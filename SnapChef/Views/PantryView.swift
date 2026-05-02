//
//  PantryView.swift
//  SnapChef
//

import SwiftUI
import SwiftData

struct PantryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PantryItem.dateAdded, order: .reverse) private var items: [PantryItem]
    @State private var searchText = ""
    @State private var selectedCategory: String = "All"
    @State private var showingAddSheet = false

    var filteredItems: [PantryItem] {
        items.filter { item in
            let matchesSearch = searchText.isEmpty || item.name.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategory == "All" || item.category == selectedCategory
            return matchesSearch && matchesCategory
        }
    }

    var expiringItems: [PantryItem] {
        items.filter {
            $0.expirationStatus == .urgent || $0.expirationStatus == .soon
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !expiringItems.isEmpty {
                        expiringSection
                    }

                    categoryPicker

                    if filteredItems.isEmpty {
                        emptyState
                    } else {
                        itemGrid
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 80)
            }
            .background(
                ZStack {
                    Theme.appBackgroundGradient.ignoresSafeArea()
                    DecorativeBlobs().ignoresSafeArea()
                }
            )
            .navigationTitle("Pantry")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search ingredients")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Theme.primaryGradient)
                                .frame(width: 36, height: 36)
                                .shadow(color: Theme.forestGreen.opacity(0.35), radius: 6, y: 3)
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddItemView()
            }
        }
    }

    private var expiringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Theme.sunsetGradient)
                        .frame(width: 28, height: 28)
                    Image(systemName: "clock.badge.exclamationmark.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text("Use soon")
                    .font(.display(18))
                    .foregroundStyle(Theme.forestGreenDark)
                Text("\(expiringItems.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.coral))
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(expiringItems) { item in
                        NavigationLink(destination: ItemDetailView(item: item)) {
                            ExpiringItemCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(
                    label: "All",
                    color: Theme.forestGreen,
                    isSelected: selectedCategory == "All"
                ) {
                    selectedCategory = "All"
                }
                ForEach(FoodCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        label: category.rawValue,
                        icon: category.icon,
                        color: category.color,
                        isSelected: selectedCategory == category.rawValue
                    ) {
                        selectedCategory = category.rawValue
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var itemGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(filteredItems) { item in
                NavigationLink(destination: ItemDetailView(item: item)) {
                    PantryItemCard(item: item)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Theme.primaryGradient)
                    .frame(width: 130, height: 130)
                    .shadow(color: Theme.forestGreen.opacity(0.3), radius: 20, y: 8)
                Image(systemName: "cabinet.fill")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.white)
            }

            Text("Your pantry is empty")
                .font(.display(20))
                .foregroundStyle(Theme.forestGreenDark)
            Text("Tap the camera tab to snap your fridge, or add items manually.")
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Theme.warmGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Add First Item") {
                showingAddSheet = true
            }
            .primaryButton()
            .padding(.horizontal, 40)
            .padding(.top, 12)
        }
        .padding(.vertical, 60)
    }
}

struct CategoryChip: View {
    let label: String
    var icon: String? = nil
    var color: Color? = nil
    let isSelected: Bool
    let action: () -> Void

    var tint: Color { color ?? Theme.forestGreen }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                }
                Text(label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            colors: [tint, tint.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        Color.white
                    }
                }
            )
            .foregroundStyle(isSelected ? .white : tint)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(tint.opacity(isSelected ? 0 : 0.4), lineWidth: 1.5)
            )
            .shadow(
                color: isSelected ? tint.opacity(0.35) : .black.opacity(0.04),
                radius: isSelected ? 8 : 3,
                y: isSelected ? 4 : 1
            )
        }
        .buttonStyle(.plain)
    }
}

struct PantryItemCard: View {
    let item: PantryItem

    var category: FoodCategory? { FoodCategory(rawValue: item.category) }
    var tint: Color { category?.color ?? Theme.forestGreen }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(category?.gradient ?? Theme.primaryGradient)
                        .frame(width: 38, height: 38)
                        .shadow(color: tint.opacity(0.35), radius: 6, y: 3)
                    Image(systemName: category?.icon ?? "bag.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Spacer()
                statusBadge
            }

            Text(item.name)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.forestGreenDark)
                .lineLimit(1)

            HStack {
                Text("\(formatted(item.quantity)) \(item.unit)")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Theme.warmGray)

                Spacer()

                if let days = item.daysUntilExpiration {
                    Text(days >= 0 ? "\(days)d" : "expired")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(colorFor(status: item.expirationStatus))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: tint.opacity(0.12), radius: 8, y: 3)
    }

    @ViewBuilder
    private var statusBadge: some View {
        Circle()
            .fill(colorFor(status: item.expirationStatus))
            .frame(width: 10, height: 10)
            .overlay(
                Circle()
                    .stroke(colorFor(status: item.expirationStatus).opacity(0.4), lineWidth: 4)
            )
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
}

struct ExpiringItemCard: View {
    let item: PantryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: FoodCategory(rawValue: item.category)?.icon ?? "bag.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)

            Text(item.name)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

            if let days = item.daysUntilExpiration {
                Text(days == 0 ? "Today" : "\(days)d left")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
            }
        }
        .padding(14)
        .frame(width: 130, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    colorFor(status: item.expirationStatus),
                    colorFor(status: item.expirationStatus).opacity(0.75)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: colorFor(status: item.expirationStatus).opacity(0.35), radius: 10, y: 5)
    }
}

func colorFor(status: ExpirationStatus) -> Color {
    switch status {
    case .fresh: return .green
    case .soon: return .yellow
    case .urgent: return .orange
    case .expired: return .red
    case .unknown: return .gray
    }
}
