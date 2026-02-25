import SwiftUI

struct StepDraft: Identifiable {
    let id: UUID
    var order: Int
    var startTime: TimeInterval
    var duration: TimeInterval
    var waterAmount: Double
    var note: String

    init(
        id: UUID = .init(),
        order: Int,
        startTime: TimeInterval,
        duration: TimeInterval,
        waterAmount: Double,
        note: String
    ) {
        self.id = id
        self.order = order
        self.startTime = startTime
        self.duration = duration
        self.waterAmount = waterAmount
        self.note = note
    }

    init(step: PourStep) {
        self.init(
            id: step.id,
            order: step.order,
            startTime: step.startTime,
            duration: step.duration,
            waterAmount: step.waterAmount,
            note: step.note
        )
    }

    init(snapshot: BrewStepSnapshot) {
        self.init(
            id: snapshot.id,
            order: snapshot.order,
            startTime: snapshot.startTime,
            duration: snapshot.duration,
            waterAmount: snapshot.waterAmount,
            note: snapshot.note
        )
    }
}

protocol PourStepDraftContainer {
    var stepDrafts: [StepDraft] { get set }
    var brewDurationSeconds: TimeInterval { get set }
    var maxBrewDuration: TimeInterval { get }
    var defaultStepDuration: TimeInterval { get }
    var defaultStepWater: Double { get }
}

extension PourStepDraftContainer {
    var totalStepDuration: TimeInterval {
        stepDrafts.map { $0.startTime + $0.duration }.max() ?? 0
    }

    var totalWater: Double {
        stepDrafts.reduce(0) { $0 + $1.waterAmount }
    }

    func index(for id: UUID) -> Int? {
        stepDrafts.firstIndex { $0.id == id }
    }

    func startTime(forIndex index: Int) -> TimeInterval? {
        guard index < stepDrafts.count else { return nil }
        return stepDrafts[index].startTime
    }

    func cumulativeWater(upTo index: Int) -> Double {
        guard index >= 0 else { return 0 }
        return stepDrafts.prefix(index + 1).reduce(0) { $0 + $1.waterAmount }
    }

    func startBounds(for index: Int, duration: TimeInterval) -> ClosedRange<TimeInterval> {
        let prevEnd: TimeInterval = {
            guard index > 0 else { return 0 }
            let prev = stepDrafts[index - 1]
            return prev.startTime + prev.duration
        }()

        let nextStartCandidate: TimeInterval = {
            guard index + 1 < stepDrafts.count else {
                return maxBrewDuration - duration
            }
            return stepDrafts[index + 1].startTime
        }()

        let maxStart = max(prevEnd, min(nextStartCandidate, maxBrewDuration - duration))
        return prevEnd...maxStart
    }

    mutating func addStep() {
        let newStart = min(totalStepDuration, maxBrewDuration - defaultStepDuration)
        let draft = StepDraft(
            order: stepDrafts.count,
            startTime: newStart,
            duration: defaultStepDuration,
            waterAmount: defaultStepWater,
            note: ""
        )
        stepDrafts.append(draft)
        brewDurationSeconds = max(brewDurationSeconds, totalStepDuration)
    }

    mutating func removeSteps(at offsets: IndexSet) {
        stepDrafts.remove(atOffsets: offsets)
        reindexSteps()
    }

    mutating func reindexSteps() {
        for index in stepDrafts.indices {
            stepDrafts[index].order = index
        }
    }
}

struct PourStepsEditorView<Context: PourStepDraftContainer>: View {
    @Binding var draft: Context
    @Environment(\.dismiss) private var dismiss

    private var displayIndices: [Int] {
        draft.stepDrafts.indices.sorted(by: >)
    }

    private var timelineSteps: [PourTimelineStepData] {
        draft.stepDrafts
            .sorted(by: { $0.startTime < $1.startTime })
            .map {
                PourTimelineStepData(
                    startTime: $0.startTime,
                    duration: $0.duration,
                    waterAmount: $0.waterAmount
                )
            }
    }

    var body: some View {
        List {
            ForEach(displayIndices, id: \.self) { index in
                StepEditorRow(step: $draft.stepDrafts[index], index: index, timeline: draft)
                    .listRowSeparator(.hidden)
            }
            .onDelete { offsets in
                let actual = offsets
                    .compactMap { off -> Int? in
                        guard off < displayIndices.count else { return nil }
                        return displayIndices[off]
                    }
                    .sorted()
                guard !actual.isEmpty else { return }
                draft.stepDrafts.remove(atOffsets: IndexSet(actual))
                draft.reindexSteps()
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                timelineHeader
                Divider()
                stepsHeader
            }
            .background(.regularMaterial)
        }
        .navigationTitle("Pour Steps")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var timelineHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pour Timeline")
                .font(.headline)
            if draft.stepDrafts.isEmpty {
                ContentUnavailableView(
                    "No steps yet",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Add steps to preview the brew curve.")
                )
            } else {
                PourTimelineChart(
                    steps: timelineSteps,
                    totalBrewTime: max(draft.brewDurationSeconds, draft.totalStepDuration)
                )
                .frame(height: 220)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stepsHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Pour Steps")
                    .font(.headline)
                Spacer()
                Button {
                    draft.addStep()
                } label: {
                    Label("Add Step", systemImage: "plus")
                }
            }
            Text("Newest steps appear at the top. Total water \(Int(draft.totalWater)) g.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

struct StepEditorRow<Context: PourStepDraftContainer>: View {
    @Binding var step: StepDraft
    let index: Int?
    let timeline: Context
    @State private var editingField: StepValueField?
    @State private var pendingValue: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Step \(index.map { $0 + 1 } ?? 1)")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 16) {
                    StepField(label: "Start") {
                        if let index {
                            CompactStepper(
                                value: startBinding(for: index),
                                bounds: timeline.startBounds(for: index, duration: step.duration),
                                step: 5
                            ) {
                                Button {
                                    pendingValue = step.startTime
                                    editingField = .start
                                } label: {
                                    Text(formatStepDuration(step.startTime))
                                        .monospacedDigit()
                                        .frame(minWidth: 72, alignment: .center)
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            Text(formatStepDuration(step.startTime))
                                .monospacedDigit()
                                .frame(minWidth: 72, alignment: .center)
                                .foregroundStyle(.secondary)
                        }
                    }

                    StepField(label: "Duration") {
                        CompactStepper(value: $step.duration, in: 5...300, step: 5) {
                            Button {
                                pendingValue = step.duration
                                editingField = .duration
                            } label: {
                                Text("\(Int(step.duration)) s")
                                    .monospacedDigit()
                                    .frame(minWidth: 72, alignment: .center)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack(alignment: .top, spacing: 16) {
                    StepField(label: "Water") {
                        CompactStepper(value: $step.waterAmount, in: 5...600, step: 5) {
                            Button {
                                pendingValue = step.waterAmount
                                editingField = .water
                            } label: {
                                Text("\(Int(step.waterAmount)) g")
                                    .monospacedDigit()
                                    .frame(minWidth: 72, alignment: .center)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    StepField(label: "Total Water", alignment: .center) {
                        Text("\(Int(totalWaterToThisStep)) g")
                            .font(.headline)
                            .monospacedDigit()
                            .frame(minWidth: 72, alignment: .center)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Notes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Care to say something?", text: $step.note, axis: .vertical)
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(.top, 4)

            if let index,
               let startTime = timeline.startTime(forIndex: index) {
                Text("Starts at \(formatStepDuration(startTime)) - ends at \(formatStepDuration(startTime + step.duration))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .sheet(item: $editingField) { field in
            if let config = editorConfig(for: field) {
                NumericPopoverView(
                    title: config.title,
                    unit: config.unit,
                    placeholder: field.placeholder,
                    range: config.range,
                    initialValue: pendingValue,
                    onSave: { newValue in
                        applyEditorValue(newValue, for: field)
                        editingField = nil
                    },
                    onCancel: {
                        editingField = nil
                        pendingValue = currentValue(for: field)
                    }
                )
                .presentationDetents([.fraction(0.3)])
                .presentationCornerRadius(20)
            }
        }
    }

    private func startBinding(for index: Int) -> Binding<TimeInterval> {
        Binding(
            get: { step.startTime },
            set: { newValue in
                let bounds = timeline.startBounds(for: index, duration: step.duration)
                step.startTime = min(max(newValue, bounds.lowerBound), bounds.upperBound)
            }
        )
    }

    private var totalWaterToThisStep: Double {
        guard let knownIndex = index ?? timeline.index(for: step.id) else {
            return timeline.totalWater
        }
        return timeline.cumulativeWater(upTo: knownIndex)
    }

    private func currentValue(for field: StepValueField) -> Double {
        switch field {
        case .start:
            return step.startTime
        case .duration:
            return step.duration
        case .water:
            return step.waterAmount
        }
    }

    private func editorConfig(for field: StepValueField) -> EditorConfig? {
        switch field {
        case .start:
            guard let index else { return nil }
            let bounds = timeline.startBounds(for: index, duration: step.duration)
            return EditorConfig(
                title: "Start Time",
                unit: "s",
                range: bounds,
                value: step.startTime
            )
        case .duration:
            return EditorConfig(
                title: "Duration",
                unit: "s",
                range: 5...300,
                value: step.duration
            )
        case .water:
            return EditorConfig(
                title: "Water Amount",
                unit: "g",
                range: 5...600,
                value: step.waterAmount
            )
        }
    }

    private func applyEditorValue(_ newValue: Double, for field: StepValueField) {
        switch field {
        case .start:
            if let index {
                let bounds = timeline.startBounds(for: index, duration: step.duration)
                step.startTime = min(max(newValue, bounds.lowerBound), bounds.upperBound)
            }
        case .duration:
            step.duration = min(max(newValue, 5), 300)
        case .water:
            step.waterAmount = min(max(newValue, 5), 600)
        }
    }

    private struct EditorConfig {
        let title: String
        let unit: String
        let range: ClosedRange<Double>
        let value: Double
    }
}

enum StepValueField: String, Identifiable {
    case start
    case duration
    case water

    var id: String { rawValue }

    var placeholder: String {
        switch self {
        case .start: return "0"
        case .duration: return "30"
        case .water: return "30"
        }
    }
}

private struct StepField<Content: View>: View {
    let label: String
    var alignment: HorizontalAlignment = .leading
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
    }
}

struct NumericPopoverView: View {
    let title: String
    let unit: String
    let placeholder: String
    let range: ClosedRange<Double>
    let initialValue: Double
    var onSave: (Double) -> Void
    var onCancel: () -> Void

    @State private var value: Double
    @FocusState private var isFocused: Bool

    init(
        title: String,
        unit: String,
        placeholder: String,
        range: ClosedRange<Double>,
        initialValue: Double,
        onSave: @escaping (Double) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.unit = unit
        self.placeholder = placeholder
        self.range = range
        self.initialValue = initialValue
        self.onSave = onSave
        self.onCancel = onCancel
        _value = State(initialValue: initialValue)
    }

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 8)

            Text(title)
                .font(.headline)

            TextField(placeholder, value: $value, formatter: formatter)
                .keyboardType(.decimalPad)
                .focused($isFocused)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            HStack(spacing: 16) {
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                .buttonStyle(.bordered)

                Button("Save") {
                    let clamped = min(max(range.lowerBound, value), range.upperBound)
                    onSave(clamped)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .presentationBackground(.regularMaterial)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isFocused = true
            }
        }
    }

    private var formatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }
}

struct CompactStepper<Label: View>: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    @ViewBuilder var label: () -> Label

    init(value: Binding<Double>, in range: ClosedRange<Double>, step: Double, @ViewBuilder label: @escaping () -> Label) {
        _value = value
        self.range = range
        self.step = step
        self.label = label
    }

    init(value: Binding<Double>, bounds: ClosedRange<Double>, step: Double, @ViewBuilder label: @escaping () -> Label) {
        _value = value
        self.range = bounds
        self.step = step
        self.label = label
    }

    var body: some View {
        HStack(spacing: 8) {
            button(systemName: "minus") {
                value = max(range.lowerBound, value - step)
            }

            label()
                .frame(minWidth: 72, alignment: .center)

            button(systemName: "plus") {
                value = min(range.upperBound, value + step)
            }
        }
    }

    private func button(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .resizable()
                .scaledToFit()
                .frame(width: 10, height: 10)
                .padding(6)
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
        .frame(width: 32, height: 28)
    }
}

private func formatStepDuration(_ time: TimeInterval) -> String {
    guard time.isFinite else { return "--" }
    let minutes = Int(time) / 60
    let seconds = Int(time) % 60
    if minutes > 0 {
        return "\(minutes)m \(seconds)s"
    } else {
        return "\(seconds)s"
    }
}
