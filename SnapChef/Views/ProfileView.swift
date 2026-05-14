//
//  ProfileView.swift
//  SnapChef
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [DietaryProfile]
    @Query private var equipment: [KitchenEquipment]
    @Query private var pantry: [PantryItem]

    @State private var showingDietSheet = false
    @State private var showingEquipmentSheet = false
    @State private var showingAPIKeySheet = false
    @State private var apiKeyConfigured = KeychainService.getAPIKey() != nil

    private var currentProfile: DietaryProfile? { profiles.first }

    private var expiringCount: Int {
        pantry.filter { $0.expirationStatus == .urgent || $0.expirationStatus == .soon }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    titleBlock

                    metricsRow

                    settingsSection

                    aboutSection
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Theme.canvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { Color.clear.frame(height: 1) } }
            .sheet(isPresented: $showingDietSheet) {
                if let profile = currentProfile { DietaryPreferencesView(profile: profile) }
            }
            .sheet(isPresented: $showingEquipmentSheet) { EquipmentView() }
            .sheet(isPresented: $showingAPIKeySheet, onDismiss: {
                apiKeyConfigured = KeychainService.getAPIKey() != nil
            }) { APIKeySettingsView() }
            .onAppear {
                seedEquipmentIfNeeded()
                seedProfileIfNeeded()
                apiKeyConfigured = KeychainService.getAPIKey() != nil
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Profile.")
                .font(.display(40, weight: .regular))
                .tracking(-0.6)
                .foregroundStyle(Theme.graphite)
            Text("Cook smarter, waste less.")
                .font(.text(14))
                .foregroundStyle(Theme.stone)
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 0) {
            MetricTile(value: "\(pantry.count)", label: "ITEMS", tint: Theme.forest)
            verticalRule
            MetricTile(
                value: "\(expiringCount)",
                label: "USE SOON",
                tint: expiringCount > 0 ? Theme.accent : Theme.graphite
            )
            verticalRule
            MetricTile(
                value: "\(equipment.filter { $0.isAvailable }.count)",
                label: "APPLIANCES",
                tint: Theme.berry
            )
        }
        .padding(.vertical, 20)
        .overlay(Hairline(), alignment: .top)
        .overlay(Hairline(), alignment: .bottom)
    }

    private var verticalRule: some View {
        Rectangle().fill(Theme.hairline).frame(width: 1, height: 28)
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionEyebrow(text: "Preferences")

            VStack(spacing: 0) {
                SettingsRow(
                    icon: "leaf",
                    title: "Dietary preferences",
                    subtitle: dietarySummary
                ) { showingDietSheet = true }

                Hairline()

                SettingsRow(
                    icon: "cooktop",
                    title: "Kitchen equipment",
                    subtitle: "\(equipment.filter { $0.isAvailable }.count) of \(equipment.count) available"
                ) { showingEquipmentSheet = true }

                Hairline()

                SettingsRow(
                    icon: "bell",
                    title: "Expiration alerts",
                    subtitle: "Pings you 3, 2, 1 day before anything spoils",
                    trailingText: "On",
                    chevron: false,
                    action: nil
                )

                Hairline()

                SettingsRow(
                    icon: "key",
                    title: "Anthropic API key",
                    subtitle: apiKeyConfigured ? "Configured" : "Not set — required for scanning",
                    trailingDot: apiKeyConfigured ? Theme.forest : Theme.coral
                ) { showingAPIKeySheet = true }
            }
        }
    }

    private var dietarySummary: String {
        guard let profile = currentProfile else { return "No restrictions" }
        var parts: [String] = []
        if profile.isVegan { parts.append("Vegan") }
        else if profile.isVegetarian { parts.append("Vegetarian") }
        if profile.isGlutenFree { parts.append("Gluten-free") }
        if profile.isDairyFree { parts.append("Dairy-free") }
        if profile.isNutFree { parts.append("Nut-free") }
        return parts.isEmpty ? "No restrictions" : parts.joined(separator: ", ")
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionEyebrow(text: "About")
            VStack(alignment: .leading, spacing: 8) {
                Text("Snap your fridge. Cook what you have. Waste nothing.")
                    .font(.display(18, weight: .regular))
                    .foregroundStyle(Theme.graphite)
                    .lineSpacing(2)
                Text("Built by Team 6 — Bri Sosa, Bo Bredenbruecher, Maksymillian Rechnio.")
                    .font(.text(13))
                    .foregroundStyle(Theme.stone)
                Text("ISYS 556/856")
                    .font(.text(11, weight: .medium))
                    .tracking(0.6)
                    .foregroundStyle(Theme.stoneLight)
                    .padding(.top, 2)
            }
            .padding(.vertical, 8)
        }
    }

    private func seedEquipmentIfNeeded() {
        if equipment.isEmpty {
            for name in KitchenEquipment.defaults {
                context.insert(KitchenEquipment(name: name, isAvailable: true))
            }
        }
    }

    private func seedProfileIfNeeded() {
        if profiles.isEmpty { context.insert(DietaryProfile()) }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var trailingText: String? = nil
    var trailingDot: Color? = nil
    var chevron: Bool = true
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            if let action {
                Button(action: action) { content }.buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    private var content: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.graphite)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.text(15, weight: .medium))
                    .foregroundStyle(Theme.graphite)
                Text(subtitle)
                    .font(.text(12))
                    .foregroundStyle(Theme.stone)
                    .lineLimit(2)
            }

            Spacer()

            if let trailingText {
                Text(trailingText)
                    .font(.text(13, weight: .medium))
                    .foregroundStyle(Theme.graphiteSoft)
            }
            if let trailingDot {
                Circle().fill(trailingDot).frame(width: 8, height: 8)
            }
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.stoneLight)
            }
        }
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }
}

// MARK: - Dietary preferences sheet

struct DietaryPreferencesView: View {
    @Bindable var profile: DietaryProfile
    @Environment(\.dismiss) private var dismiss
    @State private var newAllergy = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Diet type") {
                    Toggle("Vegetarian", isOn: $profile.isVegetarian)
                    Toggle("Vegan", isOn: $profile.isVegan)
                        .onChange(of: profile.isVegan) { _, newValue in
                            if newValue { profile.isVegetarian = true }
                        }
                }
                Section("Restrictions") {
                    Toggle("Gluten-free", isOn: $profile.isGlutenFree)
                    Toggle("Dairy-free", isOn: $profile.isDairyFree)
                    Toggle("Nut-free", isOn: $profile.isNutFree)
                }
                Section("Allergies") {
                    ForEach(profile.allergies, id: \.self) { allergy in
                        HStack {
                            Text(allergy)
                            Spacer()
                            Button {
                                profile.allergies.removeAll { $0 == allergy }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(Theme.coral)
                            }
                        }
                    }
                    HStack {
                        TextField("Add allergy", text: $newAllergy)
                        Button("Add") {
                            let trimmed = newAllergy.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty {
                                profile.allergies.append(trimmed)
                                newAllergy = ""
                            }
                        }
                        .disabled(newAllergy.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                Section {
                    Toggle("Apply to recipe suggestions", isOn: $profile.isActive)
                }
            }
            .themedFormBackground()
            .navigationTitle("Dietary preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Equipment sheet

struct EquipmentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var equipment: [KitchenEquipment]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(equipment) { item in
                        Toggle(item.name, isOn: Binding(
                            get: { item.isAvailable },
                            set: { item.isAvailable = $0 }
                        ))
                    }
                } footer: {
                    Text("Recipes will be filtered to only show those you can make with your available equipment.")
                }
            }
            .themedFormBackground()
            .navigationTitle("Kitchen equipment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }
}
