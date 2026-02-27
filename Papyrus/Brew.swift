//
//  Brew.swift
//  Papyrus
//
//  Created by 张成熠 on 2/26/26.
//

import Foundation
import SwiftData

@Model
final class BrewLog {
    var id: UUID
    var createdAt: Date
    var snapshotName: String
    var snapshotMethod: String
    var doseGrams: Double
    var yieldGrams: Double
    var waterTemperatureCelsius: Double
    var grindSetting: String
    var brewDurationSeconds: TimeInterval
    var notes: String
    var sourness: Int
    var bitterness: Int
    var sweetness: Int
    var tastingNotes: String
    var modifiedFromRecipe: Bool
    var customBeanName: String

    @Relationship var bean: Bean?
    @Relationship var baseRecipe: Recipe?
    @Relationship(deleteRule: .cascade, inverse: \BrewStepSnapshot.brew)
    var steps: [BrewStepSnapshot]
    @Relationship(deleteRule: .cascade, inverse: \BrewFlavorTagSnapshot.brew)
    var flavorTags: [BrewFlavorTagSnapshot]

    init(
        id: UUID = .init(),
        snapshotName: String,
        snapshotMethod: String,
        doseGrams: Double,
        yieldGrams: Double,
        waterTemperatureCelsius: Double,
        grindSetting: String,
        brewDurationSeconds: TimeInterval,
        notes: String = "",
        sourness: Int = 5,
        bitterness: Int = 5,
        sweetness: Int = 5,
        tastingNotes: String = "",
        modifiedFromRecipe: Bool = false,
        customBeanName: String = "",
        bean: Bean? = nil,
        baseRecipe: Recipe? = nil,
        steps: [BrewStepSnapshot] = [],
        flavorTags: [BrewFlavorTagSnapshot] = []
    ) {
        self.id = id
        self.snapshotName = snapshotName
        self.snapshotMethod = snapshotMethod
        self.doseGrams = doseGrams
        self.yieldGrams = yieldGrams
        self.waterTemperatureCelsius = waterTemperatureCelsius
        self.grindSetting = grindSetting
        self.brewDurationSeconds = brewDurationSeconds
        self.notes = notes
        self.sourness = sourness
        self.bitterness = bitterness
        self.sweetness = sweetness
        self.tastingNotes = tastingNotes
        self.modifiedFromRecipe = modifiedFromRecipe
        self.customBeanName = customBeanName
        self.bean = bean
        self.baseRecipe = baseRecipe
        self.steps = steps
        self.flavorTags = flavorTags
        self.createdAt = .now
    }

    var ratio: Double {
        guard doseGrams > 0 else { return 0 }
        return yieldGrams / doseGrams
    }
}

@Model
final class BrewStepSnapshot {
    @Attribute(.unique) var id: UUID
    var order: Int
    var startTime: TimeInterval
    var duration: TimeInterval
    var waterAmount: Double
    var note: String

    @Relationship var brew: BrewLog?

    init(
        id: UUID = .init(),
        order: Int,
        startTime: TimeInterval,
        duration: TimeInterval,
        waterAmount: Double,
        note: String = "",
        brew: BrewLog? = nil
    ) {
        self.id = id
        self.order = order
        self.startTime = startTime
        self.duration = duration
        self.waterAmount = waterAmount
        self.note = note
        self.brew = brew
    }
}

@Model
final class BrewFlavorTagSnapshot {
    @Attribute(.unique) var id: UUID
    var order: Int
    var leafID: String
    var leafNameAtCapture: String

    @Relationship var brew: BrewLog?

    init(
        id: UUID = .init(),
        order: Int,
        leafID: String,
        leafNameAtCapture: String,
        brew: BrewLog? = nil
    ) {
        self.id = id
        self.order = order
        self.leafID = leafID
        self.leafNameAtCapture = leafNameAtCapture
        self.brew = brew
    }
}

extension BrewLog {
    var displayBeanName: String {
        if let beanName = bean?.name.trimmingCharacters(in: .whitespacesAndNewlines),
           !beanName.isEmpty {
            return beanName
        }
        let trimmed = customBeanName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unknown Bean" : trimmed
    }

    var sortedFlavorTags: [BrewFlavorTagSnapshot] {
        flavorTags.sorted(by: { $0.order < $1.order })
    }
}
