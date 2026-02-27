import Foundation
import SwiftUI

struct FlavorTaxonomyNode: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let children: [FlavorTaxonomyNode]

    init(id: String, name: String, children: [FlavorTaxonomyNode] = []) {
        self.id = id
        self.name = name
        self.children = children
    }

    var isLeaf: Bool {
        children.isEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case children
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        children = try container.decodeIfPresent([FlavorTaxonomyNode].self, forKey: .children) ?? []
    }
}

struct FlavorLeaf: Identifiable, Hashable {
    let id: String
    let name: String
    let path: [String]

    var pathLabel: String {
        path.joined(separator: " > ")
    }
}

struct FlavorTaxonomy {
    let version: String
    let nodes: [FlavorTaxonomyNode]

    private let leavesByID: [String: FlavorLeaf]
    private let leaves: [FlavorLeaf]

    init(version: String, nodes: [FlavorTaxonomyNode]) {
        self.version = version
        self.nodes = nodes

        var builtLeaves: [FlavorLeaf] = []
        var builtIndex: [String: FlavorLeaf] = [:]

        func walk(node: FlavorTaxonomyNode, path: [String]) {
            let currentPath = path + [node.name]
            if node.isLeaf {
                let leaf = FlavorLeaf(id: node.id, name: node.name, path: currentPath)
                builtLeaves.append(leaf)
                builtIndex[node.id] = leaf
                return
            }
            for child in node.children {
                walk(node: child, path: currentPath)
            }
        }

        for node in nodes {
            walk(node: node, path: [])
        }

        self.leaves = builtLeaves.sorted(by: { $0.pathLabel < $1.pathLabel })
        self.leavesByID = builtIndex
    }

    func leaf(for id: String) -> FlavorLeaf? {
        leavesByID[id]
    }

    func pathLabel(for id: String) -> String? {
        leavesByID[id]?.pathLabel
    }

    func searchLeaves(query: String) -> [FlavorLeaf] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return leaves }
        return leaves.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) ||
            $0.pathLabel.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var allLeaves: [FlavorLeaf] {
        leaves
    }
}

private struct FlavorTaxonomyPayload: Codable {
    let version: String
    let nodes: [FlavorTaxonomyNode]
}

enum FlavorTaxonomyProvider {
    struct LoadResult {
        let taxonomy: FlavorTaxonomy?
        let error: String?
    }

    static let shared: LoadResult = load()

    private static func load() -> LoadResult {
        for bundle in candidateBundles() {
            if let taxonomy = loadFromBundle(bundle) {
                return LoadResult(taxonomy: taxonomy, error: nil)
            }
        }
        let discovered = candidateBundles()
            .flatMap { bundle in
                bundle.urls(forResourcesWithExtension: "json", subdirectory: nil)?
                    .map { $0.lastPathComponent } ?? []
            }
            .sorted()
        let suffix = discovered.isEmpty ? "none found" : discovered.joined(separator: ", ")
        return LoadResult(
            taxonomy: nil,
            error: "Missing bundled flavor_taxonomy.v1.json (discovered JSON files: \(suffix))."
        )
    }

    private static func candidateBundles() -> [Bundle] {
        [Bundle.main, Bundle(for: BundleToken.self)]
    }

    private final class BundleToken {}

    private static func loadFromBundle(_ bundle: Bundle) -> FlavorTaxonomy? {
        if let exactURL = bundle.url(forResource: "flavor_taxonomy.v1", withExtension: "json"),
           let taxonomy = decodeTaxonomy(at: exactURL) {
            return taxonomy
        }

        let candidates = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        for url in candidates where url.lastPathComponent == "flavor_taxonomy.v1.json" {
            if let taxonomy = decodeTaxonomy(at: url) {
                return taxonomy
            }
        }
        return nil
    }

    private static func decodeTaxonomy(at url: URL) -> FlavorTaxonomy? {
        do {
            let data = try Data(contentsOf: url)
            let payload = try JSONDecoder().decode(FlavorTaxonomyPayload.self, from: data)
            return FlavorTaxonomy(version: payload.version, nodes: payload.nodes)
        } catch {
            return nil
        }
    }
}

struct FlavorTagEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedLeafIDs: [String]

    @State private var searchText = ""
    @State private var navigationPath = NavigationPath()

    private let maxSelection = 5
    private let loadResult = FlavorTaxonomyProvider.shared

    private var selectedCount: Int {
        selectedLeafIDs.count
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if let taxonomy = loadResult.taxonomy {
                    List {
                        selectedSection(taxonomy: taxonomy)

                        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Section("Flavor Families") {
                                ForEach(taxonomy.nodes) { node in
                                    if node.isLeaf {
                                        leafRow(node: node, taxonomy: taxonomy)
                                    } else {
                                        NavigationLink(value: node) {
                                            Text(node.name)
                                        }
                                    }
                                }
                            }
                        } else {
                            Section("Search Results") {
                                let results = taxonomy.searchLeaves(query: searchText)
                                if results.isEmpty {
                                    Text("No flavors found")
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(results) { leaf in
                                        leafRow(leaf: leaf)
                                    }
                                }
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search flavor notes")
                } else {
                    ContentUnavailableView(
                        "Flavor taxonomy unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(loadResult.error ?? "Unable to load flavor data.")
                    )
                }
            }
            .navigationTitle("Flavor Profile")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") {
                        selectedLeafIDs.removeAll()
                    }
                    .disabled(selectedLeafIDs.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .navigationDestination(for: FlavorTaxonomyNode.self) { node in
                if let taxonomy = loadResult.taxonomy {
                    FlavorNodeDetailView(
                        node: node,
                        taxonomy: taxonomy,
                        selectedLeafIDs: $selectedLeafIDs,
                        maxSelection: maxSelection,
                        onLeafSelected: {
                            if !navigationPath.isEmpty {
                                navigationPath.removeLast(navigationPath.count)
                            }
                        }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func selectedSection(taxonomy: FlavorTaxonomy) -> some View {
        Section {
            if selectedLeafIDs.isEmpty {
                Text("Choose up to \(maxSelection) flavor tags.")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedLeafIDs, id: \.self) { id in
                            let label = taxonomy.leaf(for: id)?.name ?? id
                            Button {
                                remove(id: id)
                            } label: {
                                HStack(spacing: 6) {
                                    Text(label)
                                        .lineLimit(1)
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.secondarySystemFill), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        } header: {
            Text("Selected (\(selectedCount)/\(maxSelection))")
        } footer: {
            if selectedCount >= maxSelection {
                Text("Maximum tags selected.")
            }
        }
    }

    private func leafRow(node: FlavorTaxonomyNode, taxonomy: FlavorTaxonomy) -> some View {
        let leaf = taxonomy.leaf(for: node.id) ?? FlavorLeaf(id: node.id, name: node.name, path: [node.name])
        return leafRow(leaf: leaf)
    }

    private func leafRow(leaf: FlavorLeaf) -> some View {
        let isSelected = selectedLeafIDs.contains(leaf.id)
        let canSelectMore = selectedLeafIDs.count < maxSelection

        return Button {
            toggle(leafID: leaf.id)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(leaf.name)
                    Text(leaf.pathLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .opacity((!isSelected && !canSelectMore) ? 0.45 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isSelected && !canSelectMore)
    }

    private func toggle(leafID: String) {
        if let index = selectedLeafIDs.firstIndex(of: leafID) {
            selectedLeafIDs.remove(at: index)
            return
        }
        guard selectedLeafIDs.count < maxSelection else { return }
        selectedLeafIDs.append(leafID)
    }

    private func remove(id: String) {
        selectedLeafIDs.removeAll(where: { $0 == id })
    }
}

private struct FlavorNodeDetailView: View {
    let node: FlavorTaxonomyNode
    let taxonomy: FlavorTaxonomy
    @Binding var selectedLeafIDs: [String]
    let maxSelection: Int
    let onLeafSelected: () -> Void

    var body: some View {
        List {
            ForEach(node.children) { child in
                if child.isLeaf {
                    leafRow(node: child)
                } else {
                    NavigationLink(value: child) {
                        Text(child.name)
                    }
                }
            }
        }
        .navigationTitle(node.name)
        .navigationDestination(for: FlavorTaxonomyNode.self) { childNode in
            FlavorNodeDetailView(
                node: childNode,
                taxonomy: taxonomy,
                selectedLeafIDs: $selectedLeafIDs,
                maxSelection: maxSelection,
                onLeafSelected: onLeafSelected
            )
        }
    }

    private func leafRow(node: FlavorTaxonomyNode) -> some View {
        let leaf = taxonomy.leaf(for: node.id) ?? FlavorLeaf(id: node.id, name: node.name, path: [node.name])
        let isSelected = selectedLeafIDs.contains(leaf.id)
        let canSelectMore = selectedLeafIDs.count < maxSelection

        return Button {
            if let index = selectedLeafIDs.firstIndex(of: leaf.id) {
                selectedLeafIDs.remove(at: index)
            } else if canSelectMore {
                selectedLeafIDs.append(leaf.id)
                onLeafSelected()
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(leaf.name)
                    Text(leaf.pathLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .opacity((!isSelected && !canSelectMore) ? 0.45 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isSelected && !canSelectMore)
    }
}
