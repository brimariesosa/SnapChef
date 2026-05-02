//
//  ItemDetailView.swift
//  SnapChef
//

import SwiftUI
import SwiftData

struct ItemDetailView: View {
    @Bindable var item: PantryItem
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false
    @State private var isEditing = false
    @State private var showingAddBatch = false

    var category: FoodCategory? { FoodCategory(rawValue: item.category) }
    var tint: Color { category?.color ?? Theme.forestGreen }

    private var sortedBatches: [PantryBatch] {
        item.batches.sorted { lhs, rhs in
            switch (lhs.expirationDate, rhs.expirationDate) {
            case (let l?, let r?): return l < r
            case (nil, _?): return false
            case (_?, nil): return true
            default: return lhs.dateAdded < rhs.dateAdded
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                headerCard

                summaryCard

                if !item.batches.isEmpty {
                    batchesCard
                } else if item.expirationDate != nil {
                    legacyExpirationCard
                }

                metadataCard

                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Remove from Pantry")
                    }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.1))
                    .foregroundStyle(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.top, 8)
            }
            .padding(16)
        }
        .background(
            ZStack {
                Theme.appBackgroundGradient.ignoresSafeArea()
                DecorativeBlobs().ignoresSafeArea()
            }
        )
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "Done" : "Edit") {
                    isEditing.toggle()
                }
                .fontWeight(.semibold)
            }
        }
        .alert("Remove item?", isPresented: $showingDeleteAlert) {
            Button("Remove", role: .destructive) {
                NotificationService.shared.cancelAlert(for: item)
                context.delete(item)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingAddBatch) {
            AddBatchSheet(unit: item.unit) { quantity, expiration in
                item.appendBatch(
                    quantity: quantity,
                    expirationDate: expiration,
                    in: context
                )
                NotificationService.shared.scheduleExpirationAlert(for: item)
            }
        }
    }

    // MARK: - Cards

    private var headerCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(category?.gradient ?? Theme.primaryGradient)
                    .frame(width: 110, height: 110)
                    .shadow(color: tint.opacity(0.35), radius: 16, y: 8)
                Image(systemName: category?.icon ?? "bag.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.white)
            }

            if isEditing {
                TextField("Name", text: $item.name)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 40)
            } else {
                Text(item.name)
                    .font(.display(22))
                    .foregroundStyle(Theme.forestGreenDark)
            }

            Text(item.category)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.warmGray)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }

    private var summaryCard: some View {
        HStack(spacing: 0) {
            summaryTile(
                icon: "number.circle.fill",
                value: "\(formatted(item.totalQuantity)) \(item.unit)",
                label: "Total",
                color: tint
            )
            divider
            summaryTile(
                icon: "tray.full.fill",
                value: "\(item.batches.isEmpty ? 1 : item.batches.count)",
                label: item.batches.count == 1 ? "Batch" : "Batches",
                color: Theme.peach
            )
            divider
            summaryTile(
                icon: "calendar",
                value: earliestSummary,
                label: "Earliest",
                color: colorFor(status: item.expirationStatus)
            )
        }
        .padding(.vertical, 14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.15))
            .frame(width: 1, height: 36)
    }

    private func summaryTile(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.forestGreenDark)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.warmGray)
        }
        .frame(maxWidth: .infinity)
    }

    private var earliestSummary: String {
        guard let days = item.daysUntilExpiration else { return "—" }
        if days < 0 { return "Expired" }
        if days == 0 { return "Today" }
        return "\(days)d"
    }

    private var batchesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Batches", systemImage: "square.stack.3d.up.fill")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.forestGreen)
                Spacer()
                Button {
                    showingAddBatch = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Batch")
                    }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.forestGreen)
                }
            }

            VStack(spacing: 8) {
                ForEach(sortedBatches) { batch in
                    BatchRow(
                        batch: batch,
                        unit: item.unit,
                        isEditing: isEditing,
                        onDelete: { delete(batch) }
                    )
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }

    // Legacy display for items created before batches existed
    @ViewBuilder
    private var legacyExpirationCard: some View {
        if let days = item.daysUntilExpiration, let exp = item.expirationDate {
            VStack(alignment: .leading, spacing: 12) {
                Label("Expiration", systemImage: "calendar.badge.clock")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.forestGreen)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exp.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                        Text(item.expirationStatus.label)
                            .font(.caption)
                            .foregroundStyle(colorFor(status: item.expirationStatus))
                    }
                    Spacer()
                    VStack {
                        Text(days >= 0 ? "\(days)" : "0")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(colorFor(status: item.expirationStatus))
                        Text(days == 1 ? "day left" : "days left")
                            .font(.caption)
                            .foregroundStyle(Theme.warmGray)
                    }
                }

                Button {
                    showingAddBatch = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add another batch")
                    }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.forestGreen)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Theme.forestGreen.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
        }
    }

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("First added", systemImage: "clock")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.forestGreen)
            Text(item.dateAdded.formatted(date: .abbreviated, time: .shortened))
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Theme.warmGray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }

    // MARK: - Actions

    private func delete(_ batch: PantryBatch) {
        context.delete(batch)
        item.batches.removeAll { $0.id == batch.id }
        if item.batches.isEmpty && item.quantity <= 0 {
            NotificationService.shared.cancelAlert(for: item)
            context.delete(item)
            dismiss()
        } else {
            NotificationService.shared.scheduleExpirationAlert(for: item)
        }
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
}

// MARK: - Batch row

struct BatchRow: View {
    @Bindable var batch: PantryBatch
    let unit: String
    let isEditing: Bool
    let onDelete: () -> Void

    @State private var showingDeleteAlert = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(colorFor(status: batch.expirationStatus).opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: iconForStatus)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(colorFor(status: batch.expirationStatus))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(addedRelative.capitalized)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.forestGreenDark)

                    if let exp = batch.expirationDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                            Text(exp.formatted(date: .abbreviated, time: .omitted))
                            Text("•")
                            Text(daysText)
                                .foregroundStyle(colorFor(status: batch.expirationStatus))
                        }
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Theme.warmGray)
                    } else {
                        Text("No expiration")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Theme.warmGray)
                    }
                }

                Spacer(minLength: 8)

                quantityStepper

                Button {
                    showingDeleteAlert = true
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(width: 32, height: 32)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            if isEditing && batch.expirationDate != nil {
                DatePicker(
                    "Expires",
                    selection: Binding(
                        get: { batch.expirationDate ?? Date() },
                        set: { batch.expirationDate = $0 }
                    ),
                    displayedComponents: .date
                )
                .font(.system(size: 13, design: .rounded))
                .tint(Theme.forestGreen)
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(colorFor(status: batch.expirationStatus).opacity(0.25), lineWidth: 1)
        )
        .alert("Remove this batch?", isPresented: $showingDeleteAlert) {
            Button("Remove", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove \(formatted(batch.quantity)) \(unit) from the pantry.")
        }
    }

    private var quantityStepper: some View {
        HStack(spacing: 0) {
            Button {
                let next = max(0, batch.quantity - 1)
                if next == 0 {
                    showingDeleteAlert = true
                } else {
                    batch.quantity = next
                }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(Theme.forestGreen)
            }
            .buttonStyle(.plain)

            Text("\(formatted(batch.quantity)) \(unit)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.forestGreenDark)
                .frame(minWidth: 60)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Button {
                batch.quantity += 1
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(Theme.forestGreen)
            }
            .buttonStyle(.plain)
        }
        .background(Theme.forestGreen.opacity(0.08))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(Theme.forestGreen.opacity(0.2), lineWidth: 1)
        )
    }

    private var iconForStatus: String {
        switch batch.expirationStatus {
        case .fresh: return "checkmark"
        case .soon: return "clock"
        case .urgent: return "exclamationmark"
        case .expired: return "xmark"
        case .unknown: return "questionmark"
        }
    }

    private var addedRelative: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "added \(formatter.localizedString(for: batch.dateAdded, relativeTo: Date()))"
    }

    private var daysText: String {
        guard let days = batch.daysUntilExpiration else { return "—" }
        if days < 0 { return "expired" }
        if days == 0 { return "today" }
        if days == 1 { return "1 day left" }
        return "\(days) days left"
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
}

// MARK: - Add Batch sheet

struct AddBatchSheet: View {
    let unit: String
    let onAdd: (Double, Date?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var quantity: Double = 1
    @State private var hasExpiration = true
    @State private var expirationDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!

    var body: some View {
        NavigationStack {
            Form {
                Section("Quantity") {
                    HStack {
                        Stepper(value: $quantity, in: 0.25...999, step: 1) {
                            Text("\(formatted(quantity)) \(unit)")
                        }
                    }
                }

                Section("Expiration") {
                    Toggle("Track expiration", isOn: $hasExpiration)
                    if hasExpiration {
                        DatePicker(
                            "Expires",
                            selection: $expirationDate,
                            in: Date()...,
                            displayedComponents: .date
                        )
                    }
                }
            }
            .navigationTitle("Add Batch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        onAdd(quantity, hasExpiration ? expirationDate : nil)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(quantity <= 0)
                }
            }
        }
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
}
