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
            { "name": "string", "confidence": 0.0-1.0, "category": "<one of the allowed values>" }
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
                suggestedShelfLife: shelfLife
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
