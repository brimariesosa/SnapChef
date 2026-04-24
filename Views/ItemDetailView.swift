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

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard

                quantityCard

                if item.expirationDate != nil {
                    expirationCard
                }

                metadataCard

                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Remove from Pantry")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.1))
                    .foregroundStyle(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, 12)
            }
            .padding(16)
        }
        .background(Theme.cream.opacity(0.4))
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
    }

    private var headerCard: some View {
        VStack(spacing: 12) {
            Image(systemName: FoodCategory(rawValue: item.category)?.icon ?? "bag.fill")
                .font(.system(size: 60, weight: .light))
                .foregroundStyle(Theme.forestGreen)
                .frame(width: 120, height: 120)
                .background(Theme.forestGreen.opacity(0.1))
                .clipShape(Circle())

            if isEditing {
                TextField("Name", text: $item.name)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 40)
            } else {
                Text(item.name)
                    .font(.title2.weight(.bold))
            }

            Text(item.category)
                .font(.subheadline)
                .foregroundStyle(Theme.warmGray)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var quantityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quantity", systemImage: "number.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.forestGreen)

            if isEditing {
                HStack {
                    Stepper(value: $item.quantity, in: 0...999, step: 1) {
                        Text("\(formatted(item.quantity)) \(item.unit)")
                    }
                }
            } else {
                Text("\(formatted(item.quantity)) \(item.unit)")
                    .font(.title3.weight(.medium))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var expirationCard: some View {
        if let days = item.daysUntilExpiration {
            VStack(alignment: .leading, spacing: 12) {
                Label("Expiration", systemImage: "calendar.badge.clock")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.forestGreen)

                if isEditing, let exp = item.expirationDate {
                    DatePicker(
                        "Expires",
                        selection: Binding(
                            get: { exp },
                            set: { item.expirationDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.expirationDate!.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 17, weight: .medium))
                            Text(item.expirationStatus.label)
                                .font(.caption)
                                .foregroundStyle(colorFor(status: item.expirationStatus))
                        }
                        Spacer()
                        VStack {
                            Text(days >= 0 ? "\(days)" : "0")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(colorFor(status: item.expirationStatus))
                            Text(days == 1 ? "day left" : "days left")
                                .font(.caption)
                                .foregroundStyle(Theme.warmGray)
                        }
                    }
                }
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Added", systemImage: "clock")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.forestGreen)
            Text(item.dateAdded.formatted(date: .abbreviated, time: .shortened))
                .font(.system(size: 15))
                .foregroundStyle(Theme.warmGray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
}
