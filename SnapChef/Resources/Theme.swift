//
//  Theme.swift
//  SnapChef
//
//  The single source of truth for the visual system. Apple Health × Notion ×
//  Linear: warm-stone canvas, editorial serif display, monochrome iconography,
//  tactile but quiet buttons, Notion-style flat rows over boxed cards.
//

import SwiftUI
import UIKit

enum Theme {

    // MARK: - Brand greens (forest-at-dusk; never supermarket green)
    static let forest          = Color(red: 31/255,  green: 99/255,  blue: 62/255)
    static let forestDark      = Color(red: 16/255,  green: 64/255,  blue: 40/255)
    static let forestLight     = Color(red: 92/255,  green: 162/255, blue: 114/255)
    static let sage            = Color(red: 168/255, green: 196/255, blue: 168/255)
    static let mint            = Color(red: 138/255, green: 214/255, blue: 178/255)

    // Legacy aliases — many views still reference these names
    static let forestGreen     = forest
    static let forestGreenDark = forestDark
    static let forestGreenLight = forestLight

    // MARK: - Graphite & stone (replaces pitch black + yellow cream)
    /// Primary text. Soft warm graphite, never #000.
    static let graphite        = Color(red: 34/255,  green: 39/255,  blue: 38/255)
    /// Secondary text.
    static let graphiteSoft    = Color(red: 78/255,  green: 84/255,  blue: 82/255)
    /// Meta / helper.
    static let stone           = Color(red: 124/255, green: 130/255, blue: 128/255)
    /// Tertiary / dividers.
    static let stoneLight      = Color(red: 200/255, green: 204/255, blue: 200/255)
    /// Hairline.
    static let hairline        = Color(red: 230/255, green: 232/255, blue: 228/255)

    /// Page canvas — warm stone, NO yellow cast.
    static let canvas          = Color(red: 245/255, green: 245/255, blue: 242/255)
    /// Subtler underlayer for sections that need a beat of separation.
    static let canvasSoft      = Color(red: 240/255, green: 241/255, blue: 237/255)
    /// Card surface.
    static let bone            = Color.white

    // Legacy
    static let cream           = canvas
    static let warmGray        = stone
    static let background      = canvas
    static let secondaryBackground = bone
    static let tertiaryBackground  = canvasSoft

    // MARK: - Accents (status / category — all desaturated)
    static let accent  = Color(red: 246/255, green: 138/255, blue: 84/255)
    static let coral   = Color(red: 220/255, green: 100/255, blue:  92/255)
    static let peach   = Color(red: 240/255, green: 178/255, blue: 130/255)
    static let butter  = Color(red: 232/255, green: 198/255, blue: 110/255)
    static let berry   = Color(red: 196/255, green:  96/255, blue: 130/255)
    static let sky     = Color(red: 122/255, green: 170/255, blue: 206/255)
    static let plum    = Color(red: 138/255, green: 102/255, blue: 168/255)

    // MARK: - Gradients (used sparingly — only for the primary CTA)
    static let primaryGradient = LinearGradient(
        colors: [forestDark, forest],
        startPoint: .top, endPoint: .bottom
    )

    static let sunsetGradient = LinearGradient(
        colors: [coral, peach],
        startPoint: .top, endPoint: .bottom
    )

    static let berryGradient = LinearGradient(
        colors: [berry, plum],
        startPoint: .top, endPoint: .bottom
    )

    /// Almost flat — barely there.
    static let appBackgroundGradient = LinearGradient(
        colors: [canvas, canvas],
        startPoint: .top, endPoint: .bottom
    )

    /// Subtle top-of-button sheen (the "tactile" highlight).
    static let raisedSheen = LinearGradient(
        colors: [Color.white.opacity(0.18), Color.white.opacity(0)],
        startPoint: .top, endPoint: .center
    )
}

// MARK: - Typography
//
// Display: serif (New York) — editorial, premium, NOT generic SF Rounded.
// Body: SF Pro Text — Apple-native, crisp.
// Numerics: SF Pro Rounded, reserved for stat numbers only.

extension Font {
    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func text(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func numeric(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Per-category palette (low-saturation tints, used only for status dots)

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

    /// Kept for source compatibility but flattened — gradient discs are gone
    /// from the new design.
    var gradient: LinearGradient {
        LinearGradient(colors: [color, color], startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - View modifiers

extension View {

    /// The Notion-style page background: a flat warm stone. No gradients,
    /// no decorative blobs. The whole point of this redesign.
    func appBackground() -> some View {
        self.background(Theme.canvas.ignoresSafeArea())
    }

    /// For Forms / Lists — flat canvas under a transparent scroll area.
    func themedFormBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.canvas.ignoresSafeArea())
            .tint(Theme.forest)
    }

    /// White surface with hairline border. The only card style.
    func surface(cornerRadius: CGFloat = 18, padding: CGFloat = 18) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.bone)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
    }

    /// Card with a subtle lift — used sparingly for hero / featured surfaces.
    func cardStyle(cornerRadius: CGFloat = 18) -> some View {
        self.surface(cornerRadius: cornerRadius)
            .shadow(color: Theme.graphite.opacity(0.05), radius: 16, x: 0, y: 8)
    }

    /// Floating glass over imagery — only place blur is allowed.
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        self
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: Theme.graphite.opacity(0.10), radius: 18, y: 8)
    }

    // MARK: Buttons (compact, centered, tactile)

    /// Primary CTA — short forest pill. Auto-width: hugs its label with
    /// generous horizontal padding. Wrap in a centering `HStack { Spacer();
    /// Button … ; Spacer() }` or place inside a `.frame(maxWidth: .infinity)`
    /// container to center.
    func primaryButton() -> some View {
        self
            .font(.text(14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 26)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Theme.primaryGradient)
                    .overlay(Capsule().fill(Theme.raisedSheen))
            )
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.6))
            .shadow(color: Theme.forestDark.opacity(0.34), radius: 14, x: 0, y: 8)
            .shadow(color: Theme.graphite.opacity(0.08), radius: 1, x: 0, y: 1)
    }

    /// Compact primary — even smaller, used inline in rows / sheets.
    func compactPrimaryButton() -> some View {
        self
            .font(.text(13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Theme.primaryGradient)
                    .overlay(Capsule().fill(Theme.raisedSheen))
            )
            .shadow(color: Theme.forestDark.opacity(0.30), radius: 8, x: 0, y: 4)
    }

    /// Wide primary — full-width pill. Use inside bottom safe-area insets
    /// or sheet footers where a stretched button is intentional.
    func widePrimaryButton() -> some View {
        self
            .font(.text(15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                Capsule()
                    .fill(Theme.primaryGradient)
                    .overlay(Capsule().fill(Theme.raisedSheen))
            )
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.6))
            .shadow(color: Theme.forestDark.opacity(0.32), radius: 12, x: 0, y: 6)
    }

    /// Secondary — bone pill, hairline border, graphite text. Auto-width.
    func secondaryButton() -> some View {
        self
            .font(.text(14, weight: .semibold))
            .foregroundStyle(Theme.graphite)
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .background(Capsule().fill(Theme.bone))
            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
            .shadow(color: Theme.graphite.opacity(0.05), radius: 6, x: 0, y: 3)
    }

    /// Quiet text-only button used for tertiary actions ("Skip", "Choose
    /// from Library", etc).
    func tertiaryButton() -> some View {
        self
            .font(.text(14, weight: .medium))
            .foregroundStyle(Theme.graphiteSoft)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
    }

    /// Destructive — coral pill, ghost.
    func destructivePillButton() -> some View {
        self
            .font(.text(13, weight: .semibold))
            .foregroundStyle(Theme.coral)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Theme.coral.opacity(0.08)))
            .overlay(Capsule().strokeBorder(Theme.coral.opacity(0.22), lineWidth: 1))
    }

    /// Sunset accent CTA.
    func sunsetButton() -> some View {
        self
            .font(.text(15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                Capsule()
                    .fill(Theme.sunsetGradient)
                    .overlay(Capsule().fill(Theme.raisedSheen))
            )
            .shadow(color: Theme.coral.opacity(0.32), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Decorative background — REMOVED
//
// The blobs are gone. The new design is quiet stone. This stub stays as an
// empty view so existing call sites compile without churn — they just render
// nothing.

struct DecorativeBlobs: View {
    var body: some View { Color.clear }
}

// MARK: - Animated scan ring (still used by SnapView)

struct PulsingRing: View {
    var color: Color = Theme.forest
    var size: CGFloat = 220
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .stroke(color.opacity(0.34 - Double(index) * 0.10), lineWidth: 1.2)
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

// MARK: - Reusable building blocks

/// Editorial screen title — left-aligned big serif. Used as the first child
/// of every screen instead of `.navigationTitle`.
struct ScreenTitle: View {
    let title: String
    var subtitle: String? = nil
    var trailing: AnyView? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.display(36, weight: .regular))
                    .foregroundStyle(Theme.graphite)
                    .tracking(-0.5)
                if let subtitle {
                    Text(subtitle)
                        .font(.text(14))
                        .foregroundStyle(Theme.stone)
                }
            }
            Spacer(minLength: 12)
            trailing
        }
    }
}

/// Quiet uppercase section caption — Notion-style.
struct SectionEyebrow: View {
    let text: String
    var trailing: String? = nil
    var body: some View {
        HStack {
            Text(text.uppercased())
                .font(.text(11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.stone)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.text(12, weight: .medium))
                    .foregroundStyle(Theme.stone)
            }
        }
    }
}

/// A metric: big serif number with optional accent tint, tiny grey label.
struct MetricTile: View {
    let value: String
    let label: String
    var tint: Color = Theme.graphite
    var alignment: HorizontalAlignment = .center

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(value)
                .font(.display(28, weight: .regular))
                .foregroundStyle(tint)
            Text(label)
                .font(.text(11, weight: .medium))
                .tracking(0.4)
                .foregroundStyle(Theme.stone)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .center)
    }
}

/// Recipe-style tinted thumbnail. Picks a warm gradient from the recipe's
/// tags / title so the list reads colourful, not grey.
struct RecipeThumbnail: View {
    let symbol: String
    let seed: String
    var size: CGFloat = 72

    private var palette: (Color, Color) {
        let colors: [(Color, Color)] = [
            (Theme.forest, Theme.mint),       // greens
            (Theme.peach, Theme.butter),      // sunset
            (Theme.berry, Theme.plum),        // berry
            (Theme.sky, Theme.mint),          // ocean
            (Theme.accent, Theme.peach),      // warm
            (Theme.forestLight, Theme.sage),  // sage
        ]
        let idx = abs(seed.hashValue) % colors.count
        return colors[idx]
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [palette.0, palette.1],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: symbol)
                .font(.system(size: size * 0.36, weight: .light))
                .foregroundStyle(.white.opacity(0.92))
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.4), lineWidth: 0.5)
        )
        .shadow(color: palette.0.opacity(0.25), radius: 10, x: 0, y: 4)
    }
}

/// Hairline divider matching the design system.
struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 1)
    }
}

/// Notion-style flat row — tappable, no card chrome, hairline at the
/// bottom is added by the container.
struct ListRow<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var iconColor: Color = Theme.graphite
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 14) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 28, alignment: .center)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.text(15, weight: .medium))
                    .foregroundStyle(Theme.graphite)
                if let subtitle {
                    Text(subtitle)
                        .font(.text(12))
                        .foregroundStyle(Theme.stone)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

extension ListRow where Trailing == AnyView {
    /// Convenience constructor with the standard chevron trailing.
    init(title: String, subtitle: String? = nil, icon: String? = nil, iconColor: Color = Theme.graphite) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.trailing = {
            AnyView(
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.stoneLight)
            )
        }
    }
}

/// Quiet pill chip — used for filter / category selection. Selected state is
/// solid graphite; unselected is ghost with hairline border.
struct QuietChip: View {
    let label: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                }
                Text(label).font(.text(13, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : Theme.graphite)
            .background(
                Capsule().fill(isSelected ? AnyShapeStyle(Theme.graphite) : AnyShapeStyle(Color.clear))
            )
            .overlay(
                Capsule().strokeBorder(isSelected ? Color.clear : Theme.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Status pill for expiration — quiet dot + label. No saturated blocks.
struct StatusPill: View {
    let status: ExpirationStatus
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(dotColor).frame(width: 6, height: 6)
            if !compact {
                Text(status.label)
                    .font(.text(12, weight: .medium))
                    .foregroundStyle(Theme.graphiteSoft)
            }
        }
    }

    private var dotColor: Color {
        switch status {
        case .fresh:   return Theme.forest
        case .soon:    return Theme.butter
        case .urgent:  return Theme.accent
        case .expired: return Theme.coral
        case .unknown: return Theme.stoneLight
        }
    }
}

// MARK: - Status color helper (kept global; many views still call this)

func colorFor(status: ExpirationStatus) -> Color {
    switch status {
    case .fresh:   return Theme.forest
    case .soon:    return Theme.butter
    case .urgent:  return Theme.accent
    case .expired: return Theme.coral
    case .unknown: return Theme.stoneLight
    }
}

// MARK: - UIKit appearance configuration
//
// Called once on app launch from RootView so navigation and tab bars adopt
// the new aesthetic without each screen having to override it.

enum AppAppearance {
    static func configure() {
        // Tab bar: translucent, hairline divider, graphite text
        let tab = UITabBarAppearance()
        tab.configureWithTransparentBackground()
        tab.backgroundColor = UIColor(Theme.canvas.opacity(0.85))
        tab.shadowColor = UIColor(Theme.hairline)

        let normal: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor(Theme.stone)
        ]
        let selected: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor(Theme.graphite)
        ]
        for item in [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance] {
            item.normal.iconColor = UIColor(Theme.stone)
            item.normal.titleTextAttributes = normal
            item.selected.iconColor = UIColor(Theme.graphite)
            item.selected.titleTextAttributes = selected
        }
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        // Navigation bar: transparent, serif large title in graphite
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundColor = .clear
        nav.shadowColor = .clear
        nav.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
            .foregroundColor: UIColor(Theme.graphite)
        ]
        if let serif = UIFont.systemFont(ofSize: 32, weight: .regular).fontDescriptor
            .withDesign(.serif) {
            nav.largeTitleTextAttributes = [
                .font: UIFont(descriptor: serif, size: 32),
                .foregroundColor: UIColor(Theme.graphite)
            ]
        }
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = UIColor(Theme.graphite)
    }
}
