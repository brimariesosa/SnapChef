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
    @State private var matchedRecipe: Recipe?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.appBackgroundGradient.ignoresSafeArea()
                DecorativeBlobs().ignoresSafeArea()

                VStack(spacing: 22) {
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
                    matchedRecipe: matchedRecipe,
                    pantryItems: pantryItems,
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
        VStack(spacing: 6) {
            Text("Point and snap")
                .font(.display(28))
                .foregroundStyle(Theme.forestGreenDark)
            Text("SnapChef AI identifies every ingredient in seconds.")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Theme.warmGray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var placeholderView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Theme.forestGreen.opacity(0.08),
                            Theme.mint.opacity(0.16),
                            Theme.peach.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(
                            Theme.forestGreen.opacity(0.35),
                            style: StrokeStyle(lineWidth: 2, dash: [10])
                        )
                )

            PulsingRing(color: Theme.forestGreen, size: 220)

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.primaryGradient)
                        .frame(width: 92, height: 92)
                        .shadow(color: Theme.forestGreen.opacity(0.35), radius: 14, y: 6)
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text("Ready to scan")
                    .font(.display(18))
                    .foregroundStyle(Theme.forestGreenDark)
                Text("Snap or pick a photo to get started")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Theme.warmGray)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
    }

    private func capturedImageView(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(height: 300)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.6), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
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
                HStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                    Text("Take Photo")
                }
                .primaryButton()
            }

            Button {
                showingPhotoLibrary = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle")
                    Text("Choose from Library")
                }
                .secondaryButton()
            }

            Button {
                showingDemoLibrary = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("Demo Library")
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.berry)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Theme.berry.opacity(0.12))
                .clipShape(Capsule())
            }

            if capturedImage != nil && !isScanning && detectedItems.isEmpty {
                Button("Scan Again") {
                    Task { await scanImage() }
                }
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Theme.forestGreen)
            }
        }
    }

    private var scanningOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    PulsingRing(color: .white, size: 120)
                    Image(systemName: "sparkles")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text("Identifying ingredients...")
                    .font(.display(18))
                    .foregroundStyle(.white)
                Text("AI is analyzing your photo")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(36)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
    }

    private func scanImage() async {
        guard capturedImage != nil else { return }
        isScanning = true

        if let demo = pendingDemoRecipe {
            detectedItems = await MockDataService.shared.identifyIngredients(for: demo)
            matchedRecipe = demo
        } else if let image = capturedImage {
            detectedItems = await MockDataService.shared.identifyIngredients(from: image)
            matchedRecipe = nil
        }

        isScanning = false
        showingResults = true
    }

    private func addSelectedItems(_ confirmed: [DetectedIngredient]) {
        for detected in confirmed {
            let expDate = Calendar.current.date(
                byAdding: .day,
                value: detected.suggestedShelfLife,
                to: Date()
            )

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
        matchedRecipe = nil
        pendingDemoRecipe = nil
    }
}

// MARK: - Demo Library Picker

struct DemoLibraryPicker: View {
    let onPick: (DemoRecipePhoto) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var seedingState: SeedState = .idle

    enum SeedState: Equatable {
        case idle
        case seeding
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
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tap a photo to scan it. Each one maps to a recipe in your library so you can demo the full flow end-to-end.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.warmGray)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(DemoLibrary.photos) { photo in
                            Button {
                                onPick(photo)
                            } label: {
                                DemoPhotoCard(photo: photo)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    seedSection
                }
                .padding(16)
            }
            .background(Theme.cream.opacity(0.4))
            .navigationTitle("Demo Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var seedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Seed iOS Photos app")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.forestGreenDark)

            Text("Saves these demo photos to your device's Photos app so you can pick them through the regular photo library.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.warmGray)

            Button {
                seed()
            } label: {
                HStack {
                    if seedingState == .seeding {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.down.fill")
                    }
                    Text(seedingState == .seeding ? "Saving..." : "Seed Demo Photos")
                }
                .secondaryButton()
            }
            .disabled(seedingState == .seeding)

            switch seedingState {
            case .success(let count):
                Label("Saved \(count) photo\(count == 1 ? "" : "s") to Photos.",
                      systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.green)
            case .failure(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.leading)
            default:
                EmptyView()
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.top, 8)
    }

    private func seed() {
        seedingState = .seeding
        DemoLibrary.seedToPhotoLibrary { result in
            switch result {
            case .success(let count):
                seedingState = .success(count)
            case .failure(let error):
                seedingState = .failure(error.localizedDescription)
            }
        }
    }
}

struct DemoPhotoCard: View {
    let photo: DemoRecipePhoto

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: photo.gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: photo.symbol)
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 2) {
                Text(photo.recipeTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [.black.opacity(0.0), .black.opacity(0.45)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}

// MARK: - Scan Results Sheet

struct ScanResultsView: View {
    let matchedRecipe: Recipe?
    let pantryItems: [PantryItem]
    let onAdd: ([DetectedIngredient]) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var items: [DetectedIngredient]
    @State private var selected: Set<UUID>
    @State private var editingId: UUID?
    @State private var showingAddCustom = false
    @State private var didAdd = false

    @State private var showingDuplicateSheet = false
    @State private var pendingFresh: [DetectedIngredient] = []
    @State private var pendingDuplicates: [DuplicateChoice] = []
    @State private var duplicateChoices: [UUID: Bool] = [:]

    init(
        detectedItems: [DetectedIngredient],
        matchedRecipe: Recipe?,
        pantryItems: [PantryItem],
        onAdd: @escaping ([DetectedIngredient]) -> Void
    ) {
        self.matchedRecipe = matchedRecipe
        self.pantryItems = pantryItems
        self.onAdd = onAdd
        self._items = State(initialValue: detectedItems)
        self._selected = State(initialValue: Set(detectedItems.map { $0.id }))
    }

    private var selectedItems: [DetectedIngredient] {
        items.filter { selected.contains($0.id) }
    }

    private var virtualPantryNames: [String] {
        pantryItems.map { $0.name } + selectedItems.map { $0.name }
    }

    private var suggestedRecipes: [(recipe: Recipe, score: Double)] {
        sampleRecipes
            .map { ($0, $0.matchScore(pantryNames: virtualPantryNames)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { (recipe: $0.0, score: $0.1) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerInfo

                    scannedItemsSection

                    suggestionsSection
                }
                .padding(16)
            }
            .background(Theme.cream.opacity(0.4))
            .navigationTitle(didAdd ? "Added to Pantry" : "Scan Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(didAdd ? "Done" : "Cancel") { dismiss() }
                }
                if !didAdd {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Add \(selectedItems.count)") {
                            handleAddTapped()
                        }
                        .fontWeight(.semibold)
                        .disabled(selectedItems.isEmpty)
                    }
                }
            }
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
        }
    }

    // MARK: - Add flow

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

    private var headerInfo: some View {
        HStack {
            Image(systemName: didAdd ? "checkmark.seal.fill" : "sparkles")
                .foregroundStyle(didAdd ? .green : Theme.accent)
            Text(didAdd
                 ? "Items added to pantry."
                 : "Tap a row to edit. Uncheck anything we got wrong.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.warmGray)
            Spacer()
        }
    }

    private var scannedItemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Scanned Items (\(items.count))")

            VStack(spacing: 8) {
                ForEach(items) { item in
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
                }

                Button {
                    showingAddCustom = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add item the scan missed")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.forestGreen)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.forestGreen.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Recipe Suggestions")

            if suggestedRecipes.isEmpty {
                Text("Select at least one ingredient to see matching recipes.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.warmGray)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 8) {
                    ForEach(suggestedRecipes, id: \.recipe.id) { entry in
                        NavigationLink(destination: RecipeDetailView(recipe: entry.recipe)) {
                            SuggestionRow(
                                recipe: entry.recipe,
                                matchPercent: Int(entry.score * 100),
                                isHighlighted: matchedRecipe?.id == entry.recipe.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.warmGray)
            .textCase(.uppercase)
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
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Theme.sunsetGradient)
                                .frame(width: 44, height: 44)
                            Image(systemName: "tray.full.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        Text("These items are already in your pantry. Want to add another batch with a fresh expiration date?")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(Theme.warmGray)
                    }

                    VStack(spacing: 10) {
                        ForEach(duplicates) { dup in
                            DuplicateRow(
                                dup: dup,
                                isOn: Binding(
                                    get: { choices[dup.detected.id] ?? true },
                                    set: { choices[dup.detected.id] = $0 }
                                )
                            )
                        }
                    }

                    Button(action: onConfirm) {
                        Text(addCount > 0 ? "Add \(addCount) batch\(addCount == 1 ? "" : "es")" : "Skip All")
                            .primaryButton()
                    }
                    .padding(.top, 6)
                }
                .padding(16)
            }
            .background(
                ZStack {
                    Theme.appBackgroundGradient.ignoresSafeArea()
                    DecorativeBlobs().ignoresSafeArea()
                }
            )
            .navigationTitle("Already in pantry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DuplicateRow: View {
    let dup: DuplicateChoice
    @Binding var isOn: Bool

    var category: FoodCategory? { FoodCategory(rawValue: dup.existing.category) }
    var tint: Color { category?.color ?? Theme.forestGreen }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(category?.gradient ?? Theme.primaryGradient)
                    .frame(width: 40, height: 40)
                    .shadow(color: tint.opacity(0.3), radius: 5, y: 2)
                Image(systemName: category?.icon ?? "bag.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(dup.existing.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.forestGreenDark)

                HStack(spacing: 6) {
                    Text("Currently \(quantityText)")
                    if let suffix = expirationText {
                        Text("•")
                        Text(suffix)
                            .foregroundStyle(colorFor(status: dup.existing.expirationStatus))
                    }
                }
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Theme.warmGray)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Theme.forestGreen)
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
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
                    .font(.title2)
                    .foregroundStyle(isSelected ? Theme.forestGreen : Color.gray.opacity(0.3))
            }
            .buttonStyle(.plain)

            Image(systemName: FoodCategory(rawValue: item.category)?.icon ?? "bag.fill")
                .font(.title3)
                .foregroundStyle(Theme.forestGreen)
                .frame(width: 36, height: 36)
                .background(Theme.forestGreen.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)

                    if isAlreadyInPantry {
                        Text("in pantry")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.accent.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 8) {
                    Text(item.category)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Theme.warmGray)

                    Text("•")
                        .foregroundStyle(Theme.warmGray)

                    Text("\(Int(item.confidence * 100))% confidence")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.green)
                }
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.forestGreen.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct EditDetectionRow: View {
    @Binding var item: DetectedIngredient
    let onSave: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "pencil")
                    .foregroundStyle(Theme.forestGreen)
                Text("Correct item")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.forestGreenDark)
                Spacer()
            }

            TextField("Name", text: $item.name)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.words)

            Picker("Category", selection: $item.category) {
                ForEach(FoodCategory.allCases, id: \.self) { cat in
                    Text(cat.rawValue).tag(cat.rawValue)
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.forestGreen)

            HStack {
                Button(role: .destructive, action: onDelete) {
                    Label("Remove", systemImage: "trash")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Spacer()

                Button(action: onSave) {
                    Text("Done")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.forestGreen)
                .disabled(item.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.forestGreen.opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: - Recipe suggestion row

struct SuggestionRow: View {
    let recipe: Recipe
    let matchPercent: Int
    let isHighlighted: Bool

    var matchColor: Color {
        switch matchPercent {
        case 80...: return .green
        case 50..<80: return .orange
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: recipe.imageName)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [Theme.forestGreen, Theme.forestGreenLight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                if isHighlighted {
                    Text("Recipe match")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.forestGreen)
                }
                Text(recipe.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.forestGreenDark)
                    .lineLimit(1)
                Text(recipe.description)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.warmGray)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            VStack(spacing: 4) {
                Text("\(matchPercent)%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(matchColor)
                    .clipShape(Capsule())
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Theme.warmGray)
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isHighlighted ? Theme.forestGreen : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.04), radius: 5, y: 2)
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
            .navigationTitle("Add Item")
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
