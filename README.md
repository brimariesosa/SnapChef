# SnapChef

Snap your fridge. Cook what you have. Waste nothing.

Built by Team 6 for ISYS 556/856.

## Setup

1. Open `SnapChef.xcodeproj` in Xcode 15 or later.
2. Select an iOS 17+ simulator or device.
3. If prompted, set your Development Team under target Signing & Capabilities.
4. Press Cmd + R to build and run.

## Project structure

```
SnapChef/
├── SnapChefApp.swift          App entry, SwiftData container, app state
├── Models/
│   └── Models.swift           PantryItem, DietaryProfile, KitchenEquipment, Recipe
├── Views/
│   ├── RootView.swift         Tab bar + onboarding gate
│   ├── OnboardingView.swift   3-page intro flow
│   ├── PantryView.swift       Grid of ingredients with search and filters
│   ├── AddItemView.swift      Manual entry form
│   ├── ItemDetailView.swift   View and edit a single item
│   ├── RecipesView.swift      Match-scored recipe list
│   ├── RecipeDetailView.swift Ingredients, steps, pantry match
│   ├── SnapView.swift         Camera + AI scan flow
│   └── ProfileView.swift      Dietary profile + equipment settings
├── Services/
│   ├── MockDataService.swift  Stubs for Spoonacular and Google Cloud Vision
│   ├── NotificationService.swift  Local push for expiration alerts
│   └── CameraService.swift    UIImagePicker wrapper + permission helper
└── Resources/
    └── Theme.swift            Forest green palette and view modifiers
```

## Features working out of the box

- Onboarding flow with 3 intro screens
- Pantry management with SwiftData persistence
- Manual add, edit, and delete for ingredients
- Expiration tracking with color-coded status badges
- Local push notifications 2 days before expiration
- Recipe matching with pantry score, dietary filters, and equipment filters
- Snap & Scan with camera and photo library support
- AI scan simulation that "detects" 3-6 random ingredients per photo
- Review screen to select which detected items to add
- Dietary profile: vegetarian, vegan, gluten-free, dairy-free, nut-free, custom allergies
- Kitchen equipment toggles that filter recipe suggestions

## What's stubbed (and where to swap in real APIs)

Everything marked with "Mock" or "stub" below is a drop-in replacement point.

### Recipe data: `Services/MockDataService.swift`

The `matchRecipes` function returns hard-coded sample recipes. Replace with a Spoonacular call:

```swift
func matchRecipes(pantry: [PantryItem], ...) async -> [Recipe] {
    let ingredientList = pantry.map { $0.name }.joined(separator: ",")
    let url = URL(string: "https://api.spoonacular.com/recipes/findByIngredients?ingredients=\(ingredientList)&apiKey=YOUR_KEY")!
    let (data, _) = try await URLSession.shared.data(from: url)
    // decode and map to Recipe
}
```

### AI vision: `Services/MockDataService.swift`

The `identifyIngredients` function returns random items from a pool. Swap for Google Cloud Vision:

```swift
func identifyIngredients(from image: UIImage) async -> [DetectedIngredient] {
    let base64 = image.jpegData(compressionQuality: 0.8)!.base64EncodedString()
    // POST to https://vision.googleapis.com/v1/images:annotate
    // parse labelAnnotations and filter to food items
}
```

### Backend auth: not implemented

For Firebase Auth, add the Firebase SDK via Swift Package Manager, then add a login view before `MainTabView` in `RootView.swift`.

## Build order reminder (per your project plan)

1. Backend foundation. Replace `MockDataService` with real API calls.
2. Auth (Firebase).
3. Already built: pantry UI, recipe matching, dietary profiles, equipment, expiration alerts.
4. Snap & Scan: replace the vision stub with Google Cloud Vision.

## Notes

- All data persists locally via SwiftData. No backend required to run.
- Expiration alerts require user permission on first launch.
- Camera requires a physical device for the best experience; the simulator supports photo library only.
