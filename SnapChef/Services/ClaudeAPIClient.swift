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

    /// Asks Claude to invent fresh recipes the user can cook right now given
    /// their pantry, dietary profile, and available kitchen equipment. Pure
    /// text-based generation — no web search, no scraping. `detectedIngredients`
    /// biases the output toward items in a freshly-scanned photo.
    func generateRecipes(
        pantry: [PantryItem],
        dietaryProfile: DietaryProfile?,
        equipment: [KitchenEquipment],
        detectedIngredients: [String]? = nil,
        count: Int = 8
    ) async throws -> [Recipe] {
        guard let apiKey = KeychainService.getAPIKey() else {
            throw APIError.missingAPIKey
        }

        let body = makeRecipeGenerationBody(
            pantry: pantry,
            profile: dietaryProfile,
            equipment: equipment,
            detected: detectedIngredients,
            count: count
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 90

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
        return try decodeRecipes(text: text)
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

    // MARK: - Recipe generation request

    private func makeRecipeGenerationBody(
        pantry: [PantryItem],
        profile: DietaryProfile?,
        equipment: [KitchenEquipment],
        detected: [String]?,
        count: Int
    ) -> [String: Any] {
        var pantryNames = pantry.map { $0.name }
        if let detected, !detected.isEmpty {
            // Bias toward what's in the photo by listing those first.
            pantryNames = detected + pantryNames.filter { !detected.contains($0) }
        }

        var dietaryConstraints: [String] = []
        var allergyLine: String?
        if let profile {
            if profile.isVegan { dietaryConstraints.append("vegan") }
            else if profile.isVegetarian { dietaryConstraints.append("vegetarian") }
            if profile.isGlutenFree { dietaryConstraints.append("gluten-free") }
            if profile.isDairyFree { dietaryConstraints.append("dairy-free") }
            if profile.isNutFree { dietaryConstraints.append("nut-free") }
            if !profile.allergies.isEmpty {
                allergyLine = profile.allergies.joined(separator: ", ")
            }
        }
        let availableEquipment = equipment
            .filter { $0.isAvailable }
            .map { $0.name }

        let pantryLine = pantryNames.isEmpty
            ? "no specific pantry — invent a varied set assuming common staples only"
            : pantryNames.prefix(40).joined(separator: ", ")
        let dietaryLine = dietaryConstraints.isEmpty
            ? "none"
            : dietaryConstraints.joined(separator: ", ")
        let equipmentLine = availableEquipment.isEmpty
            ? "standard stovetop and oven"
            : availableEquipment.joined(separator: ", ")
        let allergyClause = allergyLine.map {
            "Allergies (NEVER include, in any amount, including trace ingredients): \($0)"
        } ?? "Allergies: none"

        let prompt = """
        You are SnapChef. Invent \(count) recipe ideas the user can cook \
        RIGHT NOW with what they already have. Output ONLY a single JSON \
        object — no prose, no markdown fences, no commentary.

        Pantry ingredients: \(pantryLine)
        Dietary constraints: \(dietaryLine)
        \(allergyClause)
        Available kitchen equipment: \(equipmentLine)

        Hard rules — apply to every recipe you draft:
        - Every core ingredient (protein, base, vegetable, sauce, starch, \
        dairy) must be in the pantry. The user is assumed to have common \
        staples: salt, pepper, cooking oil, butter, water, sugar, vinegar, \
        common dried herbs and spices. Nothing else is implied.
        - Before keeping a draft, mentally check: "does this need anything \
        not on that list?" If yes, discard the draft and try a different \
        recipe. Don't substitute on the user's behalf.
        - Respect dietary constraints absolutely. Allergies are \
        non-negotiable — drop any recipe that touches an allergen.
        - Only call out equipment the user actually has. If the recipe \
        needs equipment they don't have, drop it.
        - Pick varied recipes (different cuisines, techniques, meals of \
        the day) so the user has real choice within their pantry.
        - If the pantry is too sparse for \(count) genuinely-cookable recipes, \
        return fewer rather than padding with recipes that need missing \
        ingredients.
        - Use generic ingredient names — no brand names ("Tomato Ketchup" \
        not "Heinz Tomato Ketchup", "Penne Pasta" not "Barilla Penne Pasta").

        Schema:
        {
          "recipes": [
            {
              "title": "string (Title Case, short)",
              "description": "one short warm sentence",
              "prepTime": minutes (int),
              "cookTime": minutes (int),
              "servings": int,
              "difficulty": "Easy" | "Medium" | "Hard",
              "ingredients": [{ "name": "string", "amount": number, "unit": "string" }],
              "steps": ["step 1", "step 2", ...],
              "tags": ["vegan" | "vegetarian" | "gluten-free" | "dairy-free" | "nut-free" | "high-protein" | "quick" | "comfort" | "one-pan" | ...],
              "requiredEquipment": ["Stovetop" | "Oven" | "Air Fryer" | "Slow Cooker" | "Blender" | "Microwave" | "Toaster" | "Grill" | "Instant Pot"]
            }
          ]
        }

        Style:
        - 4-8 numbered steps each, concise and actionable.
        - Realistic prepTime and cookTime in minutes.
        - 2-5 tags per recipe, only those that are truthfully accurate.
        - requiredEquipment lists only what the steps actually use.
        """

        return [
            "model": model,
            "max_tokens": 4096,
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

    // MARK: - Request body

    private func makeRequestBody(imageBase64: String) -> [String: Any] {
        let allowedCategories = FoodCategory.allCases.map { $0.rawValue }.joined(separator: " | ")

        let prompt = """
        You are SnapChef. Identify the ingredients in the attached photo and \
        respond with ONLY a single JSON object — no prose, no markdown fences, \
        no commentary.

        Schema:
        {
          "ingredients": [
            {
              "name": "string",
              "confidence": 0.0-1.0,
              "category": "<one of the allowed values>",
              "expirationDate": "YYYY-MM-DD" or null
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
        - Do NOT return basic kitchen staples that nobody tracks: salt, pepper, \
        water, plain sugar, basic cooking oils (vegetable / canola / sunflower), \
        plain vinegars, and the dried-spice-jar shelf staples (oregano, basil, \
        thyme, rosemary, paprika, cumin, cinnamon, garlic powder, onion powder, \
        chili powder, cayenne, nutmeg, bay leaves, ground ginger). FRESH herbs — \
        a bunch of fresh basil on a counter, a sprig of fresh rosemary, fresh \
        thyme bundled with string — DO count and should be included with the \
        "fresh" qualifier in the name (e.g. "Fresh Basil"). The exclusion only \
        applies to the dried / ground / jarred form on a spice rack. Specialty \
        oils (olive oil, sesame oil, coconut oil) DO count — return them.
        - For each ingredient, look for a printed expiration / use-by / best-before date \
        on the packaging in the photo. If a date is clearly readable, return it as \
        "expirationDate" in ISO format YYYY-MM-DD. If no date is visible or you are not \
        confident, return null. Never guess. If only a month and year are printed, use \
        the last day of that month. If the date format is ambiguous (e.g. 03/04/26), \
        prefer the day-month-year reading and still return YYYY-MM-DD.
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

    private struct WireRecipeIngredient: Decodable {
        let name: String
        let amount: Double?
        let unit: String?
    }
    private struct WireRecipe: Decodable {
        let title: String
        let description: String?
        let prepTime: Int?
        let cookTime: Int?
        let servings: Int?
        let difficulty: String?
        let ingredients: [WireRecipeIngredient]?
        let steps: [String]?
        let tags: [String]?
        let requiredEquipment: [String]?

        func toRecipe() -> Recipe {
            Recipe(
                id: UUID(),
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description ?? "",
                imageName: "fork.knife.circle.fill",
                prepTime: prepTime ?? 10,
                cookTime: cookTime ?? 20,
                servings: servings ?? 2,
                difficulty: difficulty ?? "Easy",
                ingredients: (ingredients ?? []).map {
                    RecipeIngredient(
                        name: $0.name,
                        amount: $0.amount ?? 1,
                        unit: $0.unit ?? ""
                    )
                },
                steps: steps ?? [],
                tags: tags ?? [],
                requiredEquipment: requiredEquipment ?? []
            )
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
        struct WirePayload: Decodable {
            let ingredients: [WireIngredient]?
        }

        let payload: WirePayload
        do {
            payload = try JSONDecoder().decode(WirePayload.self, from: jsonData)
        } catch {
            let snippet = candidate.prefix(240)
            throw APIError.decodingFailed("\(error.localizedDescription) — got: \(snippet)")
        }

        let ingredients: [DetectedIngredient] = (payload.ingredients ?? []).compactMap { wire in
            let name = wire.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !PantryStaples.isStaple(name) else { return nil }
            let category = normalizedCategory(wire.category)
            let foodCategory = FoodCategory(rawValue: category)
            let shelfLife = ExpirationDefaults.days(forName: name, category: foodCategory)
            return DetectedIngredient(
                name: name,
                confidence: max(0.0, min(1.0, wire.confidence ?? 0.85)),
                category: category,
                suggestedShelfLife: shelfLife,
                detectedExpirationDate: parseISODate(wire.expirationDate)
            )
        }

        return AnalysisResult(ingredients: ingredients)
    }

    private func decodeRecipes(text: String) throws -> [Recipe] {
        let candidate = extractJSONObject(from: text) ?? stripCodeFence(text)
        guard let jsonData = candidate.data(using: .utf8) else {
            throw APIError.decodingFailed("non-UTF8 payload")
        }

        struct WirePayload: Decodable {
            let recipes: [WireRecipe]?
        }

        let payload: WirePayload
        do {
            payload = try JSONDecoder().decode(WirePayload.self, from: jsonData)
        } catch {
            let snippet = candidate.prefix(240)
            throw APIError.decodingFailed("\(error.localizedDescription) — got: \(snippet)")
        }

        return (payload.recipes ?? []).map { $0.toRecipe() }
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
