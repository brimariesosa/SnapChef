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

    var matchPercent: Int { Int(recipe.matchScore(pantry: pantry) * 100) }
    var missing: [RecipeIngredient] { recipe.missingIngredients(pantry: pantry) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                heroSection
                infoRow
                matchSection
                ingredientsSection
                stepsSection
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(Theme.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.canvasSoft)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    )
                Image(systemName: recipe.imageName)
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(Theme.graphiteSoft)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)

            VStack(alignment: .leading, spacing: 10) {
                Text(recipe.title)
                    .font(.display(32, weight: .regular))
                    .tracking(-0.5)
                    .foregroundStyle(Theme.graphite)
                    .lineSpacing(2)
                Text(recipe.description)
                    .font(.text(15))
                    .foregroundStyle(Theme.graphiteSoft)
                    .lineSpacing(3)
            }

            if !recipe.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(recipe.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.text(11, weight: .medium))
                                .foregroundStyle(Theme.graphiteSoft)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Info row (4 metrics)

    private var infoRow: some View {
        HStack(spacing: 0) {
            MetricTile(value: "\(recipe.prepTime)m", label: "Prep")
            verticalRule
            MetricTile(value: "\(recipe.cookTime)m", label: "Cook")
            verticalRule
            MetricTile(value: "\(recipe.servings)", label: "Servings")
            verticalRule
            MetricTile(value: recipe.difficulty, label: "Level")
        }
        .padding(.vertical, 18)
        .overlay(Hairline(), alignment: .top)
        .overlay(Hairline(), alignment: .bottom)
    }

    private var verticalRule: some View {
        Rectangle().fill(Theme.hairline).frame(width: 1, height: 28)
    }

    // MARK: - Match

    private var matchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionEyebrow(text: "Pantry match")
                Spacer()
                Text("\(matchPercent)%")
                    .font(.numeric(15, weight: .semibold))
                    .foregroundStyle(matchTint)
            }
            ProgressView(value: Double(matchPercent) / 100)
                .tint(matchTint)
            if !missing.isEmpty {
                Text("Missing: \(missing.map { $0.name }.joined(separator: ", "))")
                    .font(.text(13))
                    .foregroundStyle(Theme.graphiteSoft)
            } else {
                Text("You have everything.")
                    .font(.text(13, weight: .medium))
                    .foregroundStyle(Theme.forest)
            }
        }
    }

    private var matchTint: Color {
        switch matchPercent {
        case 80...: return Theme.forest
        case 50..<80: return Theme.accent
        default: return Theme.stone
        }
    }

    // MARK: - Ingredients

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionEyebrow(text: "Ingredients", trailing: "\(recipe.ingredients.count)")
            VStack(spacing: 0) {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { idx, ing in
                    let have = pantry.contains { $0.name.lowercased() == ing.name.lowercased() }
                    HStack(spacing: 14) {
                        Image(systemName: have ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16))
                            .foregroundStyle(have ? Theme.forest : Theme.stoneLight)
                        Text(ing.name)
                            .font(.text(15))
                            .foregroundStyle(Theme.graphite)
                            .strikethrough(have, color: Theme.stoneLight)
                        Spacer()
                        Text("\(formatted(ing.amount)) \(ing.unit)")
                            .font(.numeric(13))
                            .foregroundStyle(Theme.stone)
                    }
                    .padding(.vertical, 12)
                    if idx < recipe.ingredients.count - 1 { Hairline() }
                }
            }
        }
    }

    // MARK: - Steps

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionEyebrow(text: "Instructions", trailing: "\(recipe.steps.count) steps")
            VStack(spacing: 12) {
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { idx, step in
                    Button {
                        if completedSteps.contains(idx) {
                            completedSteps.remove(idx)
                        } else {
                            completedSteps.insert(idx)
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 14) {
                            ZStack {
                                Circle()
                                    .strokeBorder(
                                        completedSteps.contains(idx) ? Color.clear : Theme.hairline,
                                        lineWidth: 1
                                    )
                                    .background(
                                        Circle().fill(
                                            completedSteps.contains(idx)
                                            ? AnyShapeStyle(Theme.graphite)
                                            : AnyShapeStyle(Color.clear)
                                        )
                                    )
                                    .frame(width: 26, height: 26)
                                if completedSteps.contains(idx) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                } else {
                                    Text("\(idx + 1)")
                                        .font(.numeric(12, weight: .semibold))
                                        .foregroundStyle(Theme.graphiteSoft)
                                }
                            }
                            Text(step)
                                .font(.text(15))
                                .foregroundStyle(Theme.graphite)
                                .strikethrough(completedSteps.contains(idx), color: Theme.stoneLight)
                                .lineSpacing(3)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
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
