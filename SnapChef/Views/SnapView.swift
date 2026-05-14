//
//  SnapView.swift
//  SnapChef
//

import SwiftUI
import SwiftData

struct SnapView: View {
    @Environment(\.modelContext) private var context
    @Query private var pantryItems: [PantryItem]

    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var showingDemoLibrary = false
    @State private var capturedImage: UIImage?
    @State private var isScanning = false
    @State private var detectedItems: [DetectedIngredient] = []
    @State private var showingResults = false
    @State private var cameraPermissionDenied = false

    @State private var pendingDemoRecipe: Recipe?
    @State private var scanError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.canvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        titleBlock
                        viewport
                        actionStack
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }

                if isScanning { scanningOverlay }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { Color.clear.frame(height: 1) } }
            .fullScreenCover(isPresented: $showingCamera) {
                ImagePicker(image: $capturedImage, sourceType: .camera)
                    .ignoresSafeArea()
                    .onDisappear {
                        if capturedImage != nil {
                            pendingDemoRecipe = nil
                            Task { await scanImage() }
                        }
                    }
            }
            .sheet(isPresented: $showingPhotoLibrary) {
                ImagePicker(image: $capturedImage, sourceType: .photoLibrary)
                    .onDisappear {
                        if capturedImage != nil {
                            pendingDemoRecipe = nil
                            Task { await scanImage() }
                        }
                    }
            }
            .sheet(isPresented: $showingDemoLibrary) {
                DemoLibraryPicker { photo in
                    let image = DemoLibrary.render(photo)
                    capturedImage = image
                    pendingDemoRecipe = DemoLibrary.recipe(for: photo)
                    showingDemoLibrary = false
                    Task { await scanImage() }
                }
            }
            .sheet(isPresented: $showingResults, onDismiss: resetAfterScan) {
                ScanResultsView(
                    detectedItems: detectedItems,
                    pantryItems: pantryItems,
                    onAdd: addSelectedItems
                )
            }
            .alert("Scan Failed", isPresented: Binding(
                get: { scanError != nil },
                set: { if !$0 { scanError = nil } }
            )) {
                Button("OK", role: .cancel) { scanError = nil }
            } message: { Text(scanError ?? "") }
            .alert("Camera access needed", isPresented: $cameraPermissionDenied) {
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

    // MARK: - Sections

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Snap.")
                .font(.display(40, weight: .regular))
                .tracking(-0.6)
                .foregroundStyle(Theme.graphite)
            Text("Point your camera. Claude reads every ingredient in seconds.")
                .font(.text(14))
                .foregroundStyle(Theme.stone)
                .lineSpacing(2)
        }
    }

    private var viewport: some View {
        Group {
            if let image = capturedImage {
                capturedImageView(image)
            } else {
                placeholderViewport
            }
        }
    }

    private var placeholderViewport: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.bone, Theme.canvasSoft],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
                .overlay(
                    // Subtle warm tint so it doesn't feel sterile
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [Theme.mint.opacity(0.10), .clear],
                                center: .center, startRadius: 8, endRadius: 140
                            )
                        )
                )

            PulsingRing(color: Theme.forest.opacity(0.55), size: 160)

            VStack(spacing: 10) {
                Image(systemName: "viewfinder")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(Theme.forest)
                Text("Ready to scan")
                    .font(.display(16, weight: .regular))
                    .foregroundStyle(Theme.graphite)
                Text("Take or choose a photo")
                    .font(.text(12))
                    .foregroundStyle(Theme.stone)
            }
        }
        .frame(maxWidth: 280)
        .frame(height: 240)
        .frame(maxWidth: .infinity)
        .shadow(color: Theme.forestDark.opacity(0.10), radius: 20, x: 0, y: 12)
        .shadow(color: Theme.graphite.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private func capturedImageView(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: 280)
            .frame(height: 240)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: Theme.graphite.opacity(0.18), radius: 16, x: 0, y: 10)
    }

    private var actionStack: some View {
        VStack(spacing: 14) {
            Button {
                CameraPermission.check { granted in
                    if granted { showingCamera = true } else { cameraPermissionDenied = true }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera").font(.system(size: 13, weight: .semibold))
                    Text("Take photo")
                }
                .primaryButton()
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                Button {
                    showingPhotoLibrary = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "photo").font(.system(size: 12, weight: .semibold))
                        Text("Library")
                    }
                    .secondaryButton()
                }
                .buttonStyle(.plain)

                Button {
                    showingDemoLibrary = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles").font(.system(size: 12, weight: .semibold))
                        Text("Demo")
                    }
                    .font(.text(14, weight: .semibold))
                    .foregroundStyle(Theme.berry)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(Theme.berry.opacity(0.10)))
                    .overlay(Capsule().strokeBorder(Theme.berry.opacity(0.22), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)

            if capturedImage != nil && !isScanning && detectedItems.isEmpty {
                Button("Scan again") { Task { await scanImage() } }
                    .font(.text(13, weight: .medium))
                    .foregroundStyle(Theme.forest)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var scanningOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 18) {
                PulsingRing(color: .white, size: 100)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                    )
                Text("Identifying ingredients…")
                    .font(.display(17, weight: .regular))
                    .foregroundStyle(.white)
            }
            .padding(36)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    // MARK: - Actions

    private func scanImage() async {
        guard let image = capturedImage else { return }
        isScanning = true
        defer { isScanning = false }

        if let demo = pendingDemoRecipe {
            detectedItems = await MockDataService.shared.identifyIngredients(for: demo)
            showingResults = true
            return
        }

        do {
            let result = try await ClaudeAPIClient.shared.analyze(image: image)
            detectedItems = result.ingredients
            showingResults = true
        } catch let error as ClaudeAPIClient.APIError {
            scanError = error.errorDescription
        } catch {
            scanError = error.localizedDescription
        }
    }

    private func addSelectedItems(_ confirmed: [DetectedIngredient]) {
        for detected in confirmed {
            let expDate = detected.detectedExpirationDate

            if let existing = pantryItems.first(where: {
                $0.name.localizedCaseInsensitiveCompare(detected.name) == .orderedSame
            }) {
                existing.appendBatch(quantity: 1, expirationDate: expDate, in: context)
                NotificationService.shared.scheduleExpirationAlert(for: existing)
            } else {
                let item = PantryItem(
                    name: detected.name,
                    quantity: 0,
                    category: detected.category,
                    expirationDate: nil
                )
                context.insert(item)
                item.appendBatch(quantity: 1, expirationDate: expDate, in: context)
                NotificationService.shared.scheduleExpirationAlert(for: item)
            }
        }
    }

    private func resetAfterScan() {
        capturedImage = nil
        detectedItems = []
        pendingDemoRecipe = nil
    }
}

// MARK: - Demo Library Picker

struct DemoLibraryPicker: View {
    let onPick: (DemoRecipePhoto) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var seedingState: SeedState = .idle

    enum SeedState: Equatable {
        case idle, seeding
        case success(Int)
        case failure(String)
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Demo library.")
                            .font(.display(32, weight: .regular))
                            .tracking(-0.5)
                            .foregroundStyle(Theme.graphite)
                        Text("Tap a photo to scan it. Each maps to a recipe so you can demo the full flow.")
                            .font(.text(13))
                            .foregroundStyle(Theme.stone)
                            .lineSpacing(2)
                    }

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(DemoLibrary.photos) { photo in
                            Button { onPick(photo) } label: { DemoPhotoCard(photo: photo) }
                                .buttonStyle(.plain)
                        }
                    }

                    seedSection
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 8)
                .padding(.bottom, 40)
            }
            .background(Theme.canvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Theme.graphite)
                }
            }
        }
    }

    private var seedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionEyebrow(text: "Seed iOS Photos app")
            Text("Saves these demo photos to Photos so you can pick them through the regular library flow.")
                .font(.text(13))
                .foregroundStyle(Theme.stone)
                .lineSpacing(2)

            Button {
                seed()
            } label: {
                HStack(spacing: 8) {
                    if seedingState == .seeding {
                        ProgressView().tint(Theme.graphite).controlSize(.small)
                    } else {
                        Image(systemName: "square.and.arrow.down").font(.system(size: 13, weight: .semibold))
                    }
                    Text(seedingState == .seeding ? "Saving…" : "Seed demo photos")
                }
                .secondaryButton()
            }
            .disabled(seedingState == .seeding)

            switch seedingState {
            case .success(let count):
                Label("Saved \(count) photo\(count == 1 ? "" : "s") to Photos.", systemImage: "checkmark.circle")
                    .font(.text(12))
                    .foregroundStyle(Theme.forest)
            case .failure(let message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.text(12))
                    .foregroundStyle(Theme.coral)
            default: EmptyView()
            }
        }
        .padding(.top, 8)
    }

    private func seed() {
        seedingState = .seeding
        DemoLibrary.seedToPhotoLibrary { result in
            switch result {
            case .success(let count): seedingState = .success(count)
            case .failure(let error): seedingState = .failure(error.localizedDescription)
            }
        }
    }
}

struct DemoPhotoCard: View {
    let photo: DemoRecipePhoto

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Theme.canvasSoft

            Image(systemName: photo.symbol)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Theme.graphiteSoft)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 0) {
                Text(photo.recipeTitle)
                    .font(.text(13, weight: .semibold))
                    .foregroundStyle(Theme.graphite)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }
}

// MARK: - Scan Results Sheet

struct ScanResultsView: View {
    let pantryItems: [PantryItem]
    let onAdd: ([DetectedIngredient]) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var items: [DetectedIngredient]
    @State private var selected: Set<UUID>
    @State private var editingId: UUID?
    @State private var showingAddCustom = false
    @State private var didAdd = false
    @State private var showingRecipeScopeDialog = false

    @State private var showingDuplicateSheet = false
    @State private var pendingFresh: [DetectedIngredient] = []
    @State private var pendingDuplicates: [DuplicateChoice] = []
    @State private var duplicateChoices: [UUID: Bool] = [:]

    init(
        detectedItems: [DetectedIngredient],
        pantryItems: [PantryItem],
        onAdd: @escaping ([DetectedIngredient]) -> Void
    ) {
        self.pantryItems = pantryItems
        self.onAdd = onAdd
        self._items = State(initialValue: detectedItems)
        self._selected = State(initialValue: Set(detectedItems.map { $0.id }))
    }

    private var selectedItems: [DetectedIngredient] {
        items.filter { selected.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    titleBlock
                    detectionList
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Theme.canvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(didAdd ? "Done" : "Cancel") { dismiss() }
                        .foregroundStyle(Theme.graphite)
                }
            }
            .safeAreaInset(edge: .bottom) { bottomActions }
            .sheet(isPresented: $showingAddCustom) {
                AddCustomDetectionSheet { newItem in
                    items.append(newItem)
                    selected.insert(newItem.id)
                }
            }
            .sheet(isPresented: $showingDuplicateSheet) {
                DuplicateConfirmationSheet(
                    duplicates: pendingDuplicates,
                    choices: $duplicateChoices,
                    onConfirm: confirmDuplicates,
                    onCancel: {
                        showingDuplicateSheet = false
                        pendingFresh = []
                        pendingDuplicates = []
                        duplicateChoices = [:]
                    }
                )
            }
            .confirmationDialog(
                "Recipe ideas from…",
                isPresented: $showingRecipeScopeDialog,
                titleVisibility: .visible
            ) {
                Button("This photo only") { dispatchRecipes(.photoOnly) }
                Button("Photo + my pantry") { dispatchRecipes(.photoPlusPantry) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Where should Claude pull the ingredients from?")
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(didAdd ? "Added." : "Scan results.")
                .font(.display(32, weight: .regular))
                .tracking(-0.5)
                .foregroundStyle(Theme.graphite)
            Text(didAdd
                 ? "Items have been added to your pantry."
                 : "Tap to edit. Uncheck anything we got wrong.")
                .font(.text(13))
                .foregroundStyle(Theme.stone)
                .lineSpacing(2)
        }
    }

    private var detectionList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionEyebrow(text: "Detected", trailing: "\(items.count)")

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    if editingId == item.id {
                        EditDetectionRow(
                            item: bindingFor(item),
                            onSave: { editingId = nil },
                            onDelete: {
                                editingId = nil
                                items.removeAll { $0.id == item.id }
                                selected.remove(item.id)
                            }
                        )
                    } else {
                        DetectionRow(
                            item: item,
                            isSelected: selected.contains(item.id),
                            isAlreadyInPantry: existingItem(for: item) != nil,
                            onToggle: {
                                if selected.contains(item.id) {
                                    selected.remove(item.id)
                                } else {
                                    selected.insert(item.id)
                                }
                            },
                            onEdit: { editingId = item.id }
                        )
                    }
                    if idx < items.count - 1 { Hairline() }
                }
            }

            Button {
                showingAddCustom = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus").font(.system(size: 12, weight: .semibold))
                    Text("Add item the scan missed")
                }
                .font(.text(13, weight: .medium))
                .foregroundStyle(Theme.graphiteSoft)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(Theme.hairline)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }

    private var bottomActions: some View {
        VStack(spacing: 10) {
            Button {
                handleAddTapped()
            } label: {
                Text(didAdd ? "Added to pantry" : "Add \(selectedItems.count) to pantry")
                    .widePrimaryButton()
            }
            .buttonStyle(.plain)
            .disabled(selectedItems.isEmpty || didAdd)

            Button {
                showingRecipeScopeDialog = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "book.closed").font(.system(size: 12, weight: .semibold))
                    Text("Get recipe ideas")
                }
                .font(.text(15, weight: .semibold))
                .foregroundStyle(Theme.graphite)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().fill(Theme.bone))
                .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(selectedItems.isEmpty)
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .background(.ultraThinMaterial)
    }

    private func dispatchRecipes(_ scope: RecipeGenerationRequest.Scope) {
        let names = selectedItems.map { $0.name }
        appState.pendingRecipeRequest = RecipeGenerationRequest(
            scope: scope,
            detectedNames: names
        )
        appState.selectedTab = 1
        dismiss()
    }

    private func handleAddTapped() {
        let chosen = selectedItems
        var fresh: [DetectedIngredient] = []
        var duplicates: [DuplicateChoice] = []

        for detected in chosen {
            if let existing = pantryItems.first(where: {
                $0.name.localizedCaseInsensitiveCompare(detected.name) == .orderedSame
            }) {
                duplicates.append(DuplicateChoice(detected: detected, existing: existing))
            } else {
                fresh.append(detected)
            }
        }

        if duplicates.isEmpty {
            commit(fresh)
            return
        }

        pendingFresh = fresh
        pendingDuplicates = duplicates
        duplicateChoices = Dictionary(
            uniqueKeysWithValues: duplicates.map { ($0.detected.id, true) }
        )
        showingDuplicateSheet = true
    }

    private func confirmDuplicates() {
        let confirmed = pendingDuplicates
            .filter { duplicateChoices[$0.detected.id] == true }
            .map { $0.detected }
        let toCommit = pendingFresh + confirmed

        showingDuplicateSheet = false
        pendingFresh = []
        pendingDuplicates = []
        duplicateChoices = [:]

        commit(toCommit)
    }

    private func commit(_ confirmed: [DetectedIngredient]) {
        guard !confirmed.isEmpty else {
            withAnimation { didAdd = true }
            return
        }
        onAdd(confirmed)
        withAnimation { didAdd = true }
    }

    private func bindingFor(_ item: DetectedIngredient) -> Binding<DetectedIngredient> {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return .constant(item)
        }
        return $items[index]
    }

    private func existingItem(for detected: DetectedIngredient) -> PantryItem? {
        pantryItems.first {
            $0.name.localizedCaseInsensitiveCompare(detected.name) == .orderedSame
        }
    }
}

// MARK: - Duplicate confirmation

struct DuplicateChoice: Identifiable, Hashable {
    let detected: DetectedIngredient
    let existing: PantryItem
    var id: UUID { detected.id }
}

struct DuplicateConfirmationSheet: View {
    let duplicates: [DuplicateChoice]
    @Binding var choices: [UUID: Bool]
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    var addCount: Int {
        duplicates.filter { choices[$0.detected.id] == true }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Already in pantry.")
                            .font(.display(28, weight: .regular))
                            .tracking(-0.5)
                            .foregroundStyle(Theme.graphite)
                        Text("These items already exist. Add another batch with a fresh expiration date?")
                            .font(.text(13))
                            .foregroundStyle(Theme.stone)
                            .lineSpacing(2)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(duplicates.enumerated()), id: \.element.id) { idx, dup in
                            DuplicateRow(
                                dup: dup,
                                isOn: Binding(
                                    get: { choices[dup.detected.id] ?? true },
                                    set: { choices[dup.detected.id] = $0 }
                                )
                            )
                            if idx < duplicates.count - 1 { Hairline() }
                        }
                    }

                    Button(action: onConfirm) {
                        Text(addCount > 0 ? "Add \(addCount) batch\(addCount == 1 ? "" : "es")" : "Skip all")
                            .widePrimaryButton()
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Theme.canvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .foregroundStyle(Theme.graphite)
                }
            }
        }
    }
}

struct DuplicateRow: View {
    let dup: DuplicateChoice
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(colorFor(status: dup.existing.expirationStatus))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(dup.existing.name)
                    .font(.text(15, weight: .medium))
                    .foregroundStyle(Theme.graphite)

                HStack(spacing: 6) {
                    Text("Currently \(quantityText)")
                    if let suffix = expirationText {
                        Text("·")
                        Text(suffix)
                    }
                }
                .font(.text(12))
                .foregroundStyle(Theme.stone)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Theme.forest)
        }
        .padding(.vertical, 14)
    }

    private var quantityText: String {
        let qty = dup.existing.totalQuantity
        let formatted = qty.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(qty))
            : String(format: "%.1f", qty)
        return "\(formatted) \(dup.existing.unit)"
    }

    private var expirationText: String? {
        guard let days = dup.existing.daysUntilExpiration else { return nil }
        if days < 0 { return "earliest expired" }
        if days == 0 { return "earliest today" }
        return "earliest \(days)d"
    }
}

// MARK: - Detection rows

struct DetectionRow: View {
    let item: DetectedIngredient
    let isSelected: Bool
    var isAlreadyInPantry: Bool = false
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(isSelected ? Theme.forest : Theme.stoneLight)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(.text(15, weight: .medium))
                        .foregroundStyle(Theme.graphite)

                    if isAlreadyInPantry {
                        Text("In pantry")
                            .font(.text(10, weight: .semibold))
                            .tracking(0.6)
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Theme.accent.opacity(0.10)))
                    }
                }

                HStack(spacing: 6) {
                    Text(item.category)
                    Text("·")
                    Text("\(Int(item.confidence * 100))% confidence")
                        .foregroundStyle(Theme.forest)
                }
                .font(.text(12))
                .foregroundStyle(Theme.stone)
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.graphiteSoft)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct EditDetectionRow: View {
    @Binding var item: DetectedIngredient
    let onSave: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionEyebrow(text: "Correct item")

            TextField("Name", text: $item.name)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.words)

            Picker("Category", selection: $item.category) {
                ForEach(FoodCategory.allCases, id: \.self) { cat in
                    Text(cat.rawValue).tag(cat.rawValue)
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.graphite)

            HStack {
                Button(action: onDelete) {
                    Label("Remove", systemImage: "trash")
                        .destructivePillButton()
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onSave) {
                    Text("Done").compactPrimaryButton()
                }
                .buttonStyle(.plain)
                .disabled(item.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.vertical, 14)
    }
}

// MARK: - Add Custom Detection Sheet

struct AddCustomDetectionSheet: View {
    let onAdd: (DetectedIngredient) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category: FoodCategory = .produce

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                    Picker("Category", selection: $category) {
                        ForEach(FoodCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }
                }
            }
            .themedFormBackground()
            .navigationTitle("Add item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        onAdd(DetectedIngredient(
                            name: trimmed,
                            confidence: 1.0,
                            category: category.rawValue,
                            suggestedShelfLife: 7
                        ))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
