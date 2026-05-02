//
//  SnapChefApp.swift
//  SnapChef
//
//  Snap your fridge. Cook what you have. Waste nothing.
//
import SwiftUI
import SwiftData
import UserNotifications

@main
struct SnapChefApp: App {
    @StateObject private var appState = AppState()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            PantryItem.self,
            PantryBatch.self,
            DietaryProfile.self,
            KitchenEquipment.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        NotificationService.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
        .modelContainer(sharedModelContainer)
    }
}

final class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
}
