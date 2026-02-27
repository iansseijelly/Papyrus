import SwiftUI
import SwiftData

struct BrewListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\BrewLog.createdAt, order: .reverse)]) private var brews: [BrewLog]
    @State private var showNewBrew = false

    var body: some View {
        NavigationStack {
            Group {
                if brews.isEmpty {
                    ContentUnavailableView(
                        "Log your first brew",
                        systemImage: "cup.and.saucer.fill",
                        description: Text("Capture beans, recipes, tweaks, and tasting notes to track your pour overs.")
                    )
                } else {
                    List {
                        ForEach(brews) { brew in
                            NavigationLink {
                                BrewDetailView(brew: brew)
                            } label: {
                                BrewRowView(brew: brew)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Brew")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewBrew = true
                    } label: {
                        Label("Log Brew", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNewBrew) {
                NewBrewFlow {
                    showNewBrew = false
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(brews[index])
        }
    }
}

private struct BrewRowView: View {
    let brew: BrewLog
    private var formatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(brew.displayBeanName)
                    .font(.headline)
                Spacer()
                Text(brew.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(brew.snapshotName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ratingPill(label: "A", fullLabel: "Acidity", value: brew.sourness)
                ratingPill(label: "B", fullLabel: "Bitterness", value: brew.bitterness)
                ratingPill(label: "S", fullLabel: "Sweetness", value: brew.sweetness)
            }
            .font(.caption2)

            if !brew.tastingNotes.isEmpty {
                Text(brew.tastingNotes)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
    }

    private func ratingPill(label: String, fullLabel: String, value: Int) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .fontWeight(.semibold)
            Text("\(value)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.secondarySystemFill), in: Capsule())
        .accessibilityElement()
        .accessibilityLabel("\(fullLabel) \(value)")
    }
}

private struct BrewDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let brew: BrewLog
    private let flavorTaxonomy = FlavorTaxonomyProvider.shared.taxonomy
    @State private var showEditBrew = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                timeline
                ratings
                if !brew.flavorTags.isEmpty {
                    flavorProfile
                }
                if !brew.notes.isEmpty {
                    infoCard(title: "Notes") {
                        Text(brew.notes)
                    }
                }
                if !brew.tastingNotes.isEmpty {
                    infoCard(title: "Tasting Notes") {
                        Text(brew.tastingNotes)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(brew.snapshotName)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showEditBrew = true
                    } label: {
                        Label("Edit Brew", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        modelContext.delete(brew)
                        dismiss()
                    } label: {
                        Label("Delete Brew", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEditBrew) {
            NavigationStack {
                BrewEditorView(brew: brew)
            }
        }
    }

    private var header: some View {
        infoCard(title: "Overview") {
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("Bean", value: brew.displayBeanName)
                LabeledContent("Dose", value: formatGrams(brew.doseGrams))
                LabeledContent("Yield", value: formatGrams(brew.yieldGrams))
                LabeledContent("Brew Time", value: formatDuration(brew.brewDurationSeconds))
            }
        }
    }

    private var ratings: some View {
        infoCard(title: "Tasting Ratings") {
            HStack {
                ratingColumn("Acidity", value: brew.sourness)
                ratingColumn("Bitterness", value: brew.bitterness)
                ratingColumn("Sweetness", value: brew.sweetness)
            }
        }
    }

    private var timeline: some View {
        infoCard(title: "Pour Timeline") {
            if brew.steps.isEmpty {
                ContentUnavailableView(
                    "No steps captured",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Log pours to visualize this brew.")
                )
            } else {
                PourTimelineChart(
                    steps: brewTimelineSteps(),
                    totalBrewTime: max(brew.brewDurationSeconds, brew.steps.map { $0.startTime + $0.duration }.max() ?? 0),
                    color: .blue
                )
                .frame(height: 220)
            }
        }
    }

    private var flavorProfile: some View {
        infoCard(title: "Flavor Profile") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(brew.sortedFlavorTags, id: \.id) { tag in
                    Text(flavorLabel(for: tag))
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.secondarySystemFill), in: Capsule())
                }
            }
        }
    }

    private func infoCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func ratingColumn(_ title: String, value: Int) -> some View {
        VStack {
            Text("\(value)")
                .font(.title2.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func brewTimelineSteps() -> [PourTimelineStepData] {
        brew.steps
            .sorted(by: { $0.order < $1.order })
            .map { step in
                PourTimelineStepData(
                    startTime: step.startTime,
                    duration: step.duration,
                    waterAmount: step.waterAmount
                )
            }
    }

    private func flavorLabel(for tag: BrewFlavorTagSnapshot) -> String {
        if let path = flavorTaxonomy?.pathLabel(for: tag.leafID) {
            return path
        }
        return "\(tag.leafNameAtCapture) (archived)"
    }
}

private struct BrewEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let brew: BrewLog

    @State private var draft: BrewEditDraft
    @State private var showStepEditor = false

    init(brew: BrewLog) {
        self.brew = brew
        _draft = State(initialValue: BrewEditDraft(brew: brew))
    }

    var body: some View {
        Form {
            Section("Brew") {
                inlineTextField(
                    label: "Snapshot Name",
                    placeholder: "e.g. Triple Pour",
                    text: $draft.snapshotName,
                    maxWidth: nil
                )
                inlineTextField(
                    label: "Method",
                    placeholder: "e.g. V60",
                    text: $draft.snapshotMethod,
                    maxWidth: nil
                )
            }

            Section("Pour Steps") {
                Button {
                    showStepEditor = true
                } label: {
                    HStack {
                        Label("Edit Pour Steps", systemImage: "slider.horizontal.3")
                        Spacer()
                        Text("\(draft.stepDrafts.count) steps")
                            .foregroundStyle(.secondary)
                    }
                }
                Text("Total water: \(Int(draft.totalWater)) g • Total time: \(formatDuration(draft.brewDurationSeconds))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Brew Settings") {
                Stepper(value: $draft.doseGrams, in: 5...80, step: 1) {
                    Text("Dose: \(Int(draft.doseGrams)) g")
                }
                Stepper(value: $draft.yieldGrams, in: 50...1000, step: 5) {
                    Text("Yield: \(Int(draft.yieldGrams)) g")
                }
                Stepper(value: $draft.waterTemperatureCelsius, in: 80...100, step: 1) {
                    Text("Water Temp: \(Int(draft.waterTemperatureCelsius))°C")
                }
                Stepper(value: $draft.brewDurationSeconds, in: 30...600, step: 5) {
                    Text("Total Time: \(Int(draft.brewDurationSeconds))s")
                }
                inlineTextField(
                    label: "Grind Setting",
                    placeholder: "e.g. 5.2",
                    text: $draft.grindSetting,
                    maxWidth: 160
                )
            }

            Section("Ratings") {
                ratingSlider(label: "Acidity", value: $draft.sourness)
                ratingSlider(label: "Balance", value: $draft.bitterness)
                ratingSlider(label: "Sweetness", value: $draft.sweetness)
            }

            Section("Notes") {
                TextField("Brew notes", text: $draft.notes, axis: .vertical)
                TextField("Tasting notes", text: $draft.tastingNotes, axis: .vertical)
            }
        }
        .navigationTitle("Edit Brew")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(!draft.isSavable)
            }
        }
        .onChange(of: draft.totalStepDuration) { _, newValue in
            draft.brewDurationSeconds = max(draft.brewDurationSeconds, newValue)
            draft.brewDurationSeconds = min(draft.brewDurationSeconds, draft.maxBrewDuration)
        }
        .sheet(isPresented: $showStepEditor) {
            NavigationStack {
                PourStepsEditorView(draft: $draft)
            }
        }
    }

    private func save() {
        guard draft.isSavable else { return }

        brew.snapshotName = draft.snapshotName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? brew.snapshotName : draft.snapshotName
        brew.snapshotMethod = draft.snapshotMethod
        brew.doseGrams = draft.doseGrams
        brew.yieldGrams = draft.yieldGrams
        brew.waterTemperatureCelsius = draft.waterTemperatureCelsius
        brew.grindSetting = draft.grindSetting
        brew.brewDurationSeconds = draft.brewDurationSeconds
        brew.sourness = draft.sourness
        brew.bitterness = draft.bitterness
        brew.sweetness = draft.sweetness
        brew.notes = draft.notes
        brew.tastingNotes = draft.tastingNotes

        brew.steps.forEach { modelContext.delete($0) }
        brew.steps = draft.stepDrafts
            .sorted(by: { $0.order < $1.order })
            .map {
                BrewStepSnapshot(
                    order: $0.order,
                    startTime: $0.startTime,
                    duration: $0.duration,
                    waterAmount: $0.waterAmount,
                    note: $0.note,
                    brew: brew
                )
            }

        dismiss()
    }

    private func ratingSlider(label: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(label)
                Spacer()
                Text("\(value.wrappedValue)")
                    .foregroundStyle(.secondary)
            }
            Slider(value: Binding(
                get: { Double(value.wrappedValue) },
                set: { value.wrappedValue = Int($0.rounded()) }
            ), in: 1...10, step: 1)
        }
    }
}

private struct BrewEditDraft {
    var snapshotName: String
    var snapshotMethod: String
    var doseGrams: Double
    var yieldGrams: Double
    var waterTemperatureCelsius: Double
    var grindSetting: String
    var brewDurationSeconds: Double
    var notes: String
    var tastingNotes: String
    var sourness: Int
    var bitterness: Int
    var sweetness: Int
    var stepDrafts: [StepDraft]

    init(brew: BrewLog) {
        snapshotName = brew.snapshotName
        snapshotMethod = brew.snapshotMethod
        doseGrams = brew.doseGrams
        yieldGrams = brew.yieldGrams
        waterTemperatureCelsius = brew.waterTemperatureCelsius
        grindSetting = brew.grindSetting
        brewDurationSeconds = brew.brewDurationSeconds
        notes = brew.notes
        tastingNotes = brew.tastingNotes
        sourness = brew.sourness
        bitterness = brew.bitterness
        sweetness = brew.sweetness
        stepDrafts = brew.steps
            .sorted(by: { $0.order < $1.order })
            .map { StepDraft(snapshot: $0) }
    }

    var isSavable: Bool {
        !stepDrafts.isEmpty
    }
}

extension BrewEditDraft: PourStepDraftContainer {
    var maxBrewDuration: TimeInterval { BrewDraftConstants.maxBrewDuration }
    var defaultStepDuration: TimeInterval { BrewDraftConstants.defaultStepDuration }
    var defaultStepWater: Double { BrewDraftConstants.defaultStepWater }
}

struct NewBrewFlow: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Bean.name, order: .forward)]) private var beans: [Bean]
    @Query(sort: [SortDescriptor(\Recipe.updatedAt, order: .reverse)]) private var recipes: [Recipe]

    @State private var draft = BrewDraft()
    @State private var showBeanPicker = false
    @State private var showRecipePicker = false
    @State private var showStepEditor = false
    @State private var showFlavorEditor = false
    @State private var didApplyInitialRecipe = false

    let initialRecipe: Recipe?
    var onComplete: () -> Void

    init(initialRecipe: Recipe? = nil, onComplete: @escaping () -> Void) {
        self.initialRecipe = initialRecipe
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Bean") {
                    SelectionButton(title: draft.beanSelectionTitle) {
                        showBeanPicker = true
                    }
                    if draft.usesCustomBean {
                        inlineTextField(
                            label: "Bean Name",
                            placeholder: "e.g. Local Roaster",
                            text: $draft.customBeanName,
                            maxWidth: nil
                        )
                    }
                }

                Section("Recipe") {
                    SelectionButton(title: draft.recipeSelectionTitle) {
                        showRecipePicker = true
                    }
                    inlineTextField(
                        label: "Snapshot Name",
                        placeholder: "e.g. Triple Pour",
                        text: $draft.snapshotName,
                        maxWidth: nil
                    )
                    inlineTextField(
                        label: "Method",
                        placeholder: "e.g. V60",
                        text: $draft.snapshotMethod,
                        maxWidth: nil
                    )
                    if draft.usesCustomRecipe {
                        Text("Using a custom recipe")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let recipe = draft.recipe {
                        Text("Based on \(recipe.name)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Toggle("Mark as modified", isOn: $draft.markAsModified)
                }

                Section("Pour Steps") {
                    Button {
                        showStepEditor = true
                    } label: {
                        HStack {
                            Label("Edit Pour Steps", systemImage: "slider.horizontal.3")
                            Spacer()
                            Text("\(draft.stepDrafts.count) steps")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("Total water: \(Int(draft.totalWater)) g • Total time: \(formatDuration(draft.brewDurationSeconds))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Brew Settings") {
                    Stepper(value: $draft.doseGrams, in: 5...80, step: 1) {
                        Text("Dose: \(Int(draft.doseGrams)) g")
                    }
                    Stepper(value: $draft.yieldGrams, in: 50...1000, step: 5) {
                        Text("Yield: \(Int(draft.yieldGrams)) g")
                    }
                    Stepper(value: $draft.waterTemperatureCelsius, in: 80...100, step: 1) {
                        Text("Water Temp: \(Int(draft.waterTemperatureCelsius))°C")
                    }
                    Stepper(value: $draft.brewDurationSeconds, in: 30...600, step: 5) {
                        Text("Total Time: \(Int(draft.brewDurationSeconds))s")
                    }
                    inlineTextField(
                        label: "Grind Setting",
                        placeholder: "e.g. 5.2",
                        text: $draft.grindSetting,
                        maxWidth: 160
                    )
                }

                Section("Ratings") {
                    ratingSlider(label: "Acidity", value: $draft.sourness)
                    ratingSlider(label: "Bitterness", value: $draft.bitterness)
                    ratingSlider(label: "Sweetness", value: $draft.sweetness)
                }

                Section("Flavor Profile") {
                    Button {
                        showFlavorEditor = true
                    } label: {
                        HStack {
                            Label("Edit Flavor Tags", systemImage: "sparkles.rectangle.stack")
                            Spacer()
                            Text("\(draft.selectedFlavorLeafIDs.count)/\(BrewDraftConstants.maxFlavorTags)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    if !draft.flavorPreviewText.isEmpty {
                        Text(draft.flavorPreviewText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Section("Notes") {
                    TextField("Brew notes", text: $draft.notes, axis: .vertical)
                    TextField("Tasting notes", text: $draft.tastingNotes, axis: .vertical)
                }
            }
            .navigationTitle("Log Brew")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onComplete()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!draft.isSavable)
                }
            }
            .sheet(isPresented: $showBeanPicker) {
                BeanPickerView(beans: beans, selected: draft.bean, isCustomSelected: draft.usesCustomBean) { selection in
                    if let bean = selection {
                        draft.bean = bean
                        draft.usesCustomBean = false
                    } else {
                        draft.bean = nil
                        draft.usesCustomBean = true
                        if draft.customBeanName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            draft.customBeanName = "Other Bean"
                        }
                    }
                    showBeanPicker = false
                }
            }
            .sheet(isPresented: $showRecipePicker) {
                RecipePickerView(recipes: recipes, selected: draft.recipe, isCustomSelected: draft.usesCustomRecipe) { selection in
                    if let recipe = selection {
                        draft.apply(recipe: recipe)
                        draft.usesCustomRecipe = false
                    } else {
                        draft.recipe = nil
                        draft.usesCustomRecipe = true
                        draft.markAsModified = true
                    }
                    showRecipePicker = false
                }
            }
            .sheet(isPresented: $showStepEditor) {
                NavigationStack {
                    PourStepsEditorView(draft: $draft)
                }
            }
            .sheet(isPresented: $showFlavorEditor) {
                FlavorTagEditorView(selectedLeafIDs: $draft.selectedFlavorLeafIDs)
            }
        }
        .onChange(of: draft.isModified) { _, newValue in
            if newValue, !draft.markAsModified {
                draft.markAsModified = true
            }
        }
        .onChange(of: draft.totalStepDuration) { _, newValue in
            draft.brewDurationSeconds = max(draft.brewDurationSeconds, newValue)
            draft.brewDurationSeconds = min(draft.brewDurationSeconds, draft.maxBrewDuration)
        }
        .onAppear {
            guard !didApplyInitialRecipe else { return }
            if let initialRecipe {
                draft.apply(recipe: initialRecipe)
            }
            didApplyInitialRecipe = true
        }
    }

    private func save() {
        guard draft.isSavable else { return }
        let selectedBean = draft.usesCustomBean ? nil : draft.bean
        let selectedRecipe = draft.usesCustomRecipe ? nil : draft.recipe
        let brew = BrewLog(
            snapshotName: draft.finalSnapshotName,
            snapshotMethod: draft.snapshotMethod,
            doseGrams: draft.doseGrams,
            yieldGrams: draft.yieldGrams,
            waterTemperatureCelsius: draft.waterTemperatureCelsius,
            grindSetting: draft.grindSetting,
            brewDurationSeconds: draft.brewDurationSeconds,
            notes: draft.notes,
            sourness: draft.sourness,
            bitterness: draft.bitterness,
            sweetness: draft.sweetness,
            tastingNotes: draft.tastingNotes,
            modifiedFromRecipe: draft.markAsModified,
            customBeanName: draft.usesCustomBean ? draft.customBeanDisplayName : "",
            bean: selectedBean,
            baseRecipe: selectedRecipe
        )

        let steps = draft.stepDrafts
            .sorted(by: { $0.order < $1.order })
            .map {
                BrewStepSnapshot(
                    order: $0.order,
                    startTime: $0.startTime,
                    duration: $0.duration,
                    waterAmount: $0.waterAmount,
                    note: $0.note,
                    brew: brew
                )
            }
        brew.steps = steps

        let flavorTags = draft.selectedFlavorLeafIDs.enumerated().map { offset, leafID in
            BrewFlavorTagSnapshot(
                order: offset,
                leafID: leafID,
                leafNameAtCapture: FlavorTaxonomyProvider.shared.taxonomy?.leaf(for: leafID)?.name ?? leafID,
                brew: brew
            )
        }
        brew.flavorTags = flavorTags
        modelContext.insert(brew)

        if let bean = selectedBean {
            bean.remainingGrams = max(0, bean.remainingGrams - draft.doseGrams)
        }

        dismiss()
        onComplete()
    }

    private func ratingSlider(label: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(label)
                Spacer()
                Text("\(value.wrappedValue)")
                    .foregroundStyle(.secondary)
            }
            Slider(value: Binding(
                get: { Double(value.wrappedValue) },
                set: { value.wrappedValue = Int($0.rounded()) }
            ), in: 1...10, step: 1)
        }
    }
}

private struct BrewDraft {
    var bean: Bean?
    var recipe: Recipe?
    var snapshotName: String = ""
    var snapshotMethod: String = ""
    var doseGrams: Double = 20
    var yieldGrams: Double = 320
    var waterTemperatureCelsius: Double = 94
    var grindSetting: String = ""
    var brewDurationSeconds: Double = 180
    var notes: String = ""
    var tastingNotes: String = ""
    var sourness: Int = 5
    var bitterness: Int = 5
    var sweetness: Int = 5
    var stepDrafts: [StepDraft] = []
    var selectedFlavorLeafIDs: [String] = []
    var usesCustomBean: Bool = false
    var usesCustomRecipe: Bool = false
    var markAsModified: Bool = false
    var customBeanName: String = "Other Bean"

    mutating func apply(recipe: Recipe) {
        self.recipe = recipe
        snapshotName = recipe.name
        snapshotMethod = recipe.brewMethod.label
        doseGrams = recipe.doseGrams
        yieldGrams = recipe.totalWater
        waterTemperatureCelsius = recipe.waterTemperatureCelsius
        grindSetting = recipe.grindSetting
        brewDurationSeconds = min(
            BrewDraftConstants.maxBrewDuration,
            max(recipe.brewDurationSeconds, recipe.pourSteps.map(\.endTime).max() ?? 0)
        )
        stepDrafts = recipe.pourSteps
            .sorted(by: { $0.order < $1.order })
            .map { StepDraft(step: $0) }
        markAsModified = false
        usesCustomRecipe = false
    }

    var beanSelectionTitle: String {
        usesCustomBean ? customBeanDisplayName : (bean?.name ?? "Select Bean")
    }

    var recipeSelectionTitle: String {
        usesCustomRecipe ? "Other Recipe" : (recipe?.name ?? "Select Recipe")
    }

    private var baseSnapshotName: String {
        let base = snapshotName.trimmingCharacters(in: .whitespaces)
        if base.isEmpty {
            if let recipeName = recipe?.name {
                return recipeName
            }
            return "Custom Brew"
        }
        return base
    }

    var finalSnapshotName: String {
        var name = baseSnapshotName
        if markAsModified, !name.lowercased().hasSuffix("-modified") {
            name += "-modified"
        }
        return name
    }

    var isModified: Bool {
        guard let recipe = recipe else { return !stepDrafts.isEmpty }
        return doseGrams != recipe.doseGrams ||
            yieldGrams != recipe.totalWater ||
            waterTemperatureCelsius != recipe.waterTemperatureCelsius ||
            brewDurationSeconds != recipe.totalBrewTime ||
            grindSetting != recipe.grindSetting ||
            !stepsMatch(recipe: recipe)
    }

    var isSavable: Bool {
        let hasBean = usesCustomBean ? !customBeanDisplayName.isEmpty : bean != nil
        let hasRecipe = usesCustomRecipe ? true : recipe != nil
        return hasBean && hasRecipe && !stepDrafts.isEmpty
    }

    var customBeanDisplayName: String {
        let trimmed = customBeanName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Other Bean" : trimmed
    }

    var flavorPreviewText: String {
        guard let taxonomy = FlavorTaxonomyProvider.shared.taxonomy else { return "" }
        let names = selectedFlavorLeafIDs.compactMap { taxonomy.leaf(for: $0)?.name }
        guard !names.isEmpty else { return "" }
        if names.count <= 3 {
            return names.joined(separator: ", ")
        }
        return names.prefix(3).joined(separator: ", ") + " +\(names.count - 3) more"
    }

    private func stepsMatch(recipe: Recipe) -> Bool {
        let recipeSteps = recipe.pourSteps.sorted(by: { $0.order < $1.order })
        guard recipeSteps.count == stepDrafts.count else { return false }
        for (draft, recipeStep) in zip(stepDrafts, recipeSteps) {
            if draft.startTime != recipeStep.startTime ||
                draft.duration != recipeStep.duration ||
                draft.waterAmount != recipeStep.waterAmount {
                return false
            }
        }
        return true
    }
}

private enum BrewDraftConstants {
    static let defaultStepDuration: TimeInterval = 30
    static let defaultStepWater: Double = 100
    static let maxBrewDuration: TimeInterval = 1200
    static let maxFlavorTags: Int = 5
}

extension BrewDraft: PourStepDraftContainer {
    var maxBrewDuration: TimeInterval { BrewDraftConstants.maxBrewDuration }
    var defaultStepDuration: TimeInterval { BrewDraftConstants.defaultStepDuration }
    var defaultStepWater: Double { BrewDraftConstants.defaultStepWater }
}

private struct SelectionButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct BeanPickerView: View {
    let beans: [Bean]
    let selected: Bean?
    let isCustomSelected: Bool
    var onSelect: (Bean?) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(beans.enumerated()), id: \.element.persistentModelID) { _, bean in
                    Button {
                        onSelect(bean)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(bean.name)
                                Text(bean.roaster)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selected?.persistentModelID == bean.persistentModelID {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    onSelect(nil)
                } label: {
                    HStack {
                        Text("Use Other Bean")
                        Spacer()
                        if isCustomSelected {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Beans")
        }
    }
}

private struct RecipePickerView: View {
    let recipes: [Recipe]
    let selected: Recipe?
    let isCustomSelected: Bool
    var onSelect: (Recipe?) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(recipes.enumerated()), id: \.element.persistentModelID) { _, recipe in
                    Button {
                        onSelect(recipe)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(recipe.name)
                                Text(recipe.brewMethod.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selected?.persistentModelID == recipe.persistentModelID {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    onSelect(nil)
                } label: {
                    HStack {
                        Text("Use Other Recipe")
                        Spacer()
                        if isCustomSelected {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Recipes")
        }
    }
}

private func formatDuration(_ time: TimeInterval) -> String {
    guard time.isFinite else { return "--" }
    let minutes = Int(time) / 60
    let seconds = Int(time) % 60
    if minutes > 0 {
        return "\(minutes)m \(seconds)s"
    } else {
        return "\(seconds)s"
    }
}

private let brewGramsFormatter: MeasurementFormatter = {
    let formatter = MeasurementFormatter()
    formatter.unitOptions = .providedUnit
    formatter.unitStyle = .medium
    return formatter
}()

private func formatGrams(_ grams: Double) -> String {
    brewGramsFormatter.string(from: Measurement(value: grams, unit: UnitMass.grams))
}

@ViewBuilder
private func inlineTextField(
    label: String,
    placeholder: String,
    text: Binding<String>,
    maxWidth: CGFloat? = 200
) -> some View {
    LabeledContent(label) {
        TextField(placeholder, text: text)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: maxWidth)
    }
}
