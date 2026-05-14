//
//  RecipesView.swift
//  SnapChef
//

import SwiftUI
import SwiftData

struct RecipesView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var appState: AppState
    @Query private var pantryItems: [PantryItem]
    @Query private var profiles: [DietaryProfile]
    @Query private var equipment: [KitchenEquipment]
    @Query(sort: \CachedRecipe.lastAccessed, order: .reverse) private var cachedRecipes: [CachedRecipe]

    @State private var recipes: [Recipe] = []
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var selectedFilter: RecipeFilter = .all

    enum RecipeFilter: String, CaseIterable {
        case all = "All"
        case highMatch = "High match"
        case quick = "≤20 min"
        case vegetarian = "Vegetarian"
    }

    private var filteredRecipes: [Recipe] {
        var result = recipes
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        switch selectedFilter {
        case .all: break
        case .highMatch:
            result = result.filter { $0.matchScore(pantry: pantryItems) >= 0.6 }
        case .quick:
            result = result.filter { $0.totalTime <= 20 }
        case .vegetarian:
            result = result.filter { $0.tags.contains("vegetarian") || $0.tags.contains("vegan") }
        }
        return result
    }

    private var highMatchCount: Int {
        recipes.filter { $0.matchScore(pantry: pantryItems) >= 0.6 }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    titleBlock

                    metricsRow

                    refreshSection

                    filterSection

                    listSection
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Theme.canvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { Color.clear.frame(height: 1) } }
            .searchable(text: $searchText, prompt: "Search recipes")
            .task { await loadRecipes(forceRefresh: false) }
            .refreshable { await loadRecipes(forceRefresh: true) }
            .onChange(of: appState.pendingRecipeRequest?.id) { _, newId in
                guard newId != nil,
                      let request = appState.pendingRecipeRequest else { return }
                Task {
                    await loadRecipes(forceRefresh: true, biasFrom: request)
                    appState.pendingRecipeRequest = nil
                }
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recipes.")
                .font(.display(40, weight: .regular))
                .tracking(-0.6)
                .foregroundStyle(Theme.graphite)
            Text(subtitle)
                .font(.text(14))
                .foregroundStyle(Theme.stone)
        }
    }

    private var subtitle: String {
        if recipes.isEmpty { return "Tap below to generate ideas from your pantry." }
        return "\(recipes.count) ideas, \(highMatchCount) high match."
    }

    private var metricsRow: some View {
        HStack(spacing: 0) {
            MetricTile(value: "\(pantryItems.count)", label: "INGREDIENTS")
            verticalRule
            MetricTile(value: "\(recipes.count)", label: "IDEAS", tint: Theme.berry)
            verticalRule
            MetricTile(
                value: "\(highMatchCount)",
                label: "MATCHES",
                tint: highMatchCount > 0 ? Theme.forest : Theme.graphite
            )
        }
        .padding(.vertical, 20)
        .overlay(Hairline(), alignment: .top)
        .overlay(Hairline(), alignment: .bottom)
    }

    private var verticalRule: some View {
        Rectangle().fill(Theme.hairline).frame(width: 1, height: 28)
    }

    private var refreshSection: some View {
        HStack {
            Spacer()
            Button {
                Task { await loadRecipes(forceRefresh: true) }
            } label: {
                HStack(spacing: 8) {
                    if isRefreshing {
                        ProgressView().tint(.white).controlSize(.small)
                    } else {
                        Image(systemName: "sparkles").font(.system(size: 13, weight: .semibold))
                    }
                    Text(isRefreshing ? "Stirring up ideas…" : "Generate fresh ideas")
                }
                .primaryButton()
            }
            .buttonStyle(.plain)
            .disabled(isLoading || isRefreshing || pantryItems.isEmpty)
            .opacity(pantryItems.isEmpty ? 0.4 : 1)
            Spacer()
        }
    }

    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RecipeFilter.allCases, id: \.self) { filter in
                    QuietChip(label: filter.rawValue, isSelected: selectedFilter == filter) {
                        selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal, 1)
        }
    }

    @ViewBuilder
    private var listSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionEyebrow(text: "Suggested", trailing: "\(filteredRecipes.count)")

            if isLoading {
                loadingState
            } else if filteredRecipes.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(filteredRecipes.enumerated()), id: \.element.id) { idx, recipe in
                        NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                            RecipeRow(recipe: recipe, pantry: pantryItems)
                        }
                        .buttonStyle(.plain)
                        if idx < filteredRecipes.count - 1 { Hairline() }
                    }
                }
            }
        }
    }

    private var loadingState: some View {
        HStack(spacing: 12) {
            ProgressView().tint(Theme.graphite)
            Text("Matching recipes to your pantry…")
                .font(.text(14))
                .foregroundStyle(Theme.stone)
        }
        .padding(.vertical, 28)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("No matches yet.")
                .font(.display(22, weight: .regular))
                .foregroundStyle(Theme.graphite)
            Text("Add ingredients to your pantry, then generate fresh ideas — Claude will pick recipes you can actually make tonight.")
                .font(.text(14))
                .foregroundStyle(Theme.stone)
                .lineSpacing(2)
        }
        .padding(.vertical, 24)
    }

    private func loadRecipes(
        forceRefresh: Bool,
        biasFrom request: RecipeGenerationRequest? = nil
    ) async {
        if recipes.isEmpty {
            let cached = cachedRecipes.compactMap { $0.decoded() }
            if !cached.isEmpty { recipes = cached }
        }

        let shouldFetch = forceRefresh || recipes.isEmpty || request != nil
        guard shouldFetch else { return }

        if recipes.isEmpty { isLoading = true } else { isRefreshing = true }
        defer { isLoading = false; isRefreshing = false }

        let pantryForCall: [PantryItem]
        let detectedForCall: [String]?
        if let request = request {
            detectedForCall = request.detectedNames
            pantryForCall = (request.scope == .photoPlusPantry) ? pantryItems : []
        } else {
            pantryForCall = pantryItems
            detectedForCall = nil
        }

        let profile = profiles.first { $0.isActive }
        do {
            let generated = try await ClaudeAPIClient.shared.generateRecipes(
                pantry: pantryForCall,
                dietaryProfile: profile,
                equipment: equipment,
                detectedIngredients: detectedForCall,
                count: 8
            )
            recipes = generated.sorted {
                $0.matchScore(pantry: pantryItems) > $1.matchScore(pantry: pantryItems)
            }
            errorMessage = nil
            persist(recipes)
        } catch let error as ClaudeAPIClient.APIError {
            errorMessage = error.errorDescription
            if recipes.isEmpty { recipes = sampleRecipes }
        } catch {
            errorMessage = error.localizedDescription
            if recipes.isEmpty { recipes = sampleRecipes }
        }
    }

    private func persist(_ recipes: [Recipe]) {
        let existing = (try? context.fetch(FetchDescriptor<CachedRecipe>())) ?? []
        for entry in existing { context.delete(entry) }
        for recipe in recipes {
            guard let blob = CachedRecipe.encode(recipe) else { continue }
            context.insert(CachedRecipe(sourceURL: recipe.id.uuidString, jsonBlob: blob))
        }
        try? context.save()
    }
}

// MARK: - Recipe Row (Notion-style flat row)

struct RecipeRow: View {
    let recipe: Recipe
    let pantry: [PantryItem]

    var matchPercent: Int { Int(recipe.matchScore(pantry: pantry) * 100) }

    private var matchTint: Color {
        switch matchPercent {
        case 80...: return Theme.forest
        case 50..<80: return Theme.accent
        default: return Theme.stone
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RecipeThumbnail(
                symbol: recipe.imageName,
                seed: recipe.title + recipe.tags.joined(),
                size: 76
            )
            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.title)
                    .font(.display(17, weight: .regular))
                    .foregroundStyle(Theme.graphite)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(recipe.description)
                    .font(.text(13))
                    .foregroundStyle(Theme.stone)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 12) {
                    Label("\(recipe.totalTime)m", systemImage: "clock")
                    Label("\(recipe.servings)", systemImage: "person.2")
                    Spacer()
                    Text("\(matchPercent)%")
                        .font(.numeric(12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(matchTint))
                }
                .font(.text(12))
                .foregroundStyle(Theme.stone)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}
