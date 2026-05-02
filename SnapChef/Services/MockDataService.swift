//
//  MockDataService.swift
//  SnapChef
//
//  Stubs for Spoonacular API and Google Cloud Vision.
//  Swap these out for real API calls later.
//

import Foundation
import UIKit

final class MockDataService {
    static let shared = MockDataService()
    private init() {}

    // MARK: - Recipes (replaces Spoonacular)

    func fetchAllRecipes() -> [Recipe] {
        return sampleRecipes
    }

    func matchRecipes(
        pantry: [PantryItem],
        dietaryProfile: DietaryProfile?,
        equipment: [KitchenEquipment]
    ) async -> [Recipe] {
        try? await Task.sleep(nanoseconds: 400_000_000)

        var recipes = sampleRecipes

        if let profile = dietaryProfile, profile.isActive {
            recipes = recipes.filter { recipe in
                if profile.isVegan && !recipe.tags.contains("vegan") { return false }
                if profile.isVegetarian && !recipe.tags.contains("vegetarian") && !recipe.tags.contains("vegan") { return false }
                if profile.isGlutenFree && !recipe.tags.contains("gluten-free") { return false }
                if profile.isDairyFree && !recipe.tags.contains("dairy-free") { return false }
                if profile.isNutFree && recipe.tags.contains("contains-nuts") { return false }
                for allergen in profile.allergies {
                    if recipe.ingredients.contains(where: { $0.name.lowercased().contains(allergen.lowercased()) }) {
                        return false
                    }
                }
                return true
            }
        }

        let availableEquipment = Set(equipment.filter { $0.isAvailable }.map { $0.name })
        if !availableEquipment.isEmpty {
            recipes = recipes.filter { recipe in
                recipe.requiredEquipment.allSatisfy { availableEquipment.contains($0) }
            }
        }

        return recipes.sorted { $0.matchScore(pantry: pantry) > $1.matchScore(pantry: pantry) }
    }

    // MARK: - Vision (replaces Google Cloud Vision)

    func identifyIngredients(from image: UIImage) async -> [DetectedIngredient] {
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        let pool: [(name: String, confidence: Double, category: String)] = [
            ("Tomato",          0.94, "Produce"),
            ("Spinach",         0.91, "Produce"),
            ("Chicken Breast",  0.88, "Meat"),
            ("Milk",            0.96, "Dairy"),
            ("Eggs",            0.93, "Dairy"),
            ("Bell Pepper",     0.87, "Produce"),
            ("Onion",           0.95, "Produce"),
            ("Garlic",          0.90, "Produce"),
            ("Cheddar Cheese",  0.84, "Dairy"),
            ("Carrot",          0.89, "Produce"),
            ("Salmon",          0.86, "Seafood"),
            ("Strawberries",    0.90, "Produce"),
            ("Avocado",         0.85, "Produce"),
            ("Bread",           0.88, "Grains"),
            ("Soy Sauce",       0.92, "Spices & Condiments"),
            ("Black Pepper",    0.91, "Spices & Condiments"),
            ("Mustard",         0.88, "Spices & Condiments")
        ]

        let detected = pool.shuffled().prefix(Int.random(in: 3...6)).map { entry in
            DetectedIngredient(
                name: entry.name,
                confidence: entry.confidence,
                category: entry.category,
                suggestedShelfLife: ExpirationDefaults.days(
                    forName: entry.name,
                    category: FoodCategory(rawValue: entry.category)
                )
            )
        }

        return Array(detected)
    }

    // Used by the in-app Demo Library so a known photo always
    // surfaces the exact ingredients of the matching recipe.
    func identifyIngredients(for recipe: Recipe) async -> [DetectedIngredient] {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        return recipe.ingredients.map { ing in
            let category = bestCategory(for: ing.name)
            return DetectedIngredient(
                name: ing.name,
                confidence: Double.random(in: 0.86...0.97),
                category: category,
                suggestedShelfLife: ExpirationDefaults.days(
                    forName: ing.name,
                    category: FoodCategory(rawValue: category)
                )
            )
        }
    }

    private func bestCategory(for name: String) -> String {
        let n = name.lowercased()
        if ["chicken", "beef", "pork", "turkey"].contains(where: { n.contains($0) }) { return "Meat" }
        if ["fish", "salmon", "tuna", "shrimp"].contains(where: { n.contains($0) }) { return "Seafood" }
        if ["milk", "cheese", "egg", "butter", "yogurt", "cream"].contains(where: { n.contains($0) }) { return "Dairy" }
        if ["rice", "bread", "pasta", "breadcrumbs", "flour", "oats", "noodle"].contains(where: { n.contains($0) }) { return "Grains" }
        if ["soy sauce", "salt", "pepper", "mustard", "ketchup", "olive oil",
            "rosemary", "thyme", "garlic powder", "basil", "oregano", "vinegar"].contains(where: { n.contains($0) }) { return "Spices & Condiments" }
        return "Produce"
    }
}

struct DetectedIngredient: Identifiable, Hashable {
    let id: UUID
    var name: String
    var confidence: Double
    var category: String
    var suggestedShelfLife: Int

    init(
        id: UUID = UUID(),
        name: String,
        confidence: Double,
        category: String,
        suggestedShelfLife: Int
    ) {
        self.id = id
        self.name = name
        self.confidence = confidence
        self.category = category
        self.suggestedShelfLife = suggestedShelfLife
    }
}

// MARK: - Sample Recipes

let sampleRecipes: [Recipe] = [
    Recipe(
        id: UUID(),
        title: "Garlic Herb Chicken",
        description: "Juicy pan-seared chicken with fresh herbs and garlic.",
        imageName: "fork.knife.circle.fill",
        prepTime: 10,
        cookTime: 20,
        servings: 2,
        difficulty: "Easy",
        ingredients: [
            RecipeIngredient(name: "Chicken Breast", amount: 2, unit: "pieces"),
            RecipeIngredient(name: "Garlic", amount: 3, unit: "cloves"),
            RecipeIngredient(name: "Olive Oil", amount: 2, unit: "tbsp"),
            RecipeIngredient(name: "Rosemary", amount: 1, unit: "tsp")
        ],
        steps: [
            "Season chicken with salt, pepper, and rosemary.",
            "Heat olive oil in a pan over medium-high heat.",
            "Add garlic and cook until fragrant, about 30 seconds.",
            "Add chicken and sear 6-7 minutes per side until golden.",
            "Rest for 5 minutes before slicing and serving."
        ],
        tags: ["gluten-free", "dairy-free", "high-protein"],
        requiredEquipment: ["Stovetop"]
    ),
    Recipe(
        id: UUID(),
        title: "Spinach Tomato Omelette",
        description: "Fluffy omelette loaded with fresh vegetables.",
        imageName: "circle.circle.fill",
        prepTime: 5,
        cookTime: 8,
        servings: 1,
        difficulty: "Easy",
        ingredients: [
            RecipeIngredient(name: "Eggs", amount: 3, unit: "whole"),
            RecipeIngredient(name: "Spinach", amount: 1, unit: "cup"),
            RecipeIngredient(name: "Tomato", amount: 1, unit: "medium"),
            RecipeIngredient(name: "Cheddar Cheese", amount: 0.25, unit: "cup")
        ],
        steps: [
            "Whisk eggs with a pinch of salt.",
            "Cook spinach and diced tomato in a non-stick pan for 2 minutes.",
            "Pour eggs over veggies, let set on low heat.",
            "Sprinkle cheese, fold in half, and serve."
        ],
        tags: ["vegetarian", "gluten-free", "high-protein"],
        requiredEquipment: ["Stovetop"]
    ),
    Recipe(
        id: UUID(),
        title: "Roasted Veggie Bowl",
        description: "A hearty bowl of oven-roasted seasonal vegetables.",
        imageName: "leaf.circle.fill",
        prepTime: 15,
        cookTime: 25,
        servings: 2,
        difficulty: "Easy",
        ingredients: [
            RecipeIngredient(name: "Carrot", amount: 2, unit: "whole"),
            RecipeIngredient(name: "Bell Pepper", amount: 1, unit: "whole"),
            RecipeIngredient(name: "Onion", amount: 1, unit: "whole"),
            RecipeIngredient(name: "Olive Oil", amount: 3, unit: "tbsp")
        ],
        steps: [
            "Preheat oven to 425°F.",
            "Chop vegetables into 1-inch pieces.",
            "Toss with olive oil, salt, and pepper.",
            "Roast for 25 minutes, stirring once halfway.",
            "Serve over rice or greens."
        ],
        tags: ["vegan", "vegetarian", "gluten-free", "dairy-free"],
        requiredEquipment: ["Oven"]
    ),
    Recipe(
        id: UUID(),
        title: "Quick Garlic Fried Rice",
        description: "Five-minute fried rice using leftover ingredients.",
        imageName: "bowl.fill",
        prepTime: 5,
        cookTime: 10,
        servings: 2,
        difficulty: "Easy",
        ingredients: [
            RecipeIngredient(name: "Rice", amount: 2, unit: "cups"),
            RecipeIngredient(name: "Garlic", amount: 4, unit: "cloves"),
            RecipeIngredient(name: "Eggs", amount: 2, unit: "whole"),
            RecipeIngredient(name: "Onion", amount: 0.5, unit: "whole")
        ],
        steps: [
            "Mince garlic and dice onion.",
            "Heat oil, cook garlic and onion until golden.",
            "Push to side, scramble eggs in pan.",
            "Add rice, mix well, season with soy sauce.",
            "Cook 3 more minutes and serve hot."
        ],
        tags: ["vegetarian", "dairy-free"],
        requiredEquipment: ["Stovetop"]
    ),
    Recipe(
        id: UUID(),
        title: "Slow Cooker Chicken Stew",
        description: "Set-and-forget comfort food in one pot.",
        imageName: "flame.circle.fill",
        prepTime: 10,
        cookTime: 240,
        servings: 4,
        difficulty: "Easy",
        ingredients: [
            RecipeIngredient(name: "Chicken Breast", amount: 2, unit: "pieces"),
            RecipeIngredient(name: "Carrot", amount: 3, unit: "whole"),
            RecipeIngredient(name: "Onion", amount: 1, unit: "whole"),
            RecipeIngredient(name: "Garlic", amount: 3, unit: "cloves")
        ],
        steps: [
            "Chop all vegetables into chunks.",
            "Add everything to slow cooker with 2 cups broth.",
            "Season with thyme, salt, and pepper.",
            "Cook on low for 4 hours.",
            "Shred chicken and serve."
        ],
        tags: ["gluten-free", "dairy-free", "high-protein"],
        requiredEquipment: ["Slow Cooker"]
    ),
    Recipe(
        id: UUID(),
        title: "Cheesy Veggie Melt",
        description: "Open-faced sandwich with melted cheese and veggies.",
        imageName: "square.stack.fill",
        prepTime: 5,
        cookTime: 5,
        servings: 1,
        difficulty: "Easy",
        ingredients: [
            RecipeIngredient(name: "Bread", amount: 2, unit: "slices"),
            RecipeIngredient(name: "Cheddar Cheese", amount: 0.5, unit: "cup"),
            RecipeIngredient(name: "Tomato", amount: 1, unit: "medium"),
            RecipeIngredient(name: "Bell Pepper", amount: 0.5, unit: "whole")
        ],
        steps: [
            "Slice tomato and bell pepper thinly.",
            "Layer veggies on bread, top with cheese.",
            "Toast in oven or toaster oven for 5 minutes.",
            "Serve hot."
        ],
        tags: ["vegetarian"],
        requiredEquipment: ["Toaster"]
    ),
    Recipe(
        id: UUID(),
        title: "Simple Green Smoothie",
        description: "Nutrient-packed breakfast in a glass.",
        imageName: "cup.and.saucer.fill",
        prepTime: 5,
        cookTime: 0,
        servings: 1,
        difficulty: "Easy",
        ingredients: [
            RecipeIngredient(name: "Spinach", amount: 2, unit: "cups"),
            RecipeIngredient(name: "Milk", amount: 1, unit: "cup"),
            RecipeIngredient(name: "Banana", amount: 1, unit: "whole")
        ],
        steps: [
            "Add all ingredients to blender.",
            "Blend until smooth, about 45 seconds.",
            "Pour and enjoy immediately."
        ],
        tags: ["vegetarian", "gluten-free"],
        requiredEquipment: ["Blender"]
    ),
    Recipe(
        id: UUID(),
        title: "Air Fryer Chicken Tenders",
        description: "Crispy chicken tenders without the deep fryer.",
        imageName: "flame.fill",
        prepTime: 10,
        cookTime: 12,
        servings: 2,
        difficulty: "Easy",
        ingredients: [
            RecipeIngredient(name: "Chicken Breast", amount: 2, unit: "pieces"),
            RecipeIngredient(name: "Eggs", amount: 1, unit: "whole"),
            RecipeIngredient(name: "Breadcrumbs", amount: 1, unit: "cup")
        ],
        steps: [
            "Cut chicken into strips.",
            "Dip in beaten egg, then breadcrumbs.",
            "Air fry at 400°F for 12 minutes, flipping halfway.",
            "Serve with your favorite dip."
        ],
        tags: ["dairy-free", "high-protein"],
        requiredEquipment: ["Air Fryer"]
    )
]
