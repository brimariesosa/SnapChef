//
//  OnboardingView.swift
//  SnapChef
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            eyebrow: "01 — Snap",
            title: "Snap your fridge.",
            subtitle: "Point your camera. Claude reads every ingredient and reads the printed expiration when it can."
        ),
        OnboardingPage(
            eyebrow: "02 — Cook",
            title: "Cook what you have.",
            subtitle: "Get recipe matches based on your pantry, dietary profile, and the appliances you actually own."
        ),
        OnboardingPage(
            eyebrow: "03 — Waste nothing.",
            title: "Use it before it spoils.",
            subtitle: "Quiet alerts at three, two, and one day out — never an inbox of noise."
        )
    ]

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar with skip
                HStack {
                    Text("SnapChef")
                        .font(.text(13, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.graphite)
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("Skip") { appState.completeOnboarding() }
                            .font(.text(13, weight: .medium))
                            .foregroundStyle(Theme.stone)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Page indicators
                HStack(spacing: 6) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(currentPage == index ? Theme.graphite : Theme.hairline)
                            .frame(width: currentPage == index ? 22 : 6, height: 4)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentPage)
                    }
                }
                .padding(.bottom, 28)

                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        appState.completeOnboarding()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(currentPage < pages.count - 1 ? "Continue" : "Get started")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .primaryButton()
                }
                .buttonStyle(.plain)
                .padding(.bottom, 36)
            }
        }
    }
}

struct OnboardingPage {
    let eyebrow: String
    let title: String
    let subtitle: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()

            Text(page.eyebrow.uppercased())
                .font(.text(11, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(Theme.stone)

            Text(page.title)
                .font(.display(44, weight: .regular))
                .tracking(-0.8)
                .foregroundStyle(Theme.graphite)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(page.subtitle)
                .font(.text(16))
                .foregroundStyle(Theme.graphiteSoft)
                .lineSpacing(4)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }
}
