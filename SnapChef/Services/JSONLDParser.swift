//
//  JSONLDParser.swift
//  SnapChef
//
//  Pure on-device parser that turns an allrecipes.com HTML page into a
//  Recipe struct by reading the schema.org Recipe JSON-LD that the site
//  embeds in every recipe URL.
//
//  Works against the three common JSON-LD shapes:
//    1. Top-level object:        { "@type": "Recipe", ... }
//    2. Array of objects:        [ { "@type": "Recipe", ... }, ... ]
//    3. Knowledge graph wrapper: { "@graph": [ { "@type": "Recipe", ... } ] }
//

import Foundation

enum JSONLDParser {

    /// Parse an HTML string into a Recipe, or return nil if no usable
    /// JSON-LD `Recipe` block was found.
    static func extractRecipe(from html: String, fallbackURL: String? = nil) -> Recipe? {
        for block in jsonLDBlocks(in: html) {
            guard let data = block.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data)
            else { continue }

            if let recipeObject = findRecipeObject(in: root),
               let recipe = recipe(from: recipeObject, fallbackURL: fallbackURL) {
                return recipe
            }
        }
        return nil
    }

    // MARK: - HTML scanning

    /// Returns the inner text of every `<script type="application/ld+json">`
    /// block in the HTML. Tolerant of attribute order and surrounding
    /// whitespace; doesn't require an HTML parser.
    private static func jsonLDBlocks(in html: String) -> [String] {
        let pattern = #"<script[^>]*type\s*=\s*["']application/ld\+json["'][^>]*>([\s\S]*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, options: [], range: range)
        return matches.compactMap { match in
            guard match.numberOfRanges >= 2,
                  let r = Range(match.range(at: 1), in: html)
            else { return nil }
            return String(html[r]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    // MARK: - JSON traversal

    private static func findRecipeObject(in root: Any) -> [String: Any]? {
        if let array = root as? [Any] {
            for entry in array {
                if let recipe = findRecipeObject(in: entry) { return recipe }
            }
            return nil
        }
        guard let dict = root as? [String: Any] else { return nil }
        if isRecipe(dict) { return dict }
        if let graph = dict["@graph"] {
            return findRecipeObject(in: graph)
        }
        return nil
    }

    private static func isRecipe(_ dict: [String: Any]) -> Bool {
        let type = dict["@type"]
        if let t = type as? String { return t.caseInsensitiveCompare("Recipe") == .orderedSame }
        if let arr = type as? [String] {
            return arr.contains { $0.caseInsensitiveCompare("Recipe") == .orderedSame }
        }
        return false
    }

    // MARK: - Mapping

    private static func recipe(from dict: [String: Any], fallbackURL: String?) -> Recipe? {
        let title = string(dict["name"]) ?? ""
        guard !title.isEmpty else { return nil }

        let description = string(dict["description"]) ?? ""
        let imageURL = firstImageURL(dict["image"])
        let sourceURL = string(dict["url"]) ?? string(dict["mainEntityOfPage"]) ?? fallbackURL
        let prepMinutes = isoDurationMinutes(dict["prepTime"]) ?? 0
        let cookMinutes = isoDurationMinutes(dict["cookTime"]) ?? 0
        let totalMinutes = isoDurationMinutes(dict["totalTime"])
        let (prep, cook) = splitTimes(prep: prepMinutes, cook: cookMinutes, total: totalMinutes)
        let servings = parseServings(dict["recipeYield"])
        let ingredients = parseIngredients(dict["recipeIngredient"])
        let steps = parseInstructions(dict["recipeInstructions"])
        let tags = parseTags(dict)
        let rating = parseRating(dict["aggregateRating"])

        return Recipe(
            id: UUID(),
            title: title,
            description: description,
            imageName: "fork.knife.circle.fill",
            prepTime: prep,
            cookTime: cook,
            servings: servings,
            difficulty: difficultyFor(totalMinutes: prep + cook, ingredientCount: ingredients.count),
            ingredients: ingredients,
            steps: steps,
            tags: tags,
            requiredEquipment: [],
            sourceURL: sourceURL,
            sourceName: "allrecipes.com",
            imageURL: imageURL,
            rating: rating
        )
    }

    // MARK: - Field parsers

    private static func string(_ value: Any?) -> String? {
        if let s = value as? String { return s.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let dict = value as? [String: Any], let s = dict["@id"] as? String { return s }
        if let arr = value as? [Any] { return arr.compactMap { string($0) }.first }
        return nil
    }

    private static func firstImageURL(_ value: Any?) -> String? {
        if let s = value as? String { return s }
        if let dict = value as? [String: Any] {
            return string(dict["url"]) ?? string(dict["@id"])
        }
        if let arr = value as? [Any] {
            for entry in arr {
                if let url = firstImageURL(entry) { return url }
            }
        }
        return nil
    }

    /// Parse ISO-8601 durations like `PT15M`, `PT1H30M`, `PT2H` into minutes.
    private static func isoDurationMinutes(_ value: Any?) -> Int? {
        guard let raw = string(value), raw.hasPrefix("PT") else { return nil }
        var hours = 0
        var minutes = 0
        var current = ""
        for ch in raw.dropFirst(2) {
            if ch.isNumber {
                current.append(ch)
            } else if ch == "H" {
                hours = Int(current) ?? 0
                current = ""
            } else if ch == "M" {
                minutes = Int(current) ?? 0
                current = ""
            } else {
                current = ""
            }
        }
        let total = hours * 60 + minutes
        return total > 0 ? total : nil
    }

    /// If we have prep + cook explicitly, use them. Otherwise split the
    /// total roughly into prep (~25%) and cook (~75%) so the existing UI
    /// has reasonable numbers to render.
    private static func splitTimes(prep: Int, cook: Int, total: Int?) -> (Int, Int) {
        if prep > 0 || cook > 0 { return (prep, cook) }
        guard let total, total > 0 else { return (10, 20) }
        let p = max(1, Int(Double(total) * 0.25))
        return (p, max(1, total - p))
    }

    private static func parseServings(_ value: Any?) -> Int {
        if let n = value as? Int { return n }
        if let d = value as? Double { return Int(d) }
        if let s = string(value) {
            // "4 servings", "Makes 12", "12-15"
            let digits = s.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
            if let first = digits.first { return first }
        }
        if let arr = value as? [Any] {
            for entry in arr {
                let n = parseServings(entry)
                if n > 0 { return n }
            }
        }
        return 2
    }

    private static func parseIngredients(_ value: Any?) -> [RecipeIngredient] {
        guard let arr = value as? [Any] else { return [] }
        return arr.compactMap { entry -> RecipeIngredient? in
            guard let raw = string(entry), !raw.isEmpty else { return nil }
            return splitIngredientLine(raw)
        }
    }

    /// Best-effort split of a free-text ingredient line into amount/unit/name.
    /// Falls back to amount=1 / unit="" / name=line if it can't parse.
    private static func splitIngredientLine(_ line: String) -> RecipeIngredient {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true).map(String.init)

        guard parts.count >= 2 else {
            return RecipeIngredient(name: trimmed, amount: 1, unit: "")
        }

        let amount = parseAmount(parts[0])
        if amount == nil {
            return RecipeIngredient(name: trimmed, amount: 1, unit: "")
        }

        if parts.count == 2 {
            return RecipeIngredient(name: parts[1], amount: amount!, unit: "")
        }

        let unitCandidate = parts[1].lowercased()
        let knownUnits: Set<String> = [
            "cup", "cups", "tbsp", "tablespoon", "tablespoons",
            "tsp", "teaspoon", "teaspoons", "oz", "ounce", "ounces",
            "lb", "lbs", "pound", "pounds", "g", "gram", "grams",
            "kg", "ml", "l", "clove", "cloves", "pinch", "dash",
            "can", "cans", "package", "packages", "slice", "slices"
        ]
        if knownUnits.contains(unitCandidate) {
            return RecipeIngredient(name: parts[2], amount: amount!, unit: parts[1])
        }
        return RecipeIngredient(name: "\(parts[1]) \(parts[2])", amount: amount!, unit: "")
    }

    private static func parseAmount(_ raw: String) -> Double? {
        // Handle simple integers, decimals, and fractions like "1/2", "1 1/2".
        if let d = Double(raw) { return d }
        if raw.contains("/") {
            let bits = raw.split(separator: "/")
            if bits.count == 2,
               let num = Double(bits[0]),
               let den = Double(bits[1]),
               den != 0 {
                return num / den
            }
        }
        return nil
    }

    private static func parseInstructions(_ value: Any?) -> [String] {
        if let s = value as? String {
            return splitParagraphs(s)
        }
        guard let arr = value as? [Any] else { return [] }
        var steps: [String] = []
        for entry in arr {
            if let dict = entry as? [String: Any] {
                let type = (dict["@type"] as? String) ?? ""
                if type.caseInsensitiveCompare("HowToSection") == .orderedSame {
                    steps.append(contentsOf: parseInstructions(dict["itemListElement"]))
                } else if let text = string(dict["text"]) ?? string(dict["name"]) {
                    steps.append(text)
                }
            } else if let s = entry as? String {
                steps.append(s)
            }
        }
        return steps
    }

    private static func splitParagraphs(_ s: String) -> [String] {
        s.components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func parseTags(_ dict: [String: Any]) -> [String] {
        var tags: [String] = []

        if let keywords = dict["keywords"] as? String {
            tags.append(contentsOf: keywords.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces)
            })
        } else if let keywords = dict["keywords"] as? [String] {
            tags.append(contentsOf: keywords)
        }

        if let cat = dict["recipeCategory"] {
            if let s = cat as? String { tags.append(s) }
            if let arr = cat as? [String] { tags.append(contentsOf: arr) }
        }

        if let cuisine = dict["recipeCuisine"] {
            if let s = cuisine as? String { tags.append(s) }
            if let arr = cuisine as? [String] { tags.append(contentsOf: arr) }
        }

        return tags
            .map { $0.lowercased() }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { acc, tag in
                if !acc.contains(tag) { acc.append(tag) }
            }
    }

    private static func parseRating(_ value: Any?) -> Double? {
        guard let dict = value as? [String: Any] else { return nil }
        if let d = dict["ratingValue"] as? Double { return d }
        if let i = dict["ratingValue"] as? Int { return Double(i) }
        if let s = dict["ratingValue"] as? String, let d = Double(s) { return d }
        return nil
    }

    private static func difficultyFor(totalMinutes: Int, ingredientCount: Int) -> String {
        // Recipes don't carry difficulty in JSON-LD; estimate from time and
        // ingredient count so the existing UI badge has something reasonable.
        if totalMinutes <= 25 && ingredientCount <= 7 { return "Easy" }
        if totalMinutes >= 60 || ingredientCount >= 12 { return "Hard" }
        return "Medium"
    }
}
