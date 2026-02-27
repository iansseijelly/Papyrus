//
//  BeansListView.swift
//  Papyrus
//
//  Created by 张成熠 on 2/25/26.
//

import SwiftUI
import SwiftData

struct BeansListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Bean.roastDate, order: .reverse)]) private var beans: [Bean]

    @State private var showCreateSheet = false
    @State private var beanToEdit: Bean?
    @State private var searchText = ""

    private var filteredBeans: [Bean] {
        guard !searchText.isEmpty else { return beans }
        return beans.filter { bean in
            [bean.name, bean.roaster, bean.origin, bean.flavorNotes]
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if beans.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Beans")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        beanToEdit = nil
                        showCreateSheet = true
                    } label: {
                        Label("Add Bean", systemImage: "plus")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search beans, roasters, notes")
            .sheet(isPresented: $showCreateSheet, onDismiss: {
                beanToEdit = nil
            }) {
                NavigationStack {
                    BeanFormView(bean: beanToEdit, onSave: { _ in
                        beanToEdit = nil
                        showCreateSheet = false
                    }, onCancel: {
                        beanToEdit = nil
                        showCreateSheet = false
                    })
                }
            }
        }
    }

    private var list: some View {
        List {
            ForEach(filteredBeans) { bean in
                NavigationLink {
                    BeanDetailView(bean: bean)
                } label: {
                    BeanRowView(bean: bean)
                }
                .contextMenu {
                    Button {
                        beanToEdit = bean
                        showCreateSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        delete(bean)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .onDelete(perform: delete)
        }
        .animation(.default, value: filteredBeans)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            ContentUnavailableView(
                "Track your beans",
                systemImage: "bag",
                description: Text("Add your first bag of coffee to keep roast dates, tasting notes, and inventory in one place.")
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .padding(.top, 16)
        .padding(.horizontal)
    }

    private func delete(_ offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(filteredBeans[index])
            }
        }
    }

    private func delete(_ bean: Bean) {
        withAnimation {
            modelContext.delete(bean)
        }
    }
}

struct BeanRowView: View {
    let bean: Bean

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            icon

            VStack(alignment: .leading, spacing: 4) {
                Text(bean.name)
                    .font(.headline)
                Text(bean.roaster)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(bean.origin) • Roasted \(bean.roastDate, format: .relative(presentation: .named))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if !bean.flavorNotes.isEmpty {
                    Text(bean.flavorNotes)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Gauge(value: bean.remainingPercentage) {
                EmptyView()
            } currentValueLabel: {
                Text(gramsString(bean.remainingGrams))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(.blue)
        }
        .padding(.vertical, 4)
    }

    private var icon: some View {
        Image(systemName: bean.roastLevel.symbolName)
            .frame(width: 36, height: 36)
            .foregroundStyle(.white)
            .background(colorForRoastLevel(bean.roastLevel))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func colorForRoastLevel(_ level: RoastLevel) -> Color {
        switch level {
        case .light:
            return Color.yellow
        case .medium:
            return Color.orange
        case .mediumDark:
            return Color.brown
        case .dark:
            return Color(red: 0.12, green: 0.08, blue: 0.05)
        }
    }
}

struct BeanDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showAdjustRemaining = false
    @State private var showReplenish = false
    @State private var showOverviewEditor = false
    @State private var showNotesEditor = false

    let bean: Bean

    var body: some View {
        List {
            section("Overview") {
                LabeledContent("Name", value: bean.name)
                LabeledContent("Roaster", value: bean.roaster)
                LabeledContent("Origin", value: bean.origin)
                LabeledContent("Roast Level", value: bean.roastLevel.label)
                LabeledContent("Roast Date") {
                    Text(bean.roastDate, format: .dateTime.month().day().year())
                }
                LabeledContent("Days Since Roast", value: "\(bean.daysSinceRoast)d")
            }

            section("Inventory") {
                LabeledContent("Bag Size", value: gramsString(bean.bagWeightGrams))
                LabeledContent("Remaining", value: gramsString(bean.remainingGrams))
                ProgressView(value: bean.usagePercentage) {
                    Text("Usage")
                }
            }

            if !bean.flavorNotes.isEmpty {
                section("Flavor Notes") {
                    Text(bean.flavorNotes)
                        .multilineTextAlignment(.leading)
                }
            } else {
                section("Flavor Notes") {
                    Text("No notes yet")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(bean.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showOverviewEditor = true
                    } label: {
                        Label("Edit Details", systemImage: "pencil")
                    }

                    Button {
                        showAdjustRemaining = true
                    } label: {
                        Label("Adjust Inventory", systemImage: "scalemass")
                    }

                    Button {
                        showReplenish = true
                    } label: {
                        Label("Replenish Bean", systemImage: "arrow.clockwise.circle")
                    }

                    Button {
                        showNotesEditor = true
                    } label: {
                        Label("Edit Notes", systemImage: "note.text")
                    }

                    Button(role: .destructive) {
                        modelContext.delete(bean)
                    } label: {
                        Label("Delete Bean", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showOverviewEditor) {
            NavigationStack {
                BeanOverviewEditView(bean: bean) {
                    showOverviewEditor = false
                }
            }
        }
        .sheet(isPresented: $showAdjustRemaining) {
            NavigationStack {
                BeanInventoryAdjustView(bean: bean) {
                    showAdjustRemaining = false
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showReplenish) {
            NavigationStack {
                BeanReplenishView(bean: bean) {
                    showReplenish = false
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showNotesEditor) {
            NavigationStack {
                BeanNotesEditView(bean: bean) {
                    showNotesEditor = false
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        Section(title, content: content)
    }
}

private struct BeanOverviewEditView: View {
    @Environment(\.dismiss) private var dismiss

    let bean: Bean
    var onDismiss: () -> Void

    @State private var name: String
    @State private var roaster: String
    @State private var origin: String
    @State private var roastLevel: RoastLevel
    @State private var roastDate: Date

    init(bean: Bean, onDismiss: @escaping () -> Void) {
        self.bean = bean
        self.onDismiss = onDismiss
        _name = State(initialValue: bean.name)
        _roaster = State(initialValue: bean.roaster)
        _origin = State(initialValue: bean.origin)
        _roastLevel = State(initialValue: bean.roastLevel)
        _roastDate = State(initialValue: bean.roastDate)
    }

    var body: some View {
        Form {
            Section("Basics") {
                LabeledContent("Name") {
                    TextField("Bean name", text: $name)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Roaster") {
                    TextField("Roaster (e.g., Onyx)", text: $roaster)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Origin") {
                    TextField("Origin (e.g., Gedeb, Ethiopia)", text: $origin)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("Roast") {
                Picker("Roast level", selection: $roastLevel) {
                    ForEach(RoastLevel.allCases) { level in
                        Label(level.label, systemImage: level.symbolName)
                            .tag(level)
                    }
                }
                DatePicker("Roast date", selection: $roastDate, displayedComponents: .date)
            }
        }
        .navigationTitle("Edit Details")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                    onDismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(isSaveDisabled)
            }
        }
    }

    private var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespaces).isEmpty ||
        roaster.trimmingCharacters(in: .whitespaces).isEmpty ||
        origin.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        bean.name = name
        bean.roaster = roaster
        bean.origin = origin
        bean.roastLevel = roastLevel
        bean.roastDate = roastDate
        dismiss()
        onDismiss()
    }
}

private struct BeanNotesEditView: View {
    @Environment(\.dismiss) private var dismiss

    let bean: Bean
    var onDismiss: () -> Void

    @State private var notes: String

    init(bean: Bean, onDismiss: @escaping () -> Void) {
        self.bean = bean
        self.onDismiss = onDismiss
        _notes = State(initialValue: bean.flavorNotes)
    }

    var body: some View {
        Form {
            Section("Flavor Notes") {
                TextEditor(text: $notes)
                    .frame(minHeight: 150)
                    .textInputAutocapitalization(.sentences)
            }
        }
        .navigationTitle("Edit Notes")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                    onDismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    bean.flavorNotes = notes
                    dismiss()
                    onDismiss()
                }
            }
        }
    }
}

private let gramsFormatter: MeasurementFormatter = {
    let formatter = MeasurementFormatter()
    formatter.unitOptions = .providedUnit
    formatter.unitStyle = .short
    formatter.numberFormatter.maximumFractionDigits = 0
    formatter.numberFormatter.minimumFractionDigits = 0
    return formatter
}()

private func gramsString(_ grams: Double) -> String {
    gramsFormatter.string(from: Measurement(value: grams, unit: UnitMass.grams))
}

struct BeanInventoryAdjustView: View {
    @Environment(\.dismiss) private var dismiss

    let bean: Bean
    var onDismiss: () -> Void

    @State private var remaining: Double
    @State private var bagSize: Double

    init(bean: Bean, onDismiss: @escaping () -> Void) {
        self.bean = bean
        self.onDismiss = onDismiss
        _remaining = State(initialValue: bean.remainingGrams)
        _bagSize = State(initialValue: bean.bagWeightGrams)
    }

    var body: some View {
        Form {
            Section("Inventory") {
                Stepper(value: $bagSize, in: 100...1000, step: 10) {
                    Text("Bag size: \(Int(bagSize)) g")
                }

                Stepper(value: $remaining, in: 0...bagSize, step: 5) {
                    Text("Remaining: \(Int(remaining)) g")
                }

                Slider(value: $remaining, in: 0...bagSize, step: 5)

                HStack {
                    Text("Manual entry")
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("grams", value: $remaining, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .frame(maxWidth: 120)
                }
            }
        }
        .navigationTitle("Adjust Remaining")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                    onDismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    bean.bagWeightGrams = bagSize
                    bean.remainingGrams = min(max(0, remaining), bagSize)
                    dismiss()
                    onDismiss()
                }
            }
        }
        .onChange(of: bagSize) { _, newValue in
            if remaining > newValue {
                remaining = newValue
            }
        }
    }
}

private struct BeanReplenishView: View {
    @Environment(\.dismiss) private var dismiss

    let bean: Bean
    var onDismiss: () -> Void

    @State private var roastDate: Date
    @State private var remaining: Double
    @State private var showReplaceConfirmation = false

    init(bean: Bean, onDismiss: @escaping () -> Void) {
        self.bean = bean
        self.onDismiss = onDismiss
        _roastDate = State(initialValue: .now)
        _remaining = State(initialValue: bean.bagWeightGrams)
    }

    var body: some View {
        Form {
            Section("Replenish") {
                DatePicker("New roast date", selection: $roastDate, displayedComponents: .date)

                LabeledContent("Bag size", value: gramsString(bean.bagWeightGrams))

                Stepper(value: $remaining, in: 0...bean.bagWeightGrams, step: 5) {
                    Text("New inventory: \(Int(remaining)) g")
                }

                Slider(value: $remaining, in: 0...bean.bagWeightGrams, step: 5)

                HStack {
                    Text("Manual entry")
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("grams", value: $remaining, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .frame(maxWidth: 120)
                }
            }
        }
        .navigationTitle("Replenish Bean")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                    onDismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: handleSaveTapped)
            }
        }
        .alert("Replace Current Bag?", isPresented: $showReplaceConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Replenish", role: .destructive, action: save)
        } message: {
            Text("You still have \(gramsString(bean.remainingGrams)) recorded. Replenishing will replace the current bag inventory.")
        }
    }

    private func handleSaveTapped() {
        if bean.remainingGrams > 0 {
            showReplaceConfirmation = true
        } else {
            save()
        }
    }

    private func save() {
        bean.roastDate = roastDate
        bean.remainingGrams = min(max(0, remaining), bean.bagWeightGrams)
        dismiss()
        onDismiss()
    }
}

struct BeanFormView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var roaster: String = ""
    @State private var origin: String = ""
    @State private var roastDate: Date = .now
    @State private var roastLevel: RoastLevel = .light
    @State private var flavorNotes: String = ""
    @State private var bagWeight: Double = 250
    @State private var remaining: Double = 250

    let bean: Bean?
    var onSave: (Bean) -> Void
    var onCancel: () -> Void

    init(bean: Bean?, onSave: @escaping (Bean) -> Void, onCancel: @escaping () -> Void) {
        self.bean = bean
        self.onSave = onSave
        self.onCancel = onCancel

        if let bean {
            _name = State(initialValue: bean.name)
            _roaster = State(initialValue: bean.roaster)
            _origin = State(initialValue: bean.origin)
            _roastDate = State(initialValue: bean.roastDate)
            _roastLevel = State(initialValue: bean.roastLevel)
            _flavorNotes = State(initialValue: bean.flavorNotes)
            _bagWeight = State(initialValue: bean.bagWeightGrams)
            _remaining = State(initialValue: bean.remainingGrams)
        }
    }

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Bean name", text: $name)
                TextField("Roaster", text: $roaster)
                TextField("Origin", text: $origin)

                DatePicker("Roast date", selection: $roastDate, displayedComponents: .date)

                Picker("Roast level", selection: $roastLevel) {
                    ForEach(RoastLevel.allCases) { level in
                        Label(level.label, systemImage: level.symbolName)
                            .tag(level)
                    }
                }
            }

            Section("Inventory") {
                Stepper(value: $bagWeight, in: 100...1000, step: 10) {
                    Text("Bag size: \(Int(bagWeight)) g")
                }

                Stepper(value: $remaining, in: 0...bagWeight, step: 5) {
                    Text("Remaining: \(Int(remaining)) g")
                }
            }

            Section("Notes") {
                TextField("Flavor notes (peach, cacao, ...)", text: $flavorNotes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle(bean == nil ? "New Bean" : "Edit Bean")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onCancel()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || roaster.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onChange(of: bagWeight) { _, newValue in
            if remaining > newValue {
                remaining = newValue
            }
        }
    }

    private func save() {
        if let bean {
            bean.name = name
            bean.roaster = roaster
            bean.origin = origin
            bean.roastDate = roastDate
            bean.roastLevel = roastLevel
            bean.bagWeightGrams = bagWeight
            bean.remainingGrams = remaining
            bean.flavorNotes = flavorNotes
            onSave(bean)
        } else {
            let newBean = Bean(
                name: name,
                roaster: roaster,
                origin: origin,
                roastDate: roastDate,
                roastLevel: roastLevel,
                flavorNotes: flavorNotes,
                bagWeightGrams: bagWeight,
                remainingGrams: remaining
            )
            modelContext.insert(newBean)
            onSave(newBean)
        }
    }
}

#Preview {
    BeansListView()
        .modelContainer(previewContainer)
}

@MainActor
private var previewContainer: ModelContainer {
    let container = try! ModelContainer(for: Bean.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = ModelContext(container)
    context.insert(Bean.sample_light)
    context.insert(Bean.sample_medium)
    context.insert(Bean.sample_mediumDark)
    context.insert(Bean.sample_dark)
    return container
}
