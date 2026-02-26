//
//  RecipesListView.swift
//  Papyrus
//
//  Created by 张成熠 on 2/26/26.
//

import SwiftUI
import SwiftData
import Charts
import Combine

struct RecipesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Recipe.updatedAt, order: .reverse)]) private var recipes: [Recipe]

    @State private var searchText = ""
    @State private var editorSheet: RecipeEditorSheet?

    private var filtered: [Recipe] {
        guard !searchText.isEmpty else { return recipes }
        return recipes.filter {
            [$0.name, $0.grindSetting, $0.notes]
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if recipes.isEmpty {
                    ContentUnavailableView(
                        "Build your first recipe",
                        systemImage: "book.and.wrench",
                        description: Text("Capture grind, temperature, and pour curve so you can repeat perfect brews.")
                    )
                } else {
                    list
                }
            }
            .navigationTitle("Recipes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editorSheet = .create
                    } label: {
                        Label("New Recipe", systemImage: "plus")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search recipes, notes, grind")
            .sheet(item: $editorSheet) { sheet in
                NavigationStack {
                    RecipeEditorView(recipe: sheet.recipe) { _ in
                        editorSheet = nil
                    } onCancel: {
                        editorSheet = nil
                    }
                }
            }
        }
    }

    private var list: some View {
        List {
            ForEach(filtered) { recipe in
                NavigationLink {
                    RecipeDetailView(recipe: recipe, onEdit: {
                        editorSheet = .edit(recipe)
                    })
                } label: {
                    RecipeRowView(recipe: recipe)
                }
                .contextMenu {
                    Button {
                        editorSheet = .edit(recipe)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        modelContext.delete(recipe)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .onDelete(perform: delete)
        }
    }

    private func delete(_ offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(filtered[index])
            }
        }
    }
}

private enum RecipeEditorSheet: Identifiable {
    case create
    case edit(Recipe)

    var id: String {
        switch self {
        case .create:
            return "create"
        case .edit(let recipe):
            return recipe.id.uuidString
        }
    }

    var recipe: Recipe? {
        switch self {
        case .create:
            return nil
        case .edit(let recipe):
            return recipe
        }
    }
}

private struct RecipeRowView: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.1))
                    .frame(width: 42, height: 42)
                Image(systemName: recipe.brewMethod.iconName)
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.headline)
                Text("\(recipe.brewMethod.label) • 1:\(String(format: "%.1f", recipe.ratio))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Dose \(Int(recipe.doseGrams)) g → \(Int(recipe.totalWater)) g • \(formatDuration(recipe.totalBrewTime))")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if let lastPoint = recipe.cumulativePoints.last {
                VStack(alignment: .trailing) {
                    Text("\(Int(lastPoint.cumulativeWater)) g")
                        .font(.headline)
                    Text("Total")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

struct RecipeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showPlaySession = false
    @State private var showLogBrew = false

    let recipe: Recipe
    var onEdit: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                timelineCard
                metadata
                if !recipe.notes.isEmpty {
                    notes
                }
            }
            .padding()
        }
        .navigationTitle(recipe.name)
        .sheet(isPresented: $showPlaySession) {
            NavigationStack {
                RecipePlayView(recipe: recipe) {
                    showPlaySession = false
                    DispatchQueue.main.async {
                        showLogBrew = true
                    }
                }
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showLogBrew) {
            NewBrewFlow(initialRecipe: recipe) {
                showLogBrew = false
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        onEdit()
                    } label: {
                        Label("Edit Recipe", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        modelContext.delete(recipe)
                    } label: {
                        Label("Delete Recipe", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label(recipe.brewMethod.label, systemImage: recipe.brewMethod.iconName)
                    .font(.title3.bold())
                Spacer()
                Text("1 : \(String(format: "%.1f", recipe.ratio))")
                    .font(.title2.weight(.semibold))
            }

            Button {
                showPlaySession = true
            } label: {
                Label("Play Recipe", systemImage: "play.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(recipe.pourSteps.isEmpty)
        }
    }

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pour Timeline")
                .font(.headline)
            if recipe.pourSteps.isEmpty {
                ContentUnavailableView(
                    "No steps yet",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Add pour steps to visualize your brew curve.")
                )
            } else {
                PourTimelineChart(
                    steps: recipeTimelineSteps(),
                    totalBrewTime: recipe.totalBrewTime
                )
                    .frame(height: 220)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parameters")
                .font(.headline)
            parameterRow(
                metric(title: "Dose", value: "\(Int(recipe.doseGrams)) g"),
                metric(title: "Yield", value: "\(Int(recipe.totalWater)) g")
            )
            Divider()
            parameterRow(
                metric(title: "Water Temp", value: "\(Int(recipe.waterTemperatureCelsius))°C"),
                metric(title: "Grind", value: recipe.grindSetting)
            )
            Divider()
            parameterRow(
                metric(title: "Brew Time", value: formatDuration(recipe.totalBrewTime)),
                metric(title: "Steps", value: "\(recipe.pourSteps.count)")
            )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading) {
            Text(title.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
    }

    private func parameterRow<Left: View, Right: View>(_ left: Left, _ right: Right) -> some View {
        HStack(alignment: .top, spacing: 16) {
            left
                .frame(maxWidth: .infinity, alignment: .leading)
            right
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)
            Text(recipe.notes)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

private extension RecipeDetailView {
    func recipeTimelineSteps() -> [PourTimelineStepData] {
        recipe.pourSteps
            .sorted(by: { $0.order < $1.order })
            .map { step in
                PourTimelineStepData(
                    startTime: step.startTime,
                    duration: step.duration,
                    waterAmount: step.waterAmount
                )
            }
    }
}

private struct RecipePlayView: View {
    @Environment(\.dismiss) private var dismiss

    let recipe: Recipe
    var onPlaybackCompleted: () -> Void

    @State private var elapsed: TimeInterval = 0
    @State private var isRunning = false
    @State private var hasStarted = false
    @State private var lastTick: Date?
    @State private var completionTriggered = false

    private let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                statusCard
                timelineCard
                stepCard
                controlsCard
            }
            .padding()
        }
        .navigationTitle("Play Recipe")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
        .onReceive(timer) { now in
            guard isRunning else { return }
            defer { lastTick = now }

            guard let lastTick else { return }
            elapsed = min(totalBrewTime, elapsed + now.timeIntervalSince(lastTick))
            if elapsed >= totalBrewTime {
                finishAndLog()
            }
        }
        .onDisappear {
            isRunning = false
            lastTick = nil
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timer")
                .font(.headline)
            Text(formatDuration(elapsed))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pour Timeline")
                .font(.headline)
            PourTimelineChart(
                steps: timelineSteps,
                totalBrewTime: totalBrewTime,
                color: .blue,
                currentTime: elapsed
            )
            .frame(height: 220)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var stepCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Step Guidance")
                .font(.headline)
            if let currentStep {
                Text("Now: Step \(currentStep.label)")
                    .font(.subheadline.weight(.semibold))
                Text("Pour \(Int(currentStep.waterAmount)) g over \(formatDuration(currentStep.duration))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let nextStep {
                Text("Next: Step \(nextStep.label)")
                    .font(.subheadline.weight(.semibold))
                Text("Starts in \(formatDuration(max(0, nextStep.startTime - elapsed)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("All pours complete")
                    .font(.subheadline.weight(.semibold))
                Text("Let the brew finish its drawdown.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var controlsCard: some View {
        HStack(spacing: 12) {
            if !hasStarted {
                Button {
                    start()
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    togglePause()
                } label: {
                    Label(isRunning ? "Pause" : "Resume", systemImage: isRunning ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(role: .destructive) {
                    finishAndLog()
                } label: {
                    Label("End", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var statusText: String {
        if !hasStarted { return "Ready to start." }
        if elapsed >= totalBrewTime { return "Finished. Opening brew log..." }
        if let currentStep {
            return "Step \(currentStep.label) in progress."
        }
        if let nextStep {
            return "Step \(nextStep.label) starts in \(formatDuration(max(0, nextStep.startTime - elapsed)))."
        }
        return "Drawdown phase."
    }

    private var steps: [PlaybackStep] {
        recipe.pourSteps
            .sorted(by: { $0.order < $1.order })
            .enumerated()
            .map { index, step in
                PlaybackStep(
                    id: index,
                    label: index + 1,
                    startTime: step.startTime,
                    duration: step.duration,
                    waterAmount: step.waterAmount
                )
            }
    }

    private var timelineSteps: [PourTimelineStepData] {
        steps.map {
            PourTimelineStepData(
                startTime: $0.startTime,
                duration: $0.duration,
                waterAmount: $0.waterAmount
            )
        }
    }

    private var totalBrewTime: TimeInterval {
        max(recipe.totalBrewTime, steps.map(\.endTime).max() ?? 0)
    }

    private var currentStep: PlaybackStep? {
        guard hasStarted, elapsed < totalBrewTime else { return nil }
        return steps.first { step in
            elapsed >= step.startTime && elapsed < step.endTime
        }
    }

    private var nextStep: PlaybackStep? {
        guard elapsed < totalBrewTime else { return nil }
        return steps.first(where: { $0.startTime >= elapsed })
    }

    private func start() {
        hasStarted = true
        isRunning = true
        lastTick = .now
    }

    private func togglePause() {
        isRunning.toggle()
        lastTick = isRunning ? .now : nil
    }

    private func finishAndLog() {
        guard !completionTriggered else { return }
        completionTriggered = true
        isRunning = false
        lastTick = nil
        onPlaybackCompleted()
    }

    private struct PlaybackStep: Identifiable {
        let id: Int
        let label: Int
        let startTime: TimeInterval
        let duration: TimeInterval
        let waterAmount: Double

        var endTime: TimeInterval {
            startTime + duration
        }
    }
}

private struct RecipeEditorView: View {
    @Environment(\.modelContext) private var modelContext

    let recipe: Recipe?
    var onSave: (Recipe) -> Void
    var onCancel: () -> Void

    @State private var draft: RecipeDraft
    @State private var showStepEditor = false

    init(recipe: Recipe?, onSave: @escaping (Recipe) -> Void, onCancel: @escaping () -> Void) {
        self.recipe = recipe
        self.onSave = onSave
        self.onCancel = onCancel
        _draft = State(initialValue: RecipeDraft(recipe: recipe))
    }

    var body: some View {
        Form {
            Section("Basics") {
                LabeledContent("Name") {
                    TextField("Recipe name", text: $draft.name)
                        .multilineTextAlignment(.trailing)
                }
                Picker("Method", selection: $draft.brewMethod) {
                    ForEach(BrewMethod.allCases) { method in
                        Text(method.label).tag(method)
                    }
                }
                LabeledContent("Grind") {
                    TextField("Grind reference", text: $draft.grindSetting)
                        .multilineTextAlignment(.trailing)
                }
                Stepper(value: $draft.doseGrams, in: 5...100, step: 1) {
                    Text("Dose: \(Int(draft.doseGrams)) g")
                }
                Stepper(value: $draft.waterTemperatureCelsius, in: 80...100, step: 1) {
                    Text("Water Temp: \(Int(draft.waterTemperatureCelsius))°C")
                }
                LabeledContent("Total Time") {
                    DurationInput(seconds: $draft.brewDurationSeconds)
                }
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

            Section("Notes") {
                TextEditor(text: $draft.notes)
                    .frame(minHeight: 120)
            }
        }
        .navigationTitle(recipe == nil ? "New Recipe" : "Edit Recipe")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(!draft.isValid)
            }
        }
        .onChange(of: draft.totalStepDuration) { _, newValue in
            draft.brewDurationSeconds = max(draft.brewDurationSeconds, newValue)
            draft.brewDurationSeconds = min(draft.brewDurationSeconds, RecipeDraft.Constants.maxBrewDuration)
        }
        .sheet(isPresented: $showStepEditor) {
            NavigationStack {
                PourStepsEditorView(draft: $draft)
            }
        }
    }

    private func save() {
        if let recipe {
            recipe.name = draft.name
            recipe.brewMethod = draft.brewMethod
            recipe.doseGrams = draft.doseGrams
            recipe.grindSetting = draft.grindSetting
            recipe.waterTemperatureCelsius = draft.waterTemperatureCelsius
            recipe.brewDurationSeconds = draft.brewDurationSeconds
            recipe.notes = draft.notes
            recipe.updatedAt = .now

            recipe.pourSteps.forEach { modelContext.delete($0) }
            recipe.pourSteps = draft.makePourSteps(recipe: recipe)
            onSave(recipe)
        } else {
            let newRecipe = Recipe(
                name: draft.name,
                brewMethod: draft.brewMethod,
                doseGrams: draft.doseGrams,
                grindSetting: draft.grindSetting,
                waterTemperatureCelsius: draft.waterTemperatureCelsius,
                brewDurationSeconds: draft.brewDurationSeconds,
                notes: draft.notes
            )
            newRecipe.pourSteps = draft.makePourSteps(recipe: newRecipe)
            modelContext.insert(newRecipe)
            onSave(newRecipe)
        }
    }
}

private struct RecipeDraft: Identifiable {
    struct Constants {
        static let defaultStepDuration: TimeInterval = 30
        static let defaultStepWater: Double = 100
        static let maxBrewDuration: TimeInterval = 1200
    }

    var id = UUID()
    var name: String
    var brewMethod: BrewMethod
    var doseGrams: Double
    var grindSetting: String
    var waterTemperatureCelsius: Double
    var brewDurationSeconds: TimeInterval
    var notes: String
    var stepDrafts: [StepDraft]

    init(recipe: Recipe?) {
        if let recipe {
            name = recipe.name
            brewMethod = recipe.brewMethod
            doseGrams = recipe.doseGrams
            grindSetting = recipe.grindSetting
            waterTemperatureCelsius = recipe.waterTemperatureCelsius
            brewDurationSeconds = min(
                Constants.maxBrewDuration,
                max(recipe.brewDurationSeconds, recipe.pourSteps.map(\.endTime).max() ?? 0)
            )
            notes = recipe.notes
            stepDrafts = recipe.pourSteps
                .sorted(by: { $0.order < $1.order })
                .map { StepDraft(step: $0) }
        } else {
            name = ""
            brewMethod = .v60
            doseGrams = 20
            grindSetting = "EK 8"
            waterTemperatureCelsius = 94
            brewDurationSeconds = 180
            notes = ""
            stepDrafts = []
        }
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        doseGrams > 0 &&
        !stepDrafts.isEmpty &&
        brewDurationSeconds >= totalStepDuration
    }

    func makePourSteps(recipe: Recipe) -> [PourStep] {
        var steps: [PourStep] = []
        for (offset, draft) in stepDrafts.enumerated() {
            let step = PourStep(
                order: offset,
                startTime: draft.startTime,
                duration: draft.duration,
                waterAmount: draft.waterAmount,
                note: draft.note,
                recipe: recipe
            )
            steps.append(step)
        }
        return steps
    }
}

extension RecipeDraft: PourStepDraftContainer {
    var maxBrewDuration: TimeInterval { Constants.maxBrewDuration }
    var defaultStepDuration: TimeInterval { Constants.defaultStepDuration }
    var defaultStepWater: Double { Constants.defaultStepWater }
}

private struct DurationInput: View {
    @Binding var seconds: TimeInterval
    private let maxSeconds: Int = 1200

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading) {
                Text("Minutes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                picker(binding: minutesBinding, range: 0...maxSeconds / 60, labelSuffix: "m")
            }

            VStack(alignment: .leading) {
                Text("Seconds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                picker(binding: secondsBinding, range: 0...59, labelSuffix: "s")
            }
        }
    }

    private func picker(binding: Binding<Int>, range: ClosedRange<Int>, labelSuffix: String) -> some View {
        Picker("", selection: binding) {
            ForEach(range, id: \.self) { value in
                Text("\(value)\(labelSuffix)").tag(value)
            }
        }
        .pickerStyle(.wheel)
        .frame(height: 100)
        .clipped()
    }

    private var minutesBinding: Binding<Int> {
        Binding(
            get: { Int(seconds) / 60 },
            set: { newMinutes in
                let clampedMinutes = min(max(0, newMinutes), maxSeconds / 60)
                let secs = Int(seconds) % 60
                let total = min(maxSeconds, clampedMinutes * 60 + secs)
                seconds = TimeInterval(total)
            }
        )
    }

    private var secondsBinding: Binding<Int> {
        Binding(
            get: { Int(seconds) % 60 },
            set: { newSeconds in
                let normalized = min(max(0, newSeconds), 59)
                let mins = Int(seconds) / 60
                let total = min(maxSeconds, mins * 60 + normalized)
                seconds = TimeInterval(total)
            }
        )
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

#Preview {
    RecipesListView()
        .modelContainer(previewRecipeContainer)
}

@MainActor
private var previewRecipeContainer: ModelContainer = {
    let schema = Schema([Recipe.self, PourStep.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [configuration])
    let context = ModelContext(container)
    let sample = Recipe.sample
    sample.pourSteps.forEach { $0.recipe = sample }
    sample.pourSteps.forEach { context.insert($0) }
    context.insert(sample)
    return container
}()
