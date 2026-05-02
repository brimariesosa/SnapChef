//
//  Theme.swift
//  SnapChef
//

import SwiftUI

enum Theme {
    static let forestGreen = Color(red: 34/255, green: 105/255, blue: 64/255)
    static let forestGreenDark = Color(red: 18/255, green: 70/255, blue: 42/255)
    static let forestGreenLight = Color(red: 86/255, green: 165/255, blue: 110/255)
    static let sage = Color(red: 156/255, green: 198/255, blue: 152/255)
    static let cream = Color(red: 252/255, green: 248/255, blue: 240/255)
    static let warmGray = Color(red: 122/255, green: 116/255, blue: 105/255)

    static let accent = Color(red: 255/255, green: 138/255, blue: 76/255)

    static let coral = Color(red: 255/255, green: 112/255, blue: 98/255)
    static let peach = Color(red: 255/255, green: 178/255, blue: 122/255)
    static let butter = Color(red: 254/255, green: 213/255, blue: 110/255)
    static let mint = Color(red: 130/255, green: 218/255, blue: 178/255)
    static let berry = Color(red: 226/255, green: 92/255, blue: 138/255)
    static let sky = Color(red: 122/255, green: 188/255, blue: 232/255)
    static let plum = Color(red: 142/255, green: 96/255, blue: 178/255)

    static let background = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    static let tertiaryBackground = Color(.tertiarySystemBackground)

    static let primaryGradient = LinearGradient(
        colors: [forestGreen, forestGreenLight, mint],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let sunsetGradient = LinearGradient(
        colors: [coral, peach, butter],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let berryGradient = LinearGradient(
        colors: [berry, plum],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let appBackgroundGradient = LinearGradient(
        colors: [
            Color(red: 252/255, green: 248/255, blue: 240/255),
            Color(red: 255/255, green: 242/255, blue: 230/255),
            Color(red: 245/255, green: 250/255, blue: 240/255)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Typography helpers

extension Font {
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Per-category palette

extension FoodCategory {
    var color: Color {
        switch self {
        case .produce: return Theme.mint
        case .dairy: return Theme.sky
        case .meat: return Theme.coral
        case .seafood: return Theme.sky
        case .grains: return Theme.peach
        case .pantry: return Theme.butter
        case .spicesAndCondiments: return Theme.berry
        case .frozen: return Theme.plum
        case .beverages: return Theme.plum
        case .other: return Theme.warmGray
        }
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [color, color.opacity(0.65)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - View modifiers

extension View {
    func cardStyle() -> some View {
        self
            .padding(16)
            .background(Theme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        self
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.4), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }

    func appBackground() -> some View {
        self.background(
            ZStack {
                Theme.appBackgroundGradient.ignoresSafeArea()
                DecorativeBlobs().ignoresSafeArea()
            }
        )
    }

    func primaryButton() -> some View {
        self
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.primaryGradient)
            .clipShape(Capsule())
            .shadow(color: Theme.forestGreen.opacity(0.35), radius: 10, y: 6)
    }

    func secondaryButton() -> some View {
        self
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.forestGreenDark)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.9))
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Theme.forestGreen.opacity(0.35), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }

    func sunsetButton() -> some View {
        self
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.sunsetGradient)
            .clipShape(Capsule())
            .shadow(color: Theme.coral.opacity(0.35), radius: 10, y: 6)
    }
}

// MARK: - Decorative background

struct DecorativeBlobs: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .fill(Theme.peach.opacity(0.25))
                    .frame(width: geo.size.width * 0.85, height: geo.size.width * 0.85)
                    .blur(radius: 80)
                    .offset(x: -geo.size.width * 0.35, y: -geo.size.height * 0.30)

                Circle()
                    .fill(Theme.mint.opacity(0.32))
                    .frame(width: geo.size.width * 0.75, height: geo.size.width * 0.75)
                    .blur(radius: 80)
                    .offset(x: geo.size.width * 0.35, y: geo.size.height * 0.35)

                Circle()
                    .fill(Theme.berry.opacity(0.10))
                    .frame(width: geo.size.width * 0.5, height: geo.size.width * 0.5)
                    .blur(radius: 70)
                    .offset(x: -geo.size.width * 0.10, y: geo.size.height * 0.20)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Animated scan ring

struct PulsingRing: View {
    var color: Color = Theme.forestGreen
    var size: CGFloat = 220
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .stroke(color.opacity(0.4 - Double(index) * 0.12), lineWidth: 2)
                    .scaleEffect(animate ? 1.25 + CGFloat(index) * 0.12 : 0.85)
                    .opacity(animate ? 0 : 1)
                    .animation(
                        .easeOut(duration: 2.6)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * 0.5),
                        value: animate
                    )
            }
        }
        .frame(width: size, height: size)
        .onAppear { animate = true }
    }
}
