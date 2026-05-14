//
//  PantryView.swift
//  SnapChef
//

import SwiftUI
import SwiftData
import UserNotifications

struct PantryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PantryItem.dateAdded, order: .reverse) private var items: [PantryItem]
    @Query(sort: \AppNotification.createdAt, order: .reverse) private var notifications: [AppNotification]
    @State private var searchText = ""
    @State private var selectedCategory: String = "All"
    @State private var showingAddSheet = false
    @State private var showingNotifications = false
    @State private var showingClearConfirmation = false

    private var unreadNotificationsCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    private var filteredItems: [PantryItem] {
        items.filter { item in
            let matchesSearch = searchText.isEmpty || item.name.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategory == "All" || item.category == selectedCategory
            return matchesSearch && matchesCategory
        }
    }

    private var expiringItems: [PantryItem] {
        items.filter { $0.expirationStatus == .urgent || $0.expirationStatus == .soon }
    }

    private var freshCount: Int {
        items.filter { $0.expirationStatus == .fresh }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    titleBlock

                    metricsRow

                    if !expiringItems.isEmpty {
                        expiringSection
                    }

                    categorySection

                    listSection
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 80)
            }
            .background(Theme.canvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { Color.clear.frame(height: 1) }
            }
            .searchable(text: $searchText, prompt: "Search ingredients")
            .sheet(isPresented: $showingAddSheet) { AddItemView() }
            .sheet(isPresented: $showingNotifications) { NotificationsListView() }
            .confirmationDialog(
                "Clear your pantry?",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear Everything", role: .destructive) { clearPantry() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Removes all \(items.count) items and their batches. You can't undo this.")
            }
            .onAppear { syncNotifications() }
            .onChange(of: items.count) { _, _ in syncNotifications() }
        }
    }

    // MARK: - Sections

    private var titleBlock: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Pantry.")
                    .font(.display(40, weight: .regular))
                    .tracking(-0.6)
                    .foregroundStyle(Theme.graphite)
                Text(items.isEmpty ? "Nothing tracked yet." : "\(items.count) items, \(freshCount) fresh.")
                    .font(.text(14))
                    .foregroundStyle(Theme.stone)
            }
            Spacer()
            HStack(spacing: 10) {
                IconChipButton(icon: "bell", badge: unreadNotificationsCount) {
                    showingNotifications = true
                }
                IconChipButton(icon: "plus", filled: true) {
                    showingAddSheet = true
                }
                if !items.isEmpty {
                    IconChipButton(icon: "trash", tint: Theme.coral) {
                        showingClearConfirmation = true
                    }
                }
            }
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 0) {
            MetricTile(value: "\(items.count)", label: "IN PANTRY", tint: Theme.graphite)
            verticalRule
            MetricTile(
                value: "\(expiringItems.count)",
                label: "USE SOON",
                tint: expiringItems.isEmpty ? Theme.graphite : Theme.accent
            )
            verticalRule
            MetricTile(
                value: "\(freshCount)",
                label: "FRESH",
                tint: freshCount > 0 ? Theme.forest : Theme.graphite
            )
        }
        .padding(.vertical, 20)
        .overlay(Hairline(), alignment: .top)
        .overlay(Hairline(), alignment: .bottom)
    }

    private var verticalRule: some View {
        Rectangle().fill(Theme.hairline).frame(width: 1, height: 28)
    }

    private var expiringSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionEyebrow(text: "Use soon", trailing: "\(expiringItems.count)")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(expiringItems) { item in
                        NavigationLink(destination: ItemDetailView(item: item)) {
                            ExpiringCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionEyebrow(text: "Categories")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    QuietChip(label: "All", isSelected: selectedCategory == "All") {
                        selectedCategory = "All"
                    }
                    ForEach(FoodCategory.allCases, id: \.self) { cat in
                        QuietChip(
                            label: cat.rawValue,
                            icon: cat.icon,
                            isSelected: selectedCategory == cat.rawValue
                        ) {
                            selectedCategory = cat.rawValue
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    @ViewBuilder
    private var listSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionEyebrow(text: "Ingredients", trailing: "\(filteredItems.count)")

            if filteredItems.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(filteredItems.enumerated()), id: \.element.id) { idx, item in
                        NavigationLink(destination: ItemDetailView(item: item)) {
                            PantryRow(item: item)
                        }
                        .buttonStyle(.plain)
                        if idx < filteredItems.count - 1 {
                            Hairline()
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your pantry is empty.")
                .font(.display(24, weight: .regular))
                .foregroundStyle(Theme.graphite)
            Text("Snap your fridge or add an item manually to start tracking what you have.")
                .font(.text(15))
                .foregroundStyle(Theme.stone)
                .lineSpacing(2)
            HStack {
                Button { showingAddSheet = true } label: {
                    Text("Add First Item").primaryButton()
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.top, 6)
        }
        .padding(.vertical, 28)
    }

    private func clearPantry() {
        for item in items { context.delete(item) }
        try? context.save()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private func syncNotifications() {
        InAppNotificationSync.sync(
            items: items,
            existing: notifications,
            context: context
        )
    }
}

// MARK: - Small components

struct IconChipButton: View {
    let icon: String
    var tint: Color = Theme.graphite
    var filled: Bool = false
    var badge: Int = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(filled ? AnyShapeStyle(Theme.graphite) : AnyShapeStyle(Theme.bone))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Circle().strokeBorder(filled ? Color.clear : Theme.hairline, lineWidth: 1)
                    )
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(filled ? .white : tint)
                if badge > 0 {
                    Circle()
                        .fill(Theme.coral)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Theme.canvas, lineWidth: 2))
                        .offset(x: 12, y: -12)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct PantryRow: View {
    let item: PantryItem

    private var category: FoodCategory? { FoodCategory(rawValue: item.category) }

    var body: some View {
        HStack(spacing: 14) {
            // Tiny status dot rail — single accent, not a gradient disc
            Circle()
                .fill(colorFor(status: item.expirationStatus))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.text(16, weight: .medium))
                    .foregroundStyle(Theme.graphite)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(item.category)
                    if item.batches.count > 1 {
                        Text("·")
                        Text("\(item.batches.count) batches")
                    }
                }
                .font(.text(12))
                .foregroundStyle(Theme.stone)
            }

            Spacer()

            Text("\(formatted(item.totalQuantity)) \(item.unit)")
                .font(.numeric(14, weight: .medium))
                .foregroundStyle(Theme.graphiteSoft)

            if let days = item.daysUntilExpiration {
                Text(days < 0 ? "expired" : "\(days)d")
                    .font(.numeric(13, weight: .medium))
                    .foregroundStyle(colorFor(status: item.expirationStatus))
                    .frame(minWidth: 44, alignment: .trailing)
            } else {
                Text("—")
                    .font(.numeric(13))
                    .foregroundStyle(Theme.stoneLight)
                    .frame(minWidth: 44, alignment: .trailing)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.stoneLight)
        }
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
}

struct ExpiringCard: View {
    let item: PantryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                StatusPill(status: item.expirationStatus, compact: true)
                Spacer()
                if let days = item.daysUntilExpiration {
                    Text(days < 0 ? "expired" : days == 0 ? "today" : "\(days)d")
                        .font(.numeric(12, weight: .semibold))
                        .foregroundStyle(colorFor(status: item.expirationStatus))
                }
            }
            Spacer(minLength: 12)
            Text(item.name)
                .font(.text(15, weight: .semibold))
                .foregroundStyle(Theme.graphite)
                .lineLimit(1)
            Text(item.category)
                .font(.text(11))
                .foregroundStyle(Theme.stone)
        }
        .padding(14)
        .frame(width: 150, height: 120, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.bone)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }
}

// MARK: - Notifications

struct NotificationsListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \AppNotification.createdAt, order: .reverse) private var notifications: [AppNotification]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ScreenTitle(title: "Alerts.", subtitle: subtitle)

                    if notifications.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(notifications.enumerated()), id: \.element.id) { idx, n in
                                NotificationRow(notification: n)
                                    .onTapGesture {
                                        if !n.isRead { n.isRead = true }
                                    }
                                if idx < notifications.count - 1 { Hairline() }
                            }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Theme.canvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.foregroundStyle(Theme.graphite)
                }
                if !notifications.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Mark all as read") {
                                for n in notifications where !n.isRead { n.isRead = true }
                            }
                            Button("Clear all", role: .destructive) {
                                for n in notifications { context.delete(n) }
                            }
                        } label: {
                            Image(systemName: "ellipsis").foregroundStyle(Theme.graphite)
                        }
                    }
                }
            }
        }
    }

    private var subtitle: String {
        notifications.isEmpty ? "No alerts." : "\(notifications.count) total, \(notifications.filter { !$0.isRead }.count) unread."
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Nothing to worry about.")
                .font(.display(22, weight: .regular))
                .foregroundStyle(Theme.graphite)
            Text("You'll see alerts here when pantry items are expiring in the next 3 days.")
                .font(.text(14))
                .foregroundStyle(Theme.stone)
        }
        .padding(.vertical, 20)
    }
}

struct NotificationRow: View {
    let notification: AppNotification

    private var tint: Color {
        switch notification.daysUntilExpiry {
        case 0: return Theme.coral
        case 1, 2: return Theme.accent
        default: return Theme.butter
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle().fill(tint).frame(width: 8, height: 8).padding(.top, 7)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(notification.title)
                        .font(.text(15, weight: .semibold))
                        .foregroundStyle(Theme.graphite)
                    if !notification.isRead {
                        Circle().fill(Theme.forest).frame(width: 6, height: 6)
                    }
                    Spacer()
                    Text(notification.createdAt, style: .relative)
                        .font(.text(11))
                        .foregroundStyle(Theme.stone)
                }
                Text(notification.body)
                    .font(.text(13))
                    .foregroundStyle(Theme.graphiteSoft)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 14)
    }
}
