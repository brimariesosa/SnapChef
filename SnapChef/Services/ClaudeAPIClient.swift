//
//  ClaudeAPIClient.swift
//  SnapChef
//
//  Calls Anthropic's /v1/messages with the captured photo and parses a
//  JSON response containing detected ingredients and tailored recipe ideas.
//

import Foundation
import UIKit

final class ClaudeAPIClient {
    static let shared = ClaudeAPIClient()
    private init() {}

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-sonnet-4-6"
    private let anthropicVersion = "2023-06-01"
    private let maxLongEdge: CGFloat = 1568

    struct AnalysisResult {
        let ingredients: [DetectedIngredient]
        let recipes: [Recipe]
    }

    enum APIError: LocalizedError {
        case missingAPIKey
        case imageEncodingFailed
        case network(Error)
        case http(status: Int, message: String)
        case invalidResponse
        case decodingFailed(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Missing API key. Add yours in Profile → Anthropic API Key."
            case .imageEncodingFailed:
                return "Couldn't prepare the photo for upload."
            case .network(let error):
                return "Network error: \(error.localizedDescription)"
            case .http(let status, let message):
                return "Claude API error (\(status)): \(message)"
            case .invalidResponse:
                return "Couldn't read Claude's response."
            case .decodingFailed(let detail):
                return "Couldn't decode response: \(detail)"
            }
        }
    }

    // MARK: - Public

    /// Asks Claude to web-search allrecipes.com and return up to ~8 candidate
    /// recipe URLs that match the pantry / dietary profile / equipment.
    /// The actual recipe content is fetched + parsed locally from those URLs;
    /// here we just need a curated list of links.
    func searchAllRecipesURLs(
        pantry: [PantryItem],
        dietaryProfile: DietaryProfile?,
        equipment: [KitchenEquipment],
        detectedIngredients: [String]? = nil,
        maxResults: Int = 8
    ) async throws -> [URL] {
        guard let apiKey = KeychainService.getAPIKey() else {
            throw APIError.missingAPIKey
        }

        let body = makeAllRecipesSearchBody(
            pantry: pantry,
            profile: dietaryProfile,
            equipment: equipment,
            detected: detectedIngredients,
            maxResults: maxResults
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = parseErrorMessage(from: data) ?? "HTTP \(http.statusCode)"
            throw APIError.http(status: http.statusCode, message: message)
        }

        let text = try extractText(from: data)
        return parseURLs(from: text)
    }

    func analyze(image: UIImage) async throws -> AnalysisResult {
        guard let apiKey = KeychainService.getAPIKey() else {
            throw APIError.missingAPIKey
        }

        let resized = resize(image, maxLongEdge: maxLongEdge)
        guard let jpegData = resized.jpegData(compressionQuality: 0.7) else {
            throw APIError.imageEncodingFailed
        }
        let base64 = jpegData.base64EncodedString()

        let body = makeRequestBody(imageBase64: base64)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = parseErrorMessage(from: data) ?? "HTTP \(http.statusCode)"
            throw APIError.http(status: http.statusCode, message: message)
        }

        let text = try extractText(from: data)
        return try decode(text: text)
    }

    // MARK: - allrecipes.com search request

    private func makeAllRecipesSearchBody(
        pantry: [PantryItem],
        profile: DietaryProfile?,
        equipment: [KitchenEquipment],
        detected: [String]?,
        maxResults: Int
    ) -> [String: Any] {
        var pantryNames = pantry.map { $0.name }
        if let detected, !detected.isEmpty {
            // Bias toward what's in the photo by listing those first.
            pantryNames = detected + pantryNames.filter { !detected.contains($0) }
        }

        var dietaryConstraints: [String] = []
        if let profile {
            if profile.isVegan { dietaryConstraints.append("vegan") }
            else if profile.isVegetarian { dietaryConstraints.append("vegetarian") }
            if profile.isGlutenFree { dietaryConstraints.append("gluten-free") }
            if profile.isDairyFree { dietaryConstraints.append("dairy-free") }
            if profile.isNutFree { dietaryConstraints.append("nut-free") }
            if !profile.allergies.isEmpty {
                dietaryConstraints.append("avoid: \(profile.allergies.joined(separator: ", "))")
            }
        }
        let availableEquipment = equipment
            .filter { $0.isAvailable }
            .map { $0.name }

        let pantryLine = pantryNames.isEmpty
            ? "no specific pantry — pick popular crowd-pleasers"
            : pantryNames.prefix(20).joined(separator: ", ")
        let dietaryLine = dietaryConstraints.isEmpty
            ? "none"
            : dietaryConstraints.joined(separator: ", ")
        let equipmentLine = availableEquipment.isEmpty
            ? "any"
            : availableEquipment.joined(separator: ", ")

        let prompt = """
        Use web search to find \(maxResults) real recipe URLs from \
        allrecipes.com that best match the user's pantry and dietary needs.

        Pantry ingredients: \(pantryLine)
        Dietary constraints: \(dietaryLine)
        Available kitchen equipment: \(equipmentLine)

        Hard requirements:
        - Every URL must be a recipe page on allrecipes.com (host equals \
        www.allrecipes.com or allrecipes.com, path contains /recipe/).
        - Prefer recipes that use as many of the pantry ingredients as \
        possible, and respect the dietary constraints.
        - Return only canonical recipe pages — no collections, no slideshows.

        Output ONLY a single JSON object on its own, no prose, no markdown \
        fences, with this exact shape:
        { "urls": ["https://www.allrecipes.com/recipe/...", ...] }
        """

        return [
            "model": model,
            "max_tokens": 1024,
            "tools": [
                [
                    "type": "web_search_20250305",
                    "name": "web_search",
                    "max_uses": 3,
                    "allowed_domains": ["allrecipes.com", "www.allrecipes.com"]
                ]
            ],
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt]
                    ]
                ]
            ]
        ]
    }

    private func parseURLs(from text: String) -> [URL] {
        let candidate = extractJSONObject(from: text) ?? stripCodeFence(text)
        guard let data = candidate.data(using: .utf8) else { return [] }

        struct Wire: Decodable { let urls: [String]? }
        guard let wire = try? JSONDecoder().decode(Wire.self, from: data),
              let urls = wire.urls
        else { return [] }

        return urls.compactMap { raw -> URL? in
            guard let url = URL(string: raw),
                  let host = url.host?.lowercased(),
                  host == "allrecipes.com" || host == "www.allrecipes.com",
                  url.path.lowercased().contains("/recipe/")
            else { return nil }
            return url
        }
    }

    // MARK: - Request body

    private func makeRequestBody(imageBase64: String) -> [String: Any] {
        let allowedCategories = FoodCategory.allCases.map { $0.rawValue }.joined(separator: " | ")

        let prompt = """
        You are SnapChef, an AI that identifies ingredients in food photos and suggests \
        recipes that can be made with them. Analyze the attached photo and respond with \
        ONLY a single JSON object — no prose, no markdown fences, no commentary.

        Schema:
        {
          "ingredients": [
            {
              "name": "string",
              "confidence": 0.0-1.0,
              "category": "<one of the allowed values>",
              "expirationDate": "YYYY-MM-DD" or null
            }
          ],
          "recipes": [
            {
              "title": "string",
              "description": "short blurb",
              "prepTime": minutes (int),
              "cookTime": minutes (int),
              "servings": int,
              "difficulty": "Easy" | "Medium" | "Hard",
              "ingredients": [{ "name": "string", "amount": number, "unit": "string" }],
              "steps": ["step 1", "step 2", ...],
              "tags": ["tag", ...]
            }
          ]
        }

        Allowed category values (use exactly one): \(allowedCategories).

        Rules:
        - Only list ingredients you can clearly see in the photo. Use singular common names \
        (e.g. "Tomato", "Cheddar Cheese", "Chicken Breast").
        - Identify ingredients generically — never include brand or manufacturer names. \
        Strip the brand and return only the food itself: "Heinz Tomato Ketchup" → \
        "Tomato Ketchup", "Barilla Penne Pasta" → "Penne Pasta", "Philadelphia Cream \
        Cheese" → "Cream Cheese", "Activia Strawberry Yogurt" → "Strawberry Yogurt". \
        Keep the descriptive food terms (variety, cut, flavor) but drop the brand.
        - For each ingredient, look for a printed expiration / use-by / best-before date \
        on the packaging in the photo. If a date is clearly readable, return it as \
        "expirationDate" in ISO format YYYY-MM-DD. If no date is visible or you are not \
        confident, return null. Never guess. If only a month and year are printed, use \
        the last day of that month. If the date format is ambiguous (e.g. 03/04/26), \
        prefer the day-month-year reading and still return YYYY-MM-DD.
        - Provide 3 to 6 recipe ideas that primarily use the detected ingredients. Recipes \
        may include common pantry staples (salt, pepper, oil) even if not pictured.
        - Keep recipe steps concise and numbered logically (4-8 steps each).
        - Use realistic prepTime/cookTime in minutes.
        - Output JSON ONLY. Do not wrap in code fences. No leading or trailing text.
        """

        return [
            "model": model,
            "max_tokens": 4096,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": imageBase64
                            ]
                        ],
                        [
                            "type": "text",
                            "text": prompt
                        ]
                    ]
                ]
            ]
        ]
    }

    // MARK: - Response parsing

    private func extractText(from data: Data) throws -> String {
        struct Wire: Decodable {
            struct Block: Decodable {
                let type: String
                let text: String?
            }
            let content: [Block]
            let stop_reason: String?
        }
        do {
            let wire = try JSONDecoder().decode(Wire.self, from: data)
            let text = wire.content
                .first(where: { $0.type == "text" })?
                .text
            guard let text, !text.isEmpty else {
                throw APIError.invalidResponse
            }
            if wire.stop_reason == "max_tokens" {
                throw APIError.decodingFailed("response truncated by token limit")
            }
            return text
        } catch let apiError as APIError {
            throw apiError
        } catch {
            throw APIError.decodingFailed(error.localizedDescription)
        }
    }

    private func decode(text: String) throws -> AnalysisResult {
        let candidate = extractJSONObject(from: text) ?? stripCodeFence(text)
        guard let jsonData = candidate.data(using: .utf8) else {
            throw APIError.decodingFailed("non-UTF8 payload")
        }

        struct WireIngredient: Decodable {
            let name: String
            let confidence: Double?
            let category: String?
            let expirationDate: String?
        }
        struct WireRecipeIngredient: Decodable {
            let name: String
            let amount: Double?
            let unit: String?
        }
        struct WireRecipe: Decodable {
            let title: String
            let description: String?
            let prepTime: Int?
            let cookTime: Int?
            let servings: Int?
            let difficulty: String?
            let ingredients: [WireRecipeIngredient]?
            let steps: [String]?
            let tags: [String]?
        }
        struct WirePayload: Decodable {
            let ingredients: [WireIngredient]?
            let recipes: [WireRecipe]?
        }

        let payload: WirePayload
        do {
            payload = try JSONDecoder().decode(WirePayload.self, from: jsonData)
        } catch {
            let snippet = candidate.prefix(240)
            throw APIError.decodingFailed("\(error.localizedDescription) — got: \(snippet)")
        }

        let ingredients: [DetectedIngredient] = (payload.ingredients ?? []).map { wire in
            let category = normalizedCategory(wire.category)
            let foodCategory = FoodCategory(rawValue: category)
            let shelfLife = ExpirationDefaults.days(forName: wire.name, category: foodCategory)
            return DetectedIngredient(
                name: wire.name.trimmingCharacters(in: .whitespacesAndNewlines),
                confidence: max(0.0, min(1.0, wire.confidence ?? 0.85)),
                category: category,
                suggestedShelfLife: shelfLife,
                detectedExpirationDate: parseISODate(wire.expirationDate)
            )
        }

        let recipes: [Recipe] = (payload.recipes ?? []).map { wire in
            Recipe(
                id: UUID(),
                title: wire.title,
                description: wire.description ?? "",
                imageName: "fork.knife.circle.fill",
                prepTime: wire.prepTime ?? 10,
                cookTime: wire.cookTime ?? 20,
                servings: wire.servings ?? 2,
                difficulty: wire.difficulty ?? "Easy",
                ingredients: (wire.ingredients ?? []).map {
                    RecipeIngredient(
                        name: $0.name,
                        amount: $0.amount ?? 1,
                        unit: $0.unit ?? ""
                    )
                },
                steps: wire.steps ?? [],
                tags: wire.tags ?? [],
                requiredEquipment: []
            )
        }

        return AnalysisResult(ingredients: ingredients, recipes: recipes)
    }

    private func parseErrorMessage(from data: Data) -> String? {
        struct ErrorEnvelope: Decodable {
            struct Inner: Decodable { let message: String? }
            let error: Inner?
        }
        if let env = try? JSONDecoder().decode(ErrorEnvelope.self, from: data),
           let message = env.error?.message {
            return message
        }
        return String(data: data, encoding: .utf8)
    }

    private func stripCodeFence(_ text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return trimmed }
        if let firstNewline = trimmed.firstIndex(of: "\n") {
            trimmed = String(trimmed[trimmed.index(after: firstNewline)...])
        }
        if let closing = trimmed.range(of: "```", options: .backwards) {
            trimmed = String(trimmed[..<closing.lowerBound])
        }
        return trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Walks the string and returns the substring of the first balanced
    /// `{ ... }` block, ignoring braces inside string literals. This is
    /// our defence against Claude prefixing or suffixing JSON with prose.
    private func extractJSONObject(from text: String) -> String? {
        let chars = Array(text)
        guard let start = chars.firstIndex(of: "{") else { return nil }

        var depth = 0
        var inString = false
        var escape = false
        for i in start..<chars.count {
            let c = chars[i]
            if escape { escape = false; continue }
            if inString {
                if c == "\\" { escape = true }
                else if c == "\"" { inString = false }
                continue
            }
            switch c {
            case "\"": inString = true
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 {
                    return String(chars[start...i])
                }
            default: break
            }
        }
        return nil
    }

    private static let isoDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func parseISODate(_ raw: String?) -> Date? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              raw.lowercased() != "null"
        else { return nil }
        return Self.isoDateFormatter.date(from: raw)
    }

    private func normalizedCategory(_ raw: String?) -> String {
        guard let raw else { return FoodCategory.other.rawValue }
        if FoodCategory(rawValue: raw) != nil { return raw }
        let lower = raw.lowercased()
        for cat in FoodCategory.allCases where cat.rawValue.lowercased() == lower {
            return cat.rawValue
        }
        return FoodCategory.other.rawValue
    }

    // MARK: - Image resizing

    private func resize(_ image: UIImage, maxLongEdge: CGFloat) -> UIImage {
        let size = image.size
        let longEdge = max(size.width, size.height)
        guard longEdge > maxLongEdge else { return image }

        let scale = maxLongEdge / longEdge
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
