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

    private var category: FoodCategory? { FoodCategory(rawValue: item.category) }

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
            VStack(alignment: .leading, spacing: 32) {
                titleBlock

                summaryRow

                if !item.batches.isEmpty {
                    batchesSection
                } else if item.expirationDate != nil {
                    legacyExpirationSection
                }

                metaSection

                Button {
                    showingDeleteAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash").font(.system(size: 13, weight: .semibold))
                        Text("Remove from pantry")
                    }
                    .font(.text(14, weight: .semibold))
                    .foregroundStyle(Theme.coral)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .overlay(Capsule().strokeBorder(Theme.coral.opacity(0.30), lineWidth: 1))
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(Theme.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "Done" : "Edit") {
                    isEditing.toggle()
                }
                .fontWeight(.semibold)
                .foregroundStyle(Theme.graphite)
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

    // MARK: - Title

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(colorFor(status: item.expirationStatus))
                    .frame(width: 8, height: 8)
                Text(item.category.uppercased())
                    .font(.text(11, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.stone)
            }

            if isEditing {
                TextField("Name", text: $item.name)
                    .font(.display(34, weight: .regular))
                    .foregroundStyle(Theme.graphite)
                    .textFieldStyle(.plain)
            } else {
                Text(item.name)
                    .font(.display(40, weight: .regular))
                    .tracking(-0.6)
                    .foregroundStyle(Theme.graphite)
            }
        }
    }

    // MARK: - Summary

    private var summaryRow: some View {
        HStack(spacing: 0) {
            MetricTile(
                value: "\(formatted(item.totalQuantity)) \(item.unit)",
                label: "Total"
            )
            verticalRule
            MetricTile(
                value: "\(item.batches.isEmpty ? 1 : item.batches.count)",
                label: item.batches.count == 1 ? "Batch" : "Batches"
            )
            verticalRule
            MetricTile(value: earliestSummary, label: "Earliest")
        }
        .padding(.vertical, 18)
        .overlay(Hairline(), alignment: .top)
        .overlay(Hairline(), alignment: .bottom)
    }

    private var verticalRule: some View {
        Rectangle().fill(Theme.hairline).frame(width: 1, height: 28)
    }

    private var earliestSummary: String {
        guard let days = item.daysUntilExpiration else { return "—" }
        if days < 0 { return "Expired" }
        if days == 0 { return "Today" }
        return "\(days)d"
    }

    // MARK: - Batches

    private var batchesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionEyebrow(text: "Batches", trailing: "\(item.batches.count)")
                Button {
                    showingAddBatch = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                        Text("Add batch")
                    }
                    .font(.text(12, weight: .semibold))
                    .foregroundStyle(Theme.graphite)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(sortedBatches.enumerated()), id: \.element.id) { idx, batch in
                    BatchRow(
                        batch: batch,
                        unit: item.unit,
                        isEditing: isEditing,
                        onDelete: { delete(batch) }
                    )
                    if idx < sortedBatches.count - 1 { Hairline() }
                }
            }
        }
    }

    @ViewBuilder
    private var legacyExpirationSection: some View {
        if let days = item.daysUntilExpiration, let exp = item.expirationDate {
            VStack(alignment: .leading, spacing: 12) {
                SectionEyebrow(text: "Expiration")
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exp.formatted(date: .abbreviated, time: .omitted))
                            .font(.text(16, weight: .medium))
                            .foregroundStyle(Theme.graphite)
                        Text(item.expirationStatus.label)
                            .font(.text(12))
                            .foregroundStyle(colorFor(status: item.expirationStatus))
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(days >= 0 ? "\(days)" : "0")
                            .font(.numeric(28, weight: .semibold))
                            .foregroundStyle(colorFor(status: item.expirationStatus))
                        Text(days == 1 ? "day left" : "days left")
                            .font(.text(11))
                            .foregroundStyle(Theme.stone)
                    }
                }
                Button {
                    showingAddBatch = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                        Text("Add another batch")
                    }
                    .font(.text(13, weight: .medium))
                    .foregroundStyle(Theme.graphiteSoft)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundStyle(Theme.hairline)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var metaSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionEyebrow(text: "First added")
            Text(item.dateAdded.formatted(date: .abbreviated, time: .shortened))
                .font(.text(14))
                .foregroundStyle(Theme.graphiteSoft)
        }
    }

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
            HStack(alignment: .center, spacing: 14) {
                Circle()
                    .fill(colorFor(status: batch.expirationStatus))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 3) {
                    Text(addedRelative.capitalized)
                        .font(.text(13, weight: .medium))
                        .foregroundStyle(Theme.graphite)

                    if let exp = batch.expirationDate {
                        HStack(spacing: 6) {
                            Text(exp.formatted(date: .abbreviated, time: .omitted))
                            Text("·")
                            Text(daysText)
                                .foregroundStyle(colorFor(status: batch.expirationStatus))
                        }
                        .font(.text(12))
                        .foregroundStyle(Theme.stone)
                    } else {
                        Text("No expiration")
                            .font(.text(12))
                            .foregroundStyle(Theme.stone)
                    }
                }

                Spacer(minLength: 8)

                quantityStepper

                Button {
                    showingDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.stone)
                        .frame(width: 32, height: 32)
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
                .font(.text(13))
                .tint(Theme.graphite)
            }
        }
        .padding(.vertical, 14)
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
                if next == 0 { showingDeleteAlert = true } else { batch.quantity = next }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .foregroundStyle(Theme.graphite)
            }
            .buttonStyle(.plain)

            Text("\(formatted(batch.quantity)) \(unit)")
                .font(.numeric(13, weight: .medium))
                .foregroundStyle(Theme.graphite)
                .frame(minWidth: 56)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Button {
                batch.quantity += 1
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .foregroundStyle(Theme.graphite)
            }
            .buttonStyle(.plain)
        }
        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
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
                    Stepper(value: $quantity, in: 0.25...999, step: 1) {
                        Text("\(formatted(quantity)) \(unit)")
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
            .themedFormBackground()
            .navigationTitle("Add batch")
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
