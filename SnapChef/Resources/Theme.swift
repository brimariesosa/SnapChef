//
//  Theme.swift
//  SnapChef
//

import SwiftUI

enum Theme {
    static let forestGreen = Color(red: 34/255, green: 85/255, blue: 54/255)
    static let forestGreenDark = Color(red: 20/255, green: 55/255, blue: 35/255)
    static let forestGreenLight = Color(red: 78/255, green: 132/255, blue: 92/255)
    static let sage = Color(red: 156/255, green: 183/255, blue: 142/255)
    static let cream = Color(red: 250/255, green: 247/255, blue: 239/255)
    static let warmGray = Color(red: 120/255, green: 115/255, blue: 105/255)

    static let accent = Color(red: 220/255, green: 140/255, blue: 60/255)

    static let background = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    static let tertiaryBackground = Color(.tertiarySystemBackground)
}

extension View {
    func cardStyle() -> some View {
        self
            .padding(16)
            .background(Theme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    func primaryButton() -> some View {
        self
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.forestGreen)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    func secondaryButton() -> some View {
        self
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.forestGreen)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.forestGreen.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
