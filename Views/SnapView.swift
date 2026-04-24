//
//  SnapView.swift
//  SnapChef
//

import SwiftUI
import SwiftData

struct SnapView: View {
    @Environment(\.modelContext) private var context
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var capturedImage: UIImage?
    @State private var isScanning = false
    @State private var detectedItems: [DetectedIngredient] = []
    @State private var selectedForAdd: Set<DetectedIngredient> = []
    @State private var showingResults = false
    @State private var cameraPermissionDenied = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.cream.opacity(0.4).ignoresSafeArea()

                VStack(spacing: 24) {
                    heroCard

                    if let image = capturedImage {
                        capturedImageView(image)
                    } else {
                        placeholderView
                    }

                    Spacer()

                    actionButtons
                }
                .padding(20)

                if isScanning {
                    scanningOverlay
                }
            }
            .navigationTitle("Snap & Scan")
            .fullScreenCover(isPresented: $showingCamera) {
                ImagePicker(image: $capturedImage, sourceType: .camera)
                    .ignoresSafeArea()
                    .onDisappear {
                        if capturedImage != nil {
                            Task { await scanImage() }
                        }
                    }
            }
            .sheet(isPresented: $showingPhotoLibrary) {
                ImagePicker(image: $capturedImage, sourceType: .photoLibrary)
                    .onDisappear {
                        if capturedImage != nil {
                            Task { await scanImage() }
                        }
                    }
            }
            .sheet(isPresented: $showingResults) {
                ScanResultsView(
                    detectedItems: detectedItems,
                    selectedItems: $selectedForAdd,
                    onAdd: addSelectedItems
                )
            }
            .alert("Camera Access Needed", isPresented: $cameraPermissionDenied) {
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enable camera access in Settings to scan your fridge.")
            }
        }
    }

    private var heroCard: some View {
        VStack(spacing: 8) {
            Text("Point and snap")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.forestGreenDark)
            Text("SnapChef AI identifies every ingredient automatically.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.warmGray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 80, weight: .light))
                .foregroundStyle(Theme.sage)

            Text("No photo yet")
                .font(.system(size: 15))
                .foregroundStyle(Theme.warmGray)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .background(Theme.forestGreen.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Theme.forestGreen.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8]))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func capturedImageView(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(height: 280)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                CameraPermission.check { granted in
                    if granted {
                        showingCamera = true
                    } else {
                        cameraPermissionDenied = true
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Take Photo")
                }
                .primaryButton()
            }

            Button {
                showingPhotoLibrary = true
            } label: {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                    Text("Choose from Library")
                }
                .secondaryButton()
            }

            if capturedImage != nil && !isScanning && detectedItems.isEmpty {
                Button("Scan Again") {
                    Task { await scanImage() }
                }
                .font(.system(size: 14))
                .foregroundStyle(Theme.forestGreen)
            }
        }
    }

    private var scanningOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                Text("Identifying ingredients...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                Text("AI is analyzing your photo")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    private func scanImage() async {
        guard let image = capturedImage else { return }
        isScanning = true
        detectedItems = await MockDataService.shared.identifyIngredients(from: image)
        selectedForAdd = Set(detectedItems)
        isScanning = false
        showingResults = true
    }

    private func addSelectedItems() {
        for detected in selectedForAdd {
            let expDate = Calendar.current.date(
                byAdding: .day,
                value: detected.suggestedShelfLife,
                to: Date()
            )
            let item = PantryItem(
                name: detected.name,
                category: detected.category,
                expirationDate: expDate
            )
            context.insert(item)
            NotificationService.shared.scheduleExpirationAlert(for: item)
        }

        capturedImage = nil
        detectedItems = []
        selectedForAdd = []
        showingResults = false
    }
}

// MARK: - Scan Results Sheet

struct ScanResultsView: View {
    let detectedItems: [DetectedIngredient]
    @Binding var selectedItems: Set<DetectedIngredient>
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    headerInfo

                    ForEach(detectedItems) { item in
                        DetectionRow(
                            item: item,
                            isSelected: selectedItems.contains(item)
                        ) {
                            if selectedItems.contains(item) {
                                selectedItems.remove(item)
                            } else {
                                selectedItems.insert(item)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.cream.opacity(0.4))
            .navigationTitle("We found \(detectedItems.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add \(selectedItems.count)") {
                        onAdd()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedItems.isEmpty)
                }
            }
        }
    }

    private var headerInfo: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundStyle(Theme.accent)
            Text("Tap to include or exclude items")
                .font(.system(size: 14))
                .foregroundStyle(Theme.warmGray)
            Spacer()
        }
        .padding(.bottom, 4)
    }
}

struct DetectionRow: View {
    let item: DetectedIngredient
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: FoodCategory(rawValue: item.category)?.icon ?? "bag.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.forestGreen)
                    .frame(width: 44, height: 44)
                    .background(Theme.forestGreen.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        Text(item.category)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.warmGray)

                        Text("•")
                            .foregroundStyle(Theme.warmGray)

                        Text("\(Int(item.confidence * 100))% confidence")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Theme.forestGreen : Color.gray.opacity(0.3))
            }
            .padding(12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
