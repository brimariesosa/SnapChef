//
//  AllRecipesService.swift
//  SnapChef
//
//  Single source for all "real" recipes. Asks Claude (via web_search) for
//  candidate URLs on allrecipes.com, fetches each URL on-device, parses the
//  schema.org Recipe JSON-LD, caches results in SwiftData (LRU, capped at
//  `cacheLimit`), and falls back to the local sample pool when anything goes
//  wrong (no API key, offline, parse failures).
//

import Foundation
import SwiftData

@MainActor
final class AllRecipesService {
    static let shared = AllRecipesService()
    private init() {}

    /// Maximum number of recipes kept in the on-device cache.
    static let cacheLimit = 20
    /// Cap concurrent URL fetches so we don't hammer allrecipes.com.
    private static let fetchConcurrency = 4

    // MARK: - Public

    /// Recipes for the Recipes tab. Returns cached set immediately if any
    /// exist, then fires a background refresh; if cache is empty the call
    /// blocks on a fresh fetch. Falls back to `sampleRecipes` when there's
    /// nothing usable.
    func fetchMatching(
        pantry: [PantryItem],
        dietaryProfile: DietaryProfile?,
        equipment: [KitchenEquipment],
        context: ModelContext,
        forceRefresh: Bool = false
    ) async -> [Recipe] {
        // 1. Use the cache if we have anything and the caller didn't ask
        //    for a refresh (pull-to-refresh on the Recipes tab).
        if !forceRefresh {
            let cached = readCache(context: context)
            if !cached.isEmpty { return cached }
        }

        // 2. Block on a fresh fetch.
        let fetched = await refresh(
            pantry: pantry,
            profile: dietaryProfile,
            equipment: equipment,
            detected: nil,
            context: context
        )
        if !fetched.isEmpty { return fetched }

        // 3. Fall back to whatever we had cached, then to sample recipes.
        let cached = readCache(context: context)
        if !cached.isEmpty { return cached }
        return sampleRecipes
    }

    /// Recipes for the post-scan flow — biased toward the photo's detected
    /// ingredients. Does a fresh fetch every time because the user just took
    /// a photo and expects relevant suggestions.
    func fetchForDetected(
        ingredients: [DetectedIngredient],
        pantry: [PantryItem],
        dietaryProfile: DietaryProfile?,
        equipment: [KitchenEquipment],
        context: ModelContext
    ) async -> [Recipe] {
        let detectedNames = ingredients.map { $0.name }
        let fetched = await refresh(
            pantry: pantry,
            profile: dietaryProfile,
            equipment: equipment,
            detected: detectedNames,
            context: context
        )
        if !fetched.isEmpty { return fetched }
        return sampleRecipes
    }

    /// Single-recipe lookup used by the Demo Library. Tries cache first,
    /// then asks Claude for one matching URL.
    func fetchByTitle(
        _ title: String,
        context: ModelContext
    ) async -> Recipe? {
        let needle = title.lowercased()
        if let hit = readCache(context: context).first(where: {
            $0.title.lowercased().contains(needle) || needle.contains($0.title.lowercased())
        }) {
            return hit
        }

        let urls = (try? await ClaudeAPIClient.shared.searchAllRecipesURLs(
            pantry: [],
            dietaryProfile: nil,
            equipment: [],
            detectedIngredients: [title],
            maxResults: 3
        )) ?? []

        for url in urls {
            if let recipe = await fetchAndParse(url: url) {
                writeCache([recipe], context: context)
                return recipe
            }
        }

        // Fall back to the matching hardcoded sample if Claude/web fails.
        return sampleRecipes.first { sample in
            sample.title.lowercased().contains(needle) ||
            needle.contains(sample.title.lowercased())
        }
    }

    // MARK: - Cache I/O

    private func readCache(context: ModelContext) -> [Recipe] {
        var descriptor = FetchDescriptor<CachedRecipe>(
            sortBy: [SortDescriptor(\.lastAccessed, order: .reverse)]
        )
        descriptor.fetchLimit = Self.cacheLimit
        let entries = (try? context.fetch(descriptor)) ?? []
        return entries.compactMap { $0.decoded() }
    }

    private func writeCache(_ recipes: [Recipe], context: ModelContext) {
        for recipe in recipes {
            guard let url = recipe.sourceURL,
                  let blob = CachedRecipe.encode(recipe)
            else { continue }

            // Upsert by sourceURL.
            let target = url
            let existingDescriptor = FetchDescriptor<CachedRecipe>(
                predicate: #Predicate { $0.sourceURL == target }
            )
            if let existing = try? context.fetch(existingDescriptor).first {
                existing.jsonBlob = blob
                existing.lastAccessed = Date()
            } else {
                context.insert(CachedRecipe(sourceURL: url, jsonBlob: blob))
            }
        }

        // Evict oldest beyond the cap.
        let allDescriptor = FetchDescriptor<CachedRecipe>(
            sortBy: [SortDescriptor(\.lastAccessed, order: .forward)]
        )
        if let all = try? context.fetch(allDescriptor), all.count > Self.cacheLimit {
            for stale in all.prefix(all.count - Self.cacheLimit) {
                context.delete(stale)
            }
        }

        try? context.save()
    }

    // MARK: - Network

    @discardableResult
    private func refresh(
        pantry: [PantryItem],
        profile: DietaryProfile?,
        equipment: [KitchenEquipment],
        detected: [String]?,
        context: ModelContext
    ) async -> [Recipe] {
        let urls: [URL]
        do {
            urls = try await ClaudeAPIClient.shared.searchAllRecipesURLs(
                pantry: pantry,
                dietaryProfile: profile,
                equipment: equipment,
                detectedIngredients: detected
            )
        } catch {
            print("AllRecipesService search failed: \(error)")
            return []
        }

        let recipes = await withTaskGroup(of: Recipe?.self) { group in
            var iterator = urls.makeIterator()
            var inFlight = 0
            var results: [Recipe] = []

            // Prime the pump.
            while inFlight < Self.fetchConcurrency, let next = iterator.next() {
                group.addTask { [weak self] in await self?.fetchAndParse(url: next) }
                inFlight += 1
            }

            while let recipe = await group.next() {
                if let recipe { results.append(recipe) }
                if let next = iterator.next() {
                    group.addTask { [weak self] in await self?.fetchAndParse(url: next) }
                }
            }
            return results
        }

        if !recipes.isEmpty {
            writeCache(recipes, context: context)
        }
        return recipes.isEmpty ? [] : recipes
    }

    nonisolated private func fetchAndParse(url: URL) async -> Recipe? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let html = String(data: data, encoding: .utf8)
            else { return nil }
            return JSONLDParser.extractRecipe(from: html, fallbackURL: url.absoluteString)
        } catch {
            return nil
        }
    }
}
