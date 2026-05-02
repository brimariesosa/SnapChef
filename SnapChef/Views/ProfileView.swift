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

    var currentProfile: DietaryProfile? {
        profiles.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerCard

                    statsCard

                    dietaryCard

                    equipmentCard

                    notificationsCard

                    aboutCard
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .background(
                ZStack {
                    Theme.appBackgroundGradient.ignoresSafeArea()
                    DecorativeBlobs().ignoresSafeArea()
                }
            )
            .navigationTitle("Profile")
            .sheet(isPresented: $showingDietSheet) {
                if let profile = currentProfile {
                    DietaryPreferencesView(profile: profile)
                }
            }
            .sheet(isPresented: $showingEquipmentSheet) {
                EquipmentView()
            }
            .onAppear {
                seedEquipmentIfNeeded()
                seedProfileIfNeeded()
            }
        }
    }

    private var headerCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.primaryGradient)
                    .frame(width: 110, height: 110)
                    .shadow(color: Theme.forestGreen.opacity(0.4), radius: 18, y: 8)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("SnapChef User")
                .font(.display(22))
                .foregroundStyle(Theme.forestGreenDark)

            Text("Cooking smarter, wasting less")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Theme.warmGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            ZStack {
                Color.white
                LinearGradient(
                    colors: [Theme.peach.opacity(0.18), .clear, Theme.mint.opacity(0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            ProfileStatTile(value: "\(pantry.count)", label: "In Pantry")
            divider
            ProfileStatTile(value: "\(expiringCount)", label: "Expiring")
            divider
            ProfileStatTile(value: "\(equipment.filter { $0.isAvailable }.count)", label: "Appliances")
        }
        .padding(.vertical, 16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var expiringCount: Int {
        pantry.filter {
            $0.expirationStatus == .urgent || $0.expirationStatus == .soon
        }.count
    }

    private var divider: some View {
        Rectangle().fill(Color.gray.opacity(0.15)).frame(width: 1, height: 36)
    }

    private var dietaryCard: some View {
        Button {
            if currentProfile != nil {
                showingDietSheet = true
            }
        } label: {
            ProfileRow(
                icon: "leaf.circle.fill",
                title: "Dietary Preferences",
                subtitle: dietarySummary,
                iconColor: Theme.forestGreen
            )
        }
        .buttonStyle(.plain)
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

    private var equipmentCard: some View {
        Button {
            showingEquipmentSheet = true
        } label: {
            ProfileRow(
                icon: "oven.fill",
                title: "Kitchen Equipment",
                subtitle: "\(equipment.filter { $0.isAvailable }.count) of \(equipment.count) available",
                iconColor: Theme.accent
            )
        }
        .buttonStyle(.plain)
    }

    private var notificationsCard: some View {
        HStack {
            Image(systemName: "bell.fill")
                .foregroundStyle(.orange)
                .frame(width: 36, height: 36)
                .background(Color.orange.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text("Expiration Alerts")
                    .font(.system(size: 15, weight: .semibold))
                Text("Push notifications 2 days before expiration")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.warmGray)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About SnapChef")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.forestGreen)

            Text("Snap your fridge. Cook what you have. Waste nothing.")
                .font(.system(size: 15, weight: .medium))

            Text("Built by Team 6: Bri Sosa, Bo Bredenbruecher, Maksymillian Rechnio.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.warmGray)

            Text("ISYS 556/856")
                .font(.system(size: 11))
                .foregroundStyle(Theme.warmGray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func seedEquipmentIfNeeded() {
        if equipment.isEmpty {
            for name in KitchenEquipment.defaults {
                context.insert(KitchenEquipment(name: name, isAvailable: true))
            }
        }
    }

    private func seedProfileIfNeeded() {
        if profiles.isEmpty {
            context.insert(DietaryProfile())
        }
    }
}

struct ProfileStatTile: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.forestGreenDark)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.warmGray)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ProfileRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 44, height: 44)
                .background(iconColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.warmGray)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Theme.warmGray)
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
                                    .foregroundStyle(.red)
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
            .navigationTitle("Dietary Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
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
            .navigationTitle("Kitchen Equipment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
