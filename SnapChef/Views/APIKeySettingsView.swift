//
//  APIKeySettingsView.swift
//  SnapChef
//

import SwiftUI

struct APIKeySettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var key: String = ""
    @State private var saveError: String?
    @State private var didSave = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("sk-ant-...", text: $key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                } header: {
                    Text("Anthropic API Key")
                } footer: {
                    Text("Stored only on this device in the iOS Keychain. Get a key at console.anthropic.com.")
                }

                if let saveError {
                    Section {
                        Label(saveError, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                if didSave {
                    Section {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                if KeychainService.getAPIKey() != nil {
                    Section {
                        Button(role: .destructive) {
                            KeychainService.deleteAPIKey()
                            key = ""
                            didSave = false
                        } label: {
                            Label("Remove key", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let existing = KeychainService.getAPIKey() {
                    key = existing
                }
            }
        }
    }

    private func save() {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try KeychainService.setAPIKey(trimmed)
            saveError = nil
            withAnimation { didSave = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                dismiss()
            }
        } catch {
            saveError = "Couldn't save key (\(error.localizedDescription))"
        }
    }
}
