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
        case highMatch = "High Match"
        case quick = "Quick (≤20min)"
        case vegetarian = "Vegetarian"
    }

    var filteredRecipes: [Recipe] {
        var result = recipes

        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }

        switch selectedFilter {
        case .all:
            break
        case .highMatch:
            result = result.filter { $0.matchScore(pantry: pantryItems) >= 0.6 }
        case .quick:
            result = result.filter { $0.totalTime <= 20 }
        case .vegetarian:
            result = result.filter { $0.tags.contains("vegetarian") || $0.tags.contains("vegan") }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerStats

                    generateButton

                    filterChips

                    if isLoading {
                        ProgressView("Matching recipes...")
                            .padding(.top, 40)
                    } else if filteredRecipes.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredRecipes) { recipe in
                                NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                                    RecipeCard(recipe: recipe, pantry: pantryItems)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .background(
                ZStack {
                    Theme.appBackgroundGradient.ignoresSafeArea()
                    DecorativeBlobs().ignoresSafeArea()
                }
            )
            .navigationTitle("Recipes")
            .searchable(text: $searchText, prompt: "Search recipes")
            .task {
                await loadRecipes(forceRefresh: false)
            }
            .refreshable {
                await loadRecipes(forceRefresh: true)
            }
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

    private var headerStats: some View {
        HStack(spacing: 12) {
            StatCard(
                value: "\(pantryItems.count)",
                label: "Ingredients",
                icon: "cabinet.fill",
                gradient: LinearGradient(
                    colors: [Theme.forestGreen, Theme.forestGreenLight],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            StatCard(
                value: "\(recipes.count)",
                label: "Recipes",
                icon: "fork.knife",
                gradient: Theme.sunsetGradient
            )
            StatCard(
                value: "\(highMatchCount)",
                label: "Matches",
                icon: "star.fill",
                gradient: Theme.berryGradient
            )
        }
        .padding(.top, 8)
    }

    private var highMatchCount: Int {
        recipes.filter { $0.matchScore(pantry: pantryItems) >= 0.6 }.count
    }

    private var generateButton: some View {
        Button {
            Task { await loadRecipes(forceRefresh: true) }
        } label: {
            HStack(spacing: 10) {
                if isRefreshing {
                    ProgressView()
                        .tint(.white)
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .bold))
                }
                Text(isRefreshing ? "Stirring up ideas..." : "Fresh Ideas From Your Pantry")
            }
        }
        .primaryButton()
        .disabled(isLoading || isRefreshing)
        .opacity(pantryItems.isEmpty ? 0.5 : 1)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RecipeFilter.allCases, id: \.self) { filter in
                    CategoryChip(
                        label: filter.rawValue,
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Theme.primaryGradient)
                    .frame(width: 130, height: 130)
                    .shadow(color: Theme.forestGreen.opacity(0.3), radius: 20, y: 8)
                Image(systemName: "fork.knife")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.white)
            }

            Text("No matching recipes")
                .font(.display(20))
                .foregroundStyle(Theme.forestGreenDark)
            Text("Add more ingredients to your pantry or adjust your filters.")
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Theme.warmGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.vertical, 60)
    }

    private func loadRecipes(
        forceRefresh: Bool,
        biasFrom request: RecipeGenerationRequest? = nil
    ) async {
        // Show whatever we have cached immediately so the screen never
        // blanks on cold launch.
        if recipes.isEmpty {
            let cached = cachedRecipes.compactMap { $0.decoded() }
            if !cached.isEmpty {
                recipes = cached
            }
        }

        // Only hit Claude when the user explicitly asks (button, pull
        // to refresh, post-scan handoff) or when we have nothing to show.
        let shouldFetch = forceRefresh || recipes.isEmpty || request != nil
        guard shouldFetch else { return }

        if recipes.isEmpty {
            isLoading = true
        } else {
            isRefreshing = true
        }
        defer {
            isLoading = false
            isRefreshing = false
        }

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
            if recipes.isEmpty {
                recipes = sampleRecipes
            }
        } catch {
            errorMessage = error.localizedDescription
            if recipes.isEmpty {
                recipes = sampleRecipes
            }
        }
    }

    private func persist(_ recipes: [Recipe]) {
        // Each fresh generation replaces the previous batch so the cache
        // always reflects the user's latest pantry / preferences.
        let existing = (try? context.fetch(FetchDescriptor<CachedRecipe>())) ?? []
        for entry in existing { context.delete(entry) }

        for recipe in recipes {
            guard let blob = CachedRecipe.encode(recipe) else { continue }
            context.insert(
                CachedRecipe(sourceURL: recipe.id.uuidString, jsonBlob: blob)
            )
        }
        try? context.save()
    }
}

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let gradient: LinearGradient

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(gradient)
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.forestGreenDark)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.warmGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.forestGreen.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

struct RecipeCard: View {
    let recipe: Recipe
    let pantry: [PantryItem]

    var matchPercent: Int {
        Int(recipe.matchScore(pantry: pantry) * 100)
    }

    var matchGradient: LinearGradient {
        switch matchPercent {
        case 80...:
            return LinearGradient(
                colors: [Theme.forestGreen, Theme.mint],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case 50..<80:
            return Theme.sunsetGradient
        default:
            return LinearGradient(
                colors: [Theme.warmGray.opacity(0.85), Theme.warmGray.opacity(0.5)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    private var cardThumbnail: some View {
        ZStack {
            Rectangle().fill(heroGradient)
            Image(systemName: recipe.imageName)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.white)
        }
    }

    var heroGradient: LinearGradient {
        switch matchPercent {
        case 80...:
            return Theme.primaryGradient
        case 50..<80:
            return Theme.sunsetGradient
        default:
            return LinearGradient(colors: [Theme.warmGray, Theme.warmGray.opacity(0.6)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            cardThumbnail
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.forestGreenDark)
                    .lineLimit(1)

                Text(recipe.description)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Theme.warmGray)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Label("\(recipe.totalTime)m", systemImage: "clock")
                    Label("\(recipe.servings)", systemImage: "person.2")
                    Spacer()
                    Text("\(matchPercent)%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(matchGradient)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.warmGray)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.forestGreen.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }
}
