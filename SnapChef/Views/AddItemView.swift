//
//  AddItemView.swift
//  SnapChef
//

import SwiftUI
import SwiftData

//comment

struct AddItemView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var existingItems: [PantryItem]

    @State private var name = ""
    @State private var quantity: Double = 1
    @State private var unit = "item"
    @State private var category: FoodCategory = .produce
    @State private var hasExpiration = true
    @State private var expirationDate: Date = Calendar.current.date(
        byAdding: .day,
        value: ExpirationDefaults.days(for: .produce),
        to: Date()
    )!
    @State private var userEditedExpiration = false

    let units = ["item", "lb", "oz", "cup", "tbsp", "tsp", "piece", "bunch", "container", "gallon"]

    private var suggestedDays: Int {
        ExpirationDefaults.days(forName: name, category: category)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ingredient") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)

                    Picker("Category", selection: $category) {
                        ForEach(FoodCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }
                }

                Section("Quantity") {
                    HStack {
                        TextField("Amount", value: $quantity, format: .number)
                            .keyboardType(.decimalPad)
                        Picker("Unit", selection: $unit) {
                            ForEach(units, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section("Expiration") {
                    Toggle("Track expiration", isOn: $hasExpiration)
                    if hasExpiration {
                        DatePicker(
                            "Expires",
                            selection: Binding(
                                get: { expirationDate },
                                set: {
                                    expirationDate = $0
                                    userEditedExpiration = true
                                }
                            ),
                            in: Date()...,
                            displayedComponents: .date
                        )
                        if !userEditedExpiration {
                            Text("Suggested for \(category.rawValue): \(suggestedDays) day\(suggestedDays == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: category) { _, _ in
                refreshSuggestedExpiration()
            }
            .onChange(of: name) { _, _ in
                refreshSuggestedExpiration()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func refreshSuggestedExpiration() {
        guard !userEditedExpiration else { return }
        if let newDate = Calendar.current.date(byAdding: .day, value: suggestedDays, to: Date()) {
            expirationDate = newDate
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let exp = hasExpiration ? expirationDate : nil

        if let existing = existingItems.first(where: {
            $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            existing.appendBatch(quantity: quantity, expirationDate: exp, in: context)
            NotificationService.shared.scheduleExpirationAlert(for: existing)
        } else {
            let item = PantryItem(
                name: trimmed,
                quantity: 0,
                unit: unit,
                category: category.rawValue,
                expirationDate: nil
            )
            context.insert(item)
            item.appendBatch(quantity: quantity, expirationDate: exp, in: context)
            NotificationService.shared.scheduleExpirationAlert(for: item)
        }

        dismiss()
    }
}
