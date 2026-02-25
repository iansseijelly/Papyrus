//
//  Recipe.swift
//  Papyrus
//
//  Created by 张成熠 on 2/26/26.
//

import Foundation
import SwiftData

enum BrewMethod: String, Codable, CaseIterable, Identifiable {
    case v60
    case kalita
    case chemex
    case clever
    case espresso
    case aeropress
    case moka
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .v60: return "V60"
        case .kalita: return "Kalita Wave"
        case .chemex: return "Chemex"
        case .clever: return "Clever"
        case .espresso: return "Espresso"
        case .aeropress: return "AeroPress"
        case .moka: return "Moka"
        case .other: return "Other"
        }
    }

    var iconName: String {
        switch self {
        case .v60: return "triangle"
        case .kalita: return "waveform"
        case .chemex: return "hourglass"
        case .clever: return "cup.and.saucer"
        case .espresso: return "cup.and.saucer.fill"
        case .aeropress: return "wind"
        case .moka: return "flame"
        case .other: return "questionmark.circle"
        }
    }
}

@Model
final class Recipe {
    var id: UUID
    var name: String
    var brewMethodRaw: BrewMethod
    var doseGrams: Double
    var grindSetting: String
    var waterTemperatureCelsius: Double
    var notes: String
    var brewDurationSeconds: TimeInterval
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \PourStep.recipe)
    var pourSteps: [PourStep]

    init(
        id: UUID = .init(),
        name: String,
        brewMethod: BrewMethod,
        doseGrams: Double,
        grindSetting: String,
        waterTemperatureCelsius: Double,
        brewDurationSeconds: TimeInterval? = nil,
        notes: String = "",
        pourSteps: [PourStep] = []
    ) {
        self.id = id
        self.name = name
        self.brewMethodRaw = brewMethod
        self.doseGrams = doseGrams
        self.grindSetting = grindSetting
        self.waterTemperatureCelsius = waterTemperatureCelsius
        self.notes = notes
        self.pourSteps = pourSteps
        let defaultDuration = pourSteps.reduce(0) { $0 + $1.duration }
        self.brewDurationSeconds = brewDurationSeconds ?? defaultDuration
        createdAt = .now
        updatedAt = .now
    }

    var brewMethod: BrewMethod {
        get { brewMethodRaw }
        set { brewMethodRaw = newValue }
    }

    var ratio: Double {
        guard doseGrams > 0 else { return 0 }
        return totalWater / doseGrams
    }

    var totalBrewTime: TimeInterval {
        max(brewDurationSeconds, pourSteps.map(\.endTime).max() ?? 0)
    }

    var totalWater: Double {
        pourSteps.reduce(0) { $0 + $1.waterAmount }
    }

    var cumulativePoints: [PourPoint] {
        var runningTotal: Double = 0
        return pourSteps
            .sorted(by: { $0.order < $1.order })
            .map { step in
                runningTotal += step.waterAmount
                return PourPoint(time: step.endTime, cumulativeWater: runningTotal)
            }
    }

    func normalizedSteps() -> [PourStep] {
        var referenceStart: TimeInterval = 0
        return pourSteps
            .sorted(by: { $0.order < $1.order })
            .map { step in
                let newStep = step
                newStep.startTime = referenceStart
                referenceStart += step.duration
                newStep.duration = step.duration
                return newStep
            }
    }
}

@Model
final class PourStep: Identifiable {
    @Attribute(.unique) var id: UUID
    var order: Int
    var startTime: TimeInterval
    var duration: TimeInterval
    var waterAmount: Double
    var note: String

    @Relationship var recipe: Recipe?

    init(
        id: UUID = .init(),
        order: Int,
        startTime: TimeInterval,
        duration: TimeInterval,
        waterAmount: Double,
        note: String = "",
        recipe: Recipe? = nil
    ) {
        self.id = id
        self.order = order
        self.startTime = startTime
        self.duration = duration
        self.waterAmount = waterAmount
        self.note = note
        self.recipe = recipe
    }

    var endTime: TimeInterval {
        startTime + duration
    }
}

struct PourPoint: Identifiable {
    let id = UUID()
    let time: TimeInterval
    let cumulativeWater: Double
}

extension Recipe {
    static var sample: Recipe {
        let recipe = Recipe(
            name: "Triple Pour",
            brewMethod: .v60,
            doseGrams: 15,
            grindSetting: "3",
            waterTemperatureCelsius: 92,
            brewDurationSeconds: 210,
            notes: "Triple pour to highlight florals."
        )

        let steps = [
            PourStep(order: 0, startTime: 0, duration: 30, waterAmount: 30, note: "Bloom"),
            PourStep(order: 1, startTime: 30, duration: 30, waterAmount: 120, note: "Pulse 1"),
            PourStep(order: 2, startTime: 80, duration: 30, waterAmount: 90, note: "Pulse 2"),
        ]

        steps.forEach { $0.recipe = recipe }
        recipe.pourSteps = steps
        return recipe
    }
}
