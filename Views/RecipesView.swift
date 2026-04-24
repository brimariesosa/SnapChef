//
//  RecipesView.swift
//  SnapChef
//

import SwiftUI
import SwiftData

struct RecipesView: View {
    @Query private var pantryItems: [PantryItem]
    @Query private var profiles: [DietaryProfile]
    @Query private var equipment: [KitchenEquipment]

    @State private var recipes: [Recipe] = []
    @State private var isLoading = false
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
            .background(Theme.cream.opacity(0.4))
            .navigationTitle("Recipes")
            .searchable(text: $searchText, prompt: "Search recipes")
            .task {
                await loadRecipes()
            }
            .refreshable {
                await loadRecipes()
            }
        }
    }

    private var headerStats: some View {
        HStack(spacing: 12) {
            StatCard(
                value: "\(pantryItems.count)",
                label: "Ingredients",
                icon: "cabinet.fill"
            )
            StatCard(
                value: "\(recipes.count)",
                label: "Recipes",
                icon: "fork.knife"
            )
            StatCard(
                value: "\(highMatchCount)",
                label: "Great Matches",
                icon: "star.fill"
            )
        }
        .padding(.top, 8)
    }

    private var highMatchCount: Int {
        recipes.filter { $0.matchScore(pantry: pantryItems) >= 0.6 }.count
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
        VStack(spacing: 16) {
            Image(systemName: "fork.knife")
                .font(.system(size: 50))
                .foregroundStyle(Theme.sage)
            Text("No matching recipes")
                .font(.headline)
            Text("Add more ingredients to your pantry or adjust your filters.")
                .font(.subheadline)
                .foregroundStyle(Theme.warmGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.vertical, 60)
    }

    private func loadRecipes() async {
        isLoading = true
        let profile = profiles.first { $0.isActive }
        recipes = await MockDataService.shared.matchRecipes(
            pantry: pantryItems,
            dietaryProfile: profile,
            equipment: equipment
        )
        isLoading = false
    }
}

struct StatCard: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Theme.forestGreen)
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.forestGreenDark)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.warmGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct RecipeCard: View {
    let recipe: Recipe
    let pantry: [PantryItem]

    var matchPercent: Int {
        Int(recipe.matchScore(pantry: pantry) * 100)
    }

    var matchColor: Color {
        switch matchPercent {
        case 80...: return .green
        case 50..<80: return .orange
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: recipe.imageName)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.forestGreen)
                .frame(width: 80, height: 80)
                .background(Theme.forestGreen.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.forestGreenDark)
                    .lineLimit(1)

                Text(recipe.description)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.warmGray)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Label("\(recipe.totalTime)m", systemImage: "clock")
                    Label("\(recipe.servings)", systemImage: "person.2")
                    Spacer()
                    Text("\(matchPercent)%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(matchColor)
                        .clipShape(Capsule())
                }
                .font(.system(size: 12))
                .foregroundStyle(Theme.warmGray)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }
}
