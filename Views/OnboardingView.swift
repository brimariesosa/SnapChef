//
//  OnboardingView.swift
//  SnapChef
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 0

    let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "camera.viewfinder",
            title: "Snap your fridge",
            subtitle: "Point your camera and let AI identify every ingredient in seconds."
        ),
        OnboardingPage(
            icon: "fork.knife.circle.fill",
            title: "Cook what you have",
            subtitle: "Get recipe matches based on your pantry, diet, and kitchen equipment."
        ),
        OnboardingPage(
            icon: "leaf.fill",
            title: "Waste nothing",
            subtitle: "Expiration alerts remind you to use ingredients before they spoil."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(currentPage == index ? Theme.forestGreen : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut, value: currentPage)
                }
            }
            .padding(.bottom, 24)

            VStack(spacing: 12) {
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        appState.completeOnboarding()
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                        .primaryButton()
                }

                if currentPage < pages.count - 1 {
                    Button("Skip") {
                        appState.completeOnboarding()
                    }
                    .foregroundStyle(Theme.warmGray)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Theme.cream)
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 100, weight: .light))
                .foregroundStyle(Theme.forestGreen)
                .frame(width: 180, height: 180)
                .background(Theme.forestGreen.opacity(0.1))
                .clipShape(Circle())

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Theme.forestGreenDark)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.warmGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }
}
