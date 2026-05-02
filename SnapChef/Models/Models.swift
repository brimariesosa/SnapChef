//
//  Models.swift
//  SnapChef
//

import Foundation
import SwiftData

// MARK: - Pantry Item (persisted)

@Model
final class PantryItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var quantity: Double
    var unit: String
    var category: String
    var dateAdded: Date
    var expirationDate: Date?
    var imageName: String?

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double = 1,
        unit: String = "item",
        category: String = "Other",
        dateAdded: Date = Date(),
        expirationDate: Date? = nil,
        imageName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.category = category
        self.dateAdded = dateAdded
        self.expirationDate = expirationDate
        self.imageName = imageName
    }

    var daysUntilExpiration: Int? {
        guard let exp = expirationDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: exp).day
        return days
    }

    var expirationStatus: ExpirationStatus {
        guard let days = daysUntilExpiration else { return .unknown }
        if days < 0 { return .expired }
        if days <= 2 { return .urgent }
        if days <= 5 { return .soon }
        return .fresh
    }
}

enum ExpirationStatus {
    case fresh, soon, urgent, expired, unknown

    var color: String {
        switch self {
        case .fresh: return "green"
        case .soon: return "yellow"
        case .urgent: return "orange"
        case .expired: return "red"
        case .unknown: return "gray"
        }
    }

    var label: String {
        switch self {
        case .fresh: return "Fresh"
        case .soon: return "Use soon"
        case .urgent: return "Use now"
        case .expired: return "Expired"
        case .unknown: return "No date"
        }
    }
}

// MARK: - Dietary Profile

@Model
final class DietaryProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var isVegetarian: Bool
    var isVegan: Bool
    var isGlutenFree: Bool
    var isDairyFree: Bool
    var isNutFree: Bool
    var allergies: [String]
    var isActive: Bool

    init(
        id: UUID = UUID(),
        name: String = "My Profile",
        isVegetarian: Bool = false,
        isVegan: Bool = false,
        isGlutenFree: Bool = false,
        isDairyFree: Bool = false,
        isNutFree: Bool = false,
        allergies: [String] = [],
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.isVegetarian = isVegetarian
        self.isVegan = isVegan
        self.isGlutenFree = isGlutenFree
        self.isDairyFree = isDairyFree
        self.isNutFree = isNutFree
        self.allergies = allergies
        self.isActive = isActive
    }
}

// MARK: - Kitchen Equipment

@Model
final class KitchenEquipment {
    @Attribute(.unique) var id: UUID
    var name: String
    var isAvailable: Bool

    init(id: UUID = UUID(), name: String, isAvailable: Bool = true) {
        self.id = id
        self.name = name
        self.isAvailable = isAvailable
    }

    static let defaults: [String] = [
        "Oven", "Stovetop", "Microwave", "Air Fryer",
        "Slow Cooker", "Blender", "Toaster", "Rice Cooker",
        "Instant Pot", "Grill"
    ]
}

// MARK: - Recipe (in-memory, from mock API)

struct Recipe: Identifiable, Hashable, Codable {
    let id: UUID
    let title: String
    let description: String
    let imageName: String
    let prepTime: Int
    let cookTime: Int
    let servings: Int
    let difficulty: String
    let ingredients: [RecipeIngredient]
    let steps: [String]
    let tags: [String]
    let requiredEquipment: [String]

    var totalTime: Int { prepTime + cookTime }

    func matchScore(pantry: [PantryItem]) -> Double {
        let pantryNames = Set(pantry.map { $0.name.lowercased() })
        let matched = ingredients.filter { pantryNames.contains($0.name.lowercased()) }
        guard !ingredients.isEmpty else { return 0 }
        return Double(matched.count) / Double(ingredients.count)
    }

    func missingIngredients(pantry: [PantryItem]) -> [RecipeIngredient] {
        let pantryNames = Set(pantry.map { $0.name.lowercased() })
        return ingredients.filter { !pantryNames.contains($0.name.lowercased()) }
    }
}

struct RecipeIngredient: Hashable, Codable {
    let name: String
    let amount: Double
    let unit: String
}

// MARK: - Categories

enum FoodCategory: String, CaseIterable {
    case produce = "Produce"
    case dairy = "Dairy"
    case meat = "Meat"
    case seafood = "Seafood"
    case grains = "Grains"
    case pantry = "Pantry"
    case spicesAndCondiments = "Spices & Condiments"
    case frozen = "Frozen"
    case beverages = "Beverages"
    case other = "Other"

    var icon: String {
        switch self {
        case .produce: return "leaf.fill"
        case .dairy: return "drop.fill"
        case .meat: return "fork.knife"
        case .seafood: return "fish.fill"
        case .grains: return "square.grid.3x3.fill"
        case .pantry: return "cabinet.fill"
        case .spicesAndCondiments: return "sparkles"
        case .frozen: return "snowflake"
        case .beverages: return "cup.and.saucer.fill"
        case .other: return "bag.fill"
        }
    }
}
