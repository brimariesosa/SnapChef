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

    @State private var name = ""
    @State private var quantity: Double = 1
    @State private var unit = "item"
    @State private var category: FoodCategory = .produce
    @State private var hasExpiration = true
    @State private var expirationDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!

    let units = ["item", "lb", "oz", "cup", "tbsp", "tsp", "piece", "bunch", "container", "gallon"]

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
                            selection: $expirationDate,
                            in: Date()...,
                            displayedComponents: .date
                        )
                    }
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
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

    private func save() {
        let item = PantryItem(
            name: name.trimmingCharacters(in: .whitespaces),
            quantity: quantity,
            unit: unit,
            category: category.rawValue,
            expirationDate: hasExpiration ? expirationDate : nil
        )
        context.insert(item)
        NotificationService.shared.scheduleExpirationAlert(for: item)
        dismiss()
    }
}
