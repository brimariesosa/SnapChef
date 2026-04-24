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
            .background(Theme.cream.opacity(0.4))
            .navigationTitle("Pantry")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search ingredients")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.forestGreen)
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
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Use soon (\(expiringItems.count))")
                    .font(.system(size: 16, weight: .semibold))
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
                CategoryChip(label: "All", isSelected: selectedCategory == "All") {
                    selectedCategory = "All"
                }
                ForEach(FoodCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        label: category.rawValue,
                        icon: category.icon,
                        isSelected: selectedCategory == category.rawValue
                    ) {
                        selectedCategory = category.rawValue
                    }
                }
            }
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
        VStack(spacing: 16) {
            Image(systemName: "cabinet")
                .font(.system(size: 60))
                .foregroundStyle(Theme.sage)
            Text("Your pantry is empty")
                .font(.system(size: 18, weight: .semibold))
            Text("Tap the camera tab to snap your fridge, or add items manually.")
                .font(.system(size: 15))
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
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon).font(.caption)
                }
                Text(label).font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Theme.forestGreen : Color.white)
            .foregroundStyle(isSelected ? .white : Theme.forestGreenDark)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Theme.forestGreen.opacity(0.3), lineWidth: isSelected ? 0 : 1)
            )
        }
    }
}

struct PantryItemCard: View {
    let item: PantryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: iconFor(category: item.category))
                    .font(.title2)
                    .foregroundStyle(Theme.forestGreen)
                Spacer()
                statusBadge
            }

            Text(item.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.forestGreenDark)
                .lineLimit(1)

            HStack {
                Text("\(formatted(item.quantity)) \(item.unit)")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.warmGray)

                Spacer()

                if let days = item.daysUntilExpiration {
                    Text(days >= 0 ? "\(days)d" : "expired")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(colorFor(status: item.expirationStatus))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    @ViewBuilder
    private var statusBadge: some View {
        Circle()
            .fill(colorFor(status: item.expirationStatus))
            .frame(width: 10, height: 10)
    }

    private func iconFor(category: String) -> String {
        FoodCategory(rawValue: category)?.icon ?? "bag.fill"
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
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: FoodCategory(rawValue: item.category)?.icon ?? "bag.fill")
                .font(.title3)
                .foregroundStyle(.white)

            Text(item.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            if let days = item.daysUntilExpiration {
                Text(days == 0 ? "Today" : "\(days)d left")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(12)
        .frame(width: 120, alignment: .leading)
        .background(
            LinearGradient(
                colors: [colorFor(status: item.expirationStatus), colorFor(status: item.expirationStatus).opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
