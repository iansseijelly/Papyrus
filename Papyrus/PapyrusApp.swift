//
//  PapyrusApp.swift
//  Papyrus
//
//  Created by 张成熠 on 2/25/26.
//

import SwiftUI
import SwiftData

@main
struct PapyrusApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Bean.self,
            Recipe.self,
            PourStep.self,
            BrewLog.self,
            BrewStepSnapshot.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
