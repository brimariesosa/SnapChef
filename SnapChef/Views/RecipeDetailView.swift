//
//  RecipeDetailView.swift
//  SnapChef
//

import SwiftUI
import SwiftData

struct RecipeDetailView: View {
    let recipe: Recipe
    @Query private var pantry: [PantryItem]
    @State private var completedSteps: Set<Int> = []

    var matchPercent: Int {
        Int(recipe.matchScore(pantry: pantry) * 100)
    }

    var missing: [RecipeIngredient] {
        recipe.missingIngredients(pantry: pantry)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroSection
                infoRow
                matchSection
                ingredientsSection
                stepsSection
                if let urlString = recipe.sourceURL, let url = URL(string: urlString) {
                    sourceFooter(url: url)
                }
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .background(
            ZStack {
                Theme.appBackgroundGradient.ignoresSafeArea()
                DecorativeBlobs().ignoresSafeArea()
            }
        )
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var heroImage: some View {
        if let imageURL = recipe.imageURL, let url = URL(string: imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    heroFallback
                case .empty:
                    heroFallback.overlay(ProgressView().tint(.white))
                @unknown default:
                    heroFallback
                }
            }
        } else {
            heroFallback
        }
    }

    private var heroFallback: some View {
        Image(systemName: recipe.imageName)
            .font(.system(size: 80, weight: .light))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [Theme.forestGreen, Theme.forestGreenLight],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private func sourceFooter(url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .font(.system(size: 14, weight: .semibold))
                Text("View on \(recipe.sourceName ?? "allrecipes.com")")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(Theme.forestGreen)
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.forestGreen.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private var heroSection: some View {
        VStack(spacing: 12) {
            heroImage
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            Text(recipe.description)
                .font(.system(size: 15))
                .foregroundStyle(Theme.warmGray)

            if !recipe.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(recipe.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Theme.sage.opacity(0.3))
                                .foregroundStyle(Theme.forestGreenDark)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    private var infoRow: some View {
        HStack(spacing: 0) {
            InfoTile(icon: "clock", value: "\(recipe.prepTime)m", label: "Prep")
            divider
            InfoTile(icon: "flame", value: "\(recipe.cookTime)m", label: "Cook")
            divider
            InfoTile(icon: "person.2", value: "\(recipe.servings)", label: "Servings")
            divider
            InfoTile(icon: "chart.bar", value: recipe.difficulty, label: "Level")
        }
        .padding(.vertical, 14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.forestGreen.opacity(0.18), lineWidth: 1)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.forestGreen.opacity(0.18))
            .frame(width: 1, height: 32)
    }

    private var matchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Pantry Match")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.forestGreenDark)
                Spacer()
                Text("\(matchPercent)%")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.forestGreen)
            }

            ProgressView(value: Double(matchPercent) / 100)
                .tint(Theme.forestGreen)

            if !missing.isEmpty {
                Text("Missing: \(missing.map { $0.name }.joined(separator: ", "))")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Theme.coral)
            } else {
                Text("You have everything!")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.forestGreen)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.forestGreen.opacity(0.18), lineWidth: 1)
        )
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingredients")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.forestGreenDark)

            VStack(spacing: 8) {
                ForEach(recipe.ingredients, id: \.self) { ing in
                    let have = pantry.contains { $0.name.lowercased() == ing.name.lowercased() }
                    HStack {
                        Image(systemName: have ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(have ? Theme.forestGreen : Theme.warmGray)
                        Text(ing.name)
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(Theme.forestGreenDark)
                            .strikethrough(have, color: Theme.warmGray)
                        Spacer()
                        Text("\(formatted(ing.amount)) \(ing.unit)")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(Theme.warmGray)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Instructions")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.forestGreenDark)

            VStack(spacing: 10) {
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { idx, step in
                    Button {
                        if completedSteps.contains(idx) {
                            completedSteps.remove(idx)
                        } else {
                            completedSteps.insert(idx)
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(completedSteps.contains(idx) ? Theme.forestGreen : Theme.forestGreen.opacity(0.15))
                                    .frame(width: 28, height: 28)
                                if completedSteps.contains(idx) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                } else {
                                    Text("\(idx + 1)")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(Theme.forestGreen)
                                }
                            }

                            Text(step)
                                .font(.system(size: 15, design: .rounded))
                                .foregroundStyle(Theme.forestGreenDark)
                                .strikethrough(completedSteps.contains(idx))
                                .multilineTextAlignment(.leading)

                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.forestGreen.opacity(0.18), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.2f", value)
    }
}

struct InfoTile: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.forestGreen)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.forestGreenDark)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.warmGray)
        }
        .frame(maxWidth: .infinity)
    }
}
