//
//  Theme.swift
//  SnapChef
//

import SwiftUI

enum Theme {
    // MARK: Brand greens — slightly muted, more "forest at dusk" than supermarket
    static let forestGreen = Color(red: 31/255, green: 99/255, blue: 62/255)
    static let forestGreenDark = Color(red: 16/255, green: 64/255, blue: 40/255)
    static let forestGreenLight = Color(red: 92/255, green: 162/255, blue: 114/255)
    static let sage = Color(red: 168/255, green: 196/255, blue: 168/255)
    static let mint = Color(red: 138/255, green: 214/255, blue: 178/255)

    // MARK: Graphite & stone — replaces pure black + yellow cream
    /// Primary text on light surfaces. Soft, warm graphite — never #000.
    static let graphite = Color(red: 34/255, green: 39/255, blue: 38/255)
    /// Secondary text. Muted slate.
    static let graphiteSoft = Color(red: 78/255, green: 84/255, blue: 82/255)
    /// Meta / helper text.
    static let stone = Color(red: 124/255, green: 130/255, blue: 128/255)
    /// Tertiary text & dividers.
    static let stoneLight = Color(red: 188/255, green: 192/255, blue: 188/255)
    /// Page background — warm-leaning off-white with no yellow cast.
    static let canvas = Color(red: 245/255, green: 245/255, blue: 242/255)
    /// Secondary surface — barely-there tint, sits behind cards.
    static let canvasSoft = Color(red: 240/255, green: 241/255, blue: 237/255)
    /// Pure card surface.
    static let bone = Color.white

    // MARK: Legacy tokens (kept for source-compat — retuned values)
    @available(*, deprecated, renamed: "canvas")
    static let cream = canvas
    @available(*, deprecated, renamed: "stone")
    static let warmGray = stone

    // MARK: Accents (status & category — slightly desaturated for premium feel)
    static let accent = Color(red: 246/255, green: 138/255, blue: 84/255)
    static let coral = Color(red: 232/255, green: 108/255, blue: 100/255)
    static let peach = Color(red: 244/255, green: 178/255, blue: 130/255)
    static let butter = Color(red: 240/255, green: 206/255, blue: 118/255)
    static let berry = Color(red: 206/255, green: 96/255, blue: 132/255)
    static let sky = Color(red: 124/255, green: 178/255, blue: 214/255)
    static let plum = Color(red: 138/255, green: 102/255, blue: 168/255)

    // MARK: System bridges
    static let background = canvas
    static let secondaryBackground = bone
    static let tertiaryBackground = canvasSoft

    // MARK: Gradients
    static let primaryGradient = LinearGradient(
        colors: [forestGreenDark, forestGreen, forestGreenLight],
        startPoint: .top,
        endPoint: .bottom
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

    /// Almost-flat canvas. Warm stone, no yellow. Reads premium and quiet.
    static let appBackgroundGradient = LinearGradient(
        colors: [canvas, canvasSoft],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Subtle top-down tactile sheen for buttons & raised surfaces.
    static let raisedSheen = LinearGradient(
        colors: [Color.white.opacity(0.22), Color.white.opacity(0.0)],
        startPoint: .top,
        endPoint: .center
    )
}

// MARK: - Typography helpers
//
// Premium pairing: New York (serif) for display, SF Pro for body.
// `.system(design: .serif)` resolves to New York on iOS — characterful and
// editorial without bundling a font. SF Pro on body keeps things native and
// crisp. SF Rounded reads as a kid app and is reserved for numerics only.

extension Font {
    /// Editorial display face — use for screen titles, hero numbers, recipe names.
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Native body face — clean, Apple-default.
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Numeric / pill-counter face — rounded for friendly numerics only.
    static func numeric(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
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
        case .other: return Theme.stone
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
    /// Card surface — bone white with dual neumorphic shadow (light top,
    /// soft graphite bottom) so it feels lifted off the canvas without
    /// any harsh black drop.
    func cardStyle(cornerRadius: CGFloat = 16) -> some View {
        self
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.bone)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.graphite.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: Theme.graphite.opacity(0.06), radius: 14, x: 0, y: 6)
            .shadow(color: Theme.graphite.opacity(0.03), radius: 1, x: 0, y: 1)
    }

    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        self
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: Theme.graphite.opacity(0.08), radius: 18, y: 8)
    }

    func appBackground() -> some View {
        self.background(
            ZStack {
                Theme.appBackgroundGradient.ignoresSafeArea()
                DecorativeBlobs().ignoresSafeArea()
            }
        )
    }

    /// Applies the brand background to a `Form` or `List`.
    func themedFormBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(
                ZStack {
                    Theme.appBackgroundGradient.ignoresSafeArea()
                    DecorativeBlobs().ignoresSafeArea()
                }
            )
            .tint(Theme.forestGreen)
    }

    /// Compact pill primary CTA — used inline in rows / sheets.
    /// Shorter, tactile, dual-shadow.
    func compactPrimaryButton() -> some View {
        self
            .font(.system(size: 14, weight: .semibold, design: .default))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(Theme.primaryGradient)
                    .overlay(Capsule().fill(Theme.raisedSheen))
            )
            .overlay(
                Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            )
            .shadow(color: Theme.forestGreenDark.opacity(0.35), radius: 10, x: 0, y: 6)
            .shadow(color: Theme.graphite.opacity(0.10), radius: 1, x: 0, y: 1)
    }

    /// Soft destructive pill — coral on tinted surface.
    func destructivePillButton() -> some View {
        self
            .font(.system(size: 13, weight: .semibold, design: .default))
            .foregroundStyle(Theme.coral)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(Theme.coral.opacity(0.10))
            )
            .overlay(
                Capsule().strokeBorder(Theme.coral.opacity(0.28), lineWidth: 1)
            )
    }

    /// Primary CTA — shorter (12pt vertical), tangible, dual-shadow.
    /// Material-meets-neumorphism: forest gradient base + top sheen +
    /// hairline white border + tinted glow + crisp 1px graphite shadow.
    func primaryButton() -> some View {
        self
            .font(.system(size: 16, weight: .semibold, design: .default))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Theme.primaryGradient)
                    .overlay(Capsule().fill(Theme.raisedSheen))
            )
            .overlay(
                Capsule().strokeBorder(Color.white.opacity(0.20), lineWidth: 0.75)
            )
            .shadow(color: Theme.forestGreenDark.opacity(0.38), radius: 14, x: 0, y: 8)
            .shadow(color: Theme.graphite.opacity(0.10), radius: 1, x: 0, y: 1)
    }

    /// Secondary CTA — bone surface, graphite text, hairline forest border.
    func secondaryButton() -> some View {
        self
            .font(.system(size: 16, weight: .semibold, design: .default))
            .foregroundStyle(Theme.graphite)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                Capsule().fill(Theme.bone)
            )
            .overlay(
                Capsule().strokeBorder(Theme.graphite.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Theme.graphite.opacity(0.06), radius: 8, x: 0, y: 4)
            .shadow(color: Theme.graphite.opacity(0.03), radius: 1, x: 0, y: 1)
    }

    func sunsetButton() -> some View {
        self
            .font(.system(size: 16, weight: .semibold, design: .default))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Theme.sunsetGradient)
                    .overlay(Capsule().fill(Theme.raisedSheen))
            )
            .overlay(
                Capsule().strokeBorder(Color.white.opacity(0.20), lineWidth: 0.75)
            )
            .shadow(color: Theme.coral.opacity(0.38), radius: 14, x: 0, y: 8)
            .shadow(color: Theme.graphite.opacity(0.10), radius: 1, x: 0, y: 1)
    }
}

// MARK: - Decorative background
//
// Dialed way down: cooler tones, much lower opacity, heavier blur. The
// canvas should read as quiet warm stone with a faint atmospheric hint —
// not the previous yellow-peach wash.

struct DecorativeBlobs: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .fill(Theme.sage.opacity(0.18))
                    .frame(width: geo.size.width * 0.95, height: geo.size.width * 0.95)
                    .blur(radius: 110)
                    .offset(x: -geo.size.width * 0.40, y: -geo.size.height * 0.32)

                Circle()
                    .fill(Theme.mint.opacity(0.14))
                    .frame(width: geo.size.width * 0.85, height: geo.size.width * 0.85)
                    .blur(radius: 110)
                    .offset(x: geo.size.width * 0.40, y: geo.size.height * 0.40)
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
