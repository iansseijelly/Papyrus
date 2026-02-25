//
//  ContentView.swift
//  Papyrus
//
//  Created by 张成熠 on 2/25/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            BeansListView()
                .tabItem {
                    Label("Beans", systemImage: "bag")
                }

            RecipesListView()
            .tabItem {
                Label("Recipes", systemImage: "book")
            }

            BrewListView()
                .tabItem {
                    Label("Brew", systemImage: "cup.and.saucer.fill")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(previewContainer)
}

@MainActor
private var previewContainer: ModelContainer {
    let schema = Schema([Bean.self, Recipe.self, PourStep.self, BrewLog.self, BrewStepSnapshot.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [configuration])
    let context = ModelContext(container)
    context.insert(Bean.sample_light)
    context.insert(Bean.sample_medium)
    context.insert(Bean.sample_mediumDark)
    context.insert(Bean.sample_dark)
    let recipe = Recipe.sample
    recipe.pourSteps.forEach { context.insert($0) }
    context.insert(recipe)
    let sampleBean = try? context.fetch(FetchDescriptor<Bean>()).first
    let brew = BrewLog(
        snapshotName: "Sample Brew",
        snapshotMethod: recipe.brewMethod.label,
        doseGrams: 20,
        yieldGrams: 320,
        waterTemperatureCelsius: 94,
        grindSetting: "EK 8",
        brewDurationSeconds: 180,
        bean: sampleBean,
        baseRecipe: recipe
    )
    context.insert(brew)
    return container
}
