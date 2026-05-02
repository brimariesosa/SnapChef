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

    @Relationship(deleteRule: .cascade, inverse: \PantryBatch.item)
    var batches: [PantryBatch] = []

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

    /// Total quantity across all batches; falls back to the legacy `quantity`
    /// field when no batches have been recorded yet.
    var totalQuantity: Double {
        batches.isEmpty ? quantity : batches.reduce(0) { $0 + $1.quantity }
    }

    /// Earliest expiration across batches, falling back to legacy `expirationDate`.
    var earliestExpirationDate: Date? {
        let dates = batches.compactMap { $0.expirationDate }
        if !dates.isEmpty { return dates.min() }
        return expirationDate
    }

    var daysUntilExpiration: Int? {
        guard let exp = earliestExpirationDate else { return nil }
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

    /// Adds a new batch with its own expiration. If the item is a legacy item
    /// that still stores its quantity/expiration on the parent (no batches
    /// yet), the existing values are migrated into a seed batch first so that
    /// nothing is lost when the new batch is appended.
    func appendBatch(quantity: Double = 1,
                     expirationDate: Date?,
                     in context: ModelContext) {
        if batches.isEmpty && self.quantity > 0 {
            let seed = PantryBatch(
                quantity: self.quantity,
                dateAdded: self.dateAdded,
                expirationDate: self.expirationDate
            )
            context.insert(seed)
            self.batches.append(seed)
            self.quantity = 0
        }

        let newBatch = PantryBatch(
            quantity: quantity,
            expirationDate: expirationDate
        )
        context.insert(newBatch)
        self.batches.append(newBatch)
    }
}

// MARK: - Pantry Batch (persisted)
//
// One PantryBatch represents a single "scan" or manual addition: a quantity
// added at a particular time with its own expiration. A PantryItem groups
// many batches under the same name so the pantry list stays clean while the
// detail view can show every batch separately.

@Model
final class PantryBatch {
    @Attribute(.unique) var id: UUID
    var quantity: Double
    var dateAdded: Date
    var expirationDate: Date?
    var item: PantryItem?

    init(
        id: UUID = UUID(),
        quantity: Double = 1,
        dateAdded: Date = Date(),
        expirationDate: Date? = nil,
        item: PantryItem? = nil
    ) {
        self.id = id
        self.quantity = quantity
        self.dateAdded = dateAdded
        self.expirationDate = expirationDate
        self.item = item
    }

    var daysUntilExpiration: Int? {
        guard let exp = expirationDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: exp).day
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
        matchScore(pantryNames: pantry.map { $0.name })
    }

    func matchScore(pantryNames: [String]) -> Double {
        let names = Set(pantryNames.map { $0.lowercased() })
        let matched = ingredients.filter { names.contains($0.name.lowercased()) }
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

// MARK: - Realistic shelf life lookup

/// Best-effort, refrigerator-friendly shelf-life estimates (in days) for
/// fresh / unopened items. Used to seed expiration dates after a scan and
/// to give the manual "Add Item" form a sensible default per category.
enum ExpirationDefaults {

    /// Shelf life by exact ingredient name (case-insensitive substring match).
    /// Returns nil if no specific rule matches; callers should fall back to
    /// `days(for:)` with the chosen category.
    static func days(forName name: String) -> Int? {
        let n = name.lowercased()

        // ---- Seafood ----
        if n.contains("salmon") || n.contains("tuna") || n.contains("cod")
            || n.contains("tilapia") || n.contains("fish")
            || n.contains("shrimp") || n.contains("scallop") || n.contains("crab")
            || n.contains("lobster") {
            return 2
        }

        // ---- Meat ----
        if n.contains("ground") { return 2 }                // ground meats spoil fastest
        if n.contains("chicken") || n.contains("turkey") || n.contains("duck") {
            return 2
        }
        if n.contains("sausage") || n.contains("bacon") || n.contains("ham") {
            return 7
        }
        if n.contains("steak") || n.contains("beef")
            || n.contains("pork") || n.contains("lamb") {
            return 4
        }

        // ---- Dairy & eggs ----
        if n.contains("milk") || n.contains("half and half") { return 7 }
        if n.contains("cream") { return 7 }
        if n.contains("yogurt") { return 14 }
        if n.contains("butter") { return 45 }
        if n.contains("cheese") { return 21 }
        if n.contains("egg") { return 28 }

        // ---- Spices, condiments, oils (long shelf life) ----
        // Specific peppercorn / ground pepper checked BEFORE produce "pepper".
        if n.contains("black pepper") || n.contains("white pepper")
            || n.contains("ground pepper") || n.contains("peppercorn") {
            return 730
        }
        if n.contains("salt") || n.contains("vinegar") || n.contains("honey") {
            return 730
        }
        if n.contains("soy sauce") || n.contains("worcestershire")
            || n.contains("hot sauce") || n.contains("sriracha") {
            return 730
        }
        if n.contains("olive oil") || n.contains("vegetable oil")
            || n.contains("canola") || n.contains("oil") {
            return 540
        }
        if n.contains("ketchup") || n.contains("mayo")
            || n.contains("mayonnaise") || n.contains("mustard") {
            return 365
        }
        if n.contains("jam") || n.contains("jelly") || n.contains("syrup") {
            return 365
        }
        if n.contains("powder") || n.contains("paprika") || n.contains("cumin")
            || n.contains("cinnamon") || n.contains("oregano")
            || n.contains("rosemary") || n.contains("thyme")
            || n.contains("basil") || n.contains("dill") {
            // Dried herbs and spices in cabinet
            return 540
        }

        // ---- Grains, bakery ----
        if n.contains("flour") || n.contains("oats") || n.contains("oat") {
            return 180
        }
        if n.contains("rice") || n.contains("pasta") || n.contains("noodle") {
            return 365
        }
        if n.contains("breadcrumb") || n.contains("cracker") || n.contains("cereal") {
            return 90
        }
        if n.contains("bagel") || n.contains("tortilla") || n.contains("bread") {
            return 7
        }

        // ---- Frozen ----
        if n.contains("frozen") { return 90 }

        // ---- Produce (long-lasting) ----
        if n.contains("onion") || n.contains("garlic")
            || n.contains("potato") || n.contains("sweet potato") {
            return 60
        }
        if n.contains("squash") || n.contains("pumpkin") { return 60 }
        if n.contains("apple") || n.contains("orange")
            || n.contains("lemon") || n.contains("lime") || n.contains("grapefruit") {
            return 21
        }
        if n.contains("cabbage") { return 30 }
        if n.contains("carrot") || n.contains("beet") || n.contains("radish") {
            return 21
        }

        // ---- Produce (medium) ----
        if n.contains("celery") || n.contains("broccoli") || n.contains("cauliflower") {
            return 7
        }
        if n.contains("zucchini") || n.contains("eggplant") || n.contains("cucumber") {
            return 7
        }
        if n.contains("bell pepper") || n.contains("pepper") {
            return 10
        }
        if n.contains("tomato") { return 7 }

        // ---- Produce (delicate) ----
        if n.contains("spinach") || n.contains("kale") || n.contains("lettuce")
            || n.contains("arugula") || n.contains("salad") {
            return 5
        }
        if n.contains("mushroom") { return 5 }
        if n.contains("berry") || n.contains("strawberry")
            || n.contains("blueberry") || n.contains("raspberry") {
            return 5
        }
        if n.contains("cilantro") || n.contains("parsley") || n.contains("mint") {
            return 7
        }
        if n.contains("banana") { return 5 }
        if n.contains("avocado") { return 4 }
        if n.contains("grape") { return 7 }

        // ---- Beverages ----
        if n.contains("juice") { return 10 }
        if n.contains("soda") || n.contains("water") { return 365 }

        return nil
    }

    /// Reasonable default shelf-life for a category, used when no name match.
    static func days(for category: FoodCategory) -> Int {
        switch category {
        case .produce: return 7
        case .dairy: return 14
        case .meat: return 3
        case .seafood: return 2
        case .grains: return 90
        case .pantry: return 180
        case .spicesAndCondiments: return 540
        case .frozen: return 90
        case .beverages: return 14
        case .other: return 14
        }
    }

    /// Best estimate for an ingredient: name match first, then category.
    static func days(forName name: String,
                     category: FoodCategory? = nil) -> Int {
        if let byName = days(forName: name) { return byName }
        if let category = category { return days(for: category) }
        return 7
    }
}
