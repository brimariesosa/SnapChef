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

    let pageGradients: [LinearGradient] = [
        Theme.primaryGradient,
        Theme.sunsetGradient,
        Theme.berryGradient
    ]

    var body: some View {
        ZStack {
            Theme.appBackgroundGradient.ignoresSafeArea()
            DecorativeBlobs().ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(
                            page: pages[index],
                            gradient: pageGradients[index % pageGradients.count]
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 10) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(currentPage == index ? Theme.forestGreen : Color.gray.opacity(0.25))
                            .frame(width: currentPage == index ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentPage)
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
                        HStack(spacing: 8) {
                            Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                            Image(systemName: currentPage < pages.count - 1 ? "arrow.right" : "sparkles")
                        }
                        .primaryButton()
                    }

                    if currentPage < pages.count - 1 {
                        Button("Skip") {
                            appState.completeOnboarding()
                        }
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.warmGray)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    let gradient: LinearGradient

    @State private var animate = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(gradient)
                    .opacity(0.18)
                    .frame(width: 240, height: 240)
                    .scaleEffect(animate ? 1.05 : 0.95)
                    .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: animate)

                Circle()
                    .fill(gradient)
                    .frame(width: 180, height: 180)
                    .shadow(color: .black.opacity(0.18), radius: 24, y: 12)

                Image(systemName: page.icon)
                    .font(.system(size: 80, weight: .light))
                    .foregroundStyle(.white)
            }
            .onAppear { animate = true }

            VStack(spacing: 14) {
                Text(page.title)
                    .font(.display(34))
                    .foregroundStyle(Theme.forestGreenDark)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.system(size: 17, design: .rounded))
                    .foregroundStyle(Theme.warmGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }
}

