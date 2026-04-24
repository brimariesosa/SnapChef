//
//  RootView.swift
//  SnapChef
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

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
    var body: some View {
        TabView {
            PantryView()
                .tabItem {
                    Label("Pantry", systemImage: "cabinet.fill")
                }

            RecipesView()
                .tabItem {
                    Label("Recipes", systemImage: "fork.knife")
                }

            SnapView()
                .tabItem {
                    Label("Snap", systemImage: "camera.fill")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .tint(Theme.forestGreen)
    }
}
