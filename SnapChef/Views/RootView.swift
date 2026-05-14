//
//  RootView.swift
//  SnapChef
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    init() {
        AppAppearance.configure()
    }

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            SnapView()
                .tabItem { Label("Snap", systemImage: "viewfinder") }
                .tag(0)

            RecipesView()
                .tabItem { Label("Recipes", systemImage: "book.closed") }
                .tag(1)

            PantryView()
                .tabItem { Label("Pantry", systemImage: "tray") }
                .tag(2)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person") }
                .tag(3)
        }
        .tint(Theme.graphite)
    }
}
