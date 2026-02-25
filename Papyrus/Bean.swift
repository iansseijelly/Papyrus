//
//  Bean.swift
//  Papyrus
//
//  Created by 张成熠 on 2/25/26.
//

import Foundation
import SwiftData

enum RoastLevel: String, Codable, CaseIterable, Identifiable {
    case light
    case medium
    case mediumDark
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light:
            return "Light"
        case .medium:
            return "Medium"
        case .mediumDark:
            return "Medium-Dark"
        case .dark:
            return "Dark"
        }
    }

    var symbolName: String {
        switch self {
        case .light:
            return "sun.max"
        case .medium:
            return "sunrise"
        case .mediumDark:
            return "sunset"
        case .dark:
            return "moon.fill"
        }
    }
}

@Model
final class Bean {
    var name: String
    var roaster: String
    var origin: String
    var roastDate: Date
    var roastLevelRaw: RoastLevel
    var flavorNotes: String
    var bagWeightGrams: Double
    var remainingGrams: Double

    init(
        name: String,
        roaster: String,
        origin: String,
        roastDate: Date,
        roastLevel: RoastLevel,
        flavorNotes: String = "",
        bagWeightGrams: Double = 250,
        remainingGrams: Double? = nil
    ) {
        self.name = name
        self.roaster = roaster
        self.origin = origin
        self.roastDate = roastDate
        self.roastLevelRaw = roastLevel
        self.flavorNotes = flavorNotes
        self.bagWeightGrams = bagWeightGrams
        self.remainingGrams = remainingGrams ?? bagWeightGrams
    }

    var roastLevel: RoastLevel {
        get { roastLevelRaw }
        set { roastLevelRaw = newValue }
    }

    var daysSinceRoast: Int {
        Calendar.current.dateComponents([.day], from: roastDate, to: .now).day ?? 0
    }

    var usagePercentage: Double {
        guard bagWeightGrams > 0 else { return 0 }
        return max(0, min(1, 1 - (remainingGrams / bagWeightGrams)))
    }

    var remainingPercentage: Double {
        guard bagWeightGrams > 0 else { return 0 }
        return max(0, min(1, remainingGrams / bagWeightGrams))
    }
}

extension Bean {
    static var sample_light: Bean {
        Bean(
            name: "Light Up Your Day Bean",
            roaster: "My Favorite Roaster",
            origin: "Somewhere on the planet Earth",
            roastDate: Calendar.current.date(byAdding: .day, value: -10, to: .now) ?? .now,
            roastLevel: .light,
            flavorNotes: "Peach, bergamot, jasmine",
            bagWeightGrams: 250
        )
    }
    static var sample_medium: Bean {
        Bean(
            name: "Just about right Bean",
            roaster: "My Favorite Roaster",
            origin: "Somewhere on the planet Earth",
            roastDate: Calendar.current.date(byAdding: .day, value: -12, to: .now) ?? .now,
            roastLevel: .medium,
            flavorNotes: "Milk chocolate, cereal",
            bagWeightGrams: 250
        )
    }

    static var sample_mediumDark: Bean {
        Bean(
            name: "Perfect Roast Bean",
            roaster: "My Favorite Roaster",
            origin: "Somewhere on the planet Earth",
            roastDate: Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now,
            roastLevel: .mediumDark,
            flavorNotes: "Dark chocolate, nutty",
            bagWeightGrams: 250
        )
    }

    static var sample_dark: Bean {
        Bean(
            name: "The O.G.",
            roaster: "My Favorite Roaster",
            origin: "Somewhere on the planet Earth",
            roastDate: Calendar.current.date(byAdding: .day, value: -18, to: .now) ?? .now,
            roastLevel: .dark,
            bagWeightGrams: 250
        )
    }
}
