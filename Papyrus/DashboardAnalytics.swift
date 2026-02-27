import Foundation

struct DashboardMetrics {
    let totalBrews: Int
    let brewsThisWeek: Int
    let currentStreakDays: Int
    let averageBrewDurationSeconds: TimeInterval
}

struct CalendarDayActivity: Identifiable {
    let date: Date
    let count: Int
    let intensityLevel: Int

    var id: Date { date }
}

struct DashboardWeek: Identifiable {
    let startDate: Date
    let days: [CalendarDayActivity?]

    var id: Date { startDate }
}

struct MethodStat: Identifiable {
    let method: String
    let count: Int
    let percentage: Double

    var id: String { method }
}

struct FlavorTagStat: Identifiable {
    let name: String
    let count: Int

    var id: String { name }
}

struct StatisticsBreakdown {
    let totalBrews: Int
    let averageDose: Double
    let averageYield: Double
    let averageBrewDurationSeconds: TimeInterval
    let averageAcidity: Double
    let averageBalance: Double
    let averageSweetness: Double
    let methods: [MethodStat]
    let topFlavorTags: [FlavorTagStat]
}

enum DashboardAnalytics {
    static func computeDashboardMetrics(from brews: [BrewLog], now: Date = .now, calendar: Calendar = .current) -> DashboardMetrics {
        let totalBrews = brews.count
        let averageDuration = totalBrews > 0 ? brews.map(\.brewDurationSeconds).reduce(0, +) / Double(totalBrews) : 0

        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        let brewsThisWeek = brews.filter { $0.createdAt >= weekStart }.count

        var datesWithBrews: Set<Date> = []
        for brew in brews {
            datesWithBrews.insert(calendar.startOfDay(for: brew.createdAt))
        }

        var streak = 0
        var cursor = calendar.startOfDay(for: now)
        while datesWithBrews.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return DashboardMetrics(
            totalBrews: totalBrews,
            brewsThisWeek: brewsThisWeek,
            currentStreakDays: streak,
            averageBrewDurationSeconds: averageDuration
        )
    }

    static func buildCalendar90DayGrid(from brews: [BrewLog], now: Date = .now, calendar: Calendar = .current) -> [DashboardWeek] {
        let endDay = calendar.startOfDay(for: now)
        guard let startDay = calendar.date(byAdding: .day, value: -89, to: endDay) else { return [] }

        var countsByDay: [Date: Int] = [:]
        for brew in brews {
            let day = calendar.startOfDay(for: brew.createdAt)
            guard day >= startDay && day <= endDay else { continue }
            countsByDay[day, default: 0] += 1
        }

        let maxCount = countsByDay.values.max() ?? 0

        guard let gridStart = calendar.dateInterval(of: .weekOfYear, for: startDay)?.start else { return [] }

        var weeks: [DashboardWeek] = []
        var weekStart = gridStart

        while weekStart <= endDay {
            var days: [CalendarDayActivity?] = []
            for dayOffset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else {
                    days.append(nil)
                    continue
                }

                if date < startDay || date > endDay {
                    days.append(nil)
                    continue
                }

                let count = countsByDay[date, default: 0]
                days.append(CalendarDayActivity(
                    date: date,
                    count: count,
                    intensityLevel: intensity(for: count, maxCount: maxCount)
                ))
            }

            weeks.append(DashboardWeek(startDate: weekStart, days: days))
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) else { break }
            weekStart = next
        }

        return weeks
    }

    static func computeDetailedBreakdown(from brews: [BrewLog]) -> StatisticsBreakdown {
        let total = brews.count
        guard total > 0 else {
            return StatisticsBreakdown(
                totalBrews: 0,
                averageDose: 0,
                averageYield: 0,
                averageBrewDurationSeconds: 0,
                averageAcidity: 0,
                averageBalance: 0,
                averageSweetness: 0,
                methods: [],
                topFlavorTags: []
            )
        }

        let averageDose = brews.map(\.doseGrams).reduce(0, +) / Double(total)
        let averageYield = brews.map(\.yieldGrams).reduce(0, +) / Double(total)
        let averageBrewDuration = brews.map(\.brewDurationSeconds).reduce(0, +) / Double(total)
        let averageAcidity = Double(brews.map(\.sourness).reduce(0, +)) / Double(total)
        let averageBalance = Double(brews.map(\.bitterness).reduce(0, +)) / Double(total)
        let averageSweetness = Double(brews.map(\.sweetness).reduce(0, +)) / Double(total)

        var methodCounts: [String: Int] = [:]
        for brew in brews {
            let method = brew.snapshotMethod.trimmingCharacters(in: .whitespacesAndNewlines)
            methodCounts[method.isEmpty ? "Unknown" : method, default: 0] += 1
        }

        let methods = methodCounts
            .map { method, count in
                MethodStat(method: method, count: count, percentage: Double(count) / Double(total))
            }
            .sorted {
                if $0.count == $1.count {
                    return $0.method < $1.method
                }
                return $0.count > $1.count
            }

        var flavorCounts: [String: Int] = [:]
        for brew in brews {
            for tag in brew.flavorTags {
                let name = tag.leafNameAtCapture.trimmingCharacters(in: .whitespacesAndNewlines)
                flavorCounts[name.isEmpty ? "Unknown" : name, default: 0] += 1
            }
        }

        let topFlavorTags = flavorCounts
            .map { FlavorTagStat(name: $0.key, count: $0.value) }
            .sorted {
                if $0.count == $1.count {
                    return $0.name < $1.name
                }
                return $0.count > $1.count
            }

        return StatisticsBreakdown(
            totalBrews: total,
            averageDose: averageDose,
            averageYield: averageYield,
            averageBrewDurationSeconds: averageBrewDuration,
            averageAcidity: averageAcidity,
            averageBalance: averageBalance,
            averageSweetness: averageSweetness,
            methods: methods,
            topFlavorTags: Array(topFlavorTags.prefix(8))
        )
    }

    private static func intensity(for count: Int, maxCount: Int) -> Int {
        guard count > 0, maxCount > 0 else { return 0 }
        if maxCount == 1 { return 4 }

        let ratio = Double(count) / Double(maxCount)
        switch ratio {
        case 0..<0.25:
            return 1
        case 0.25..<0.5:
            return 2
        case 0.5..<0.75:
            return 3
        default:
            return 4
        }
    }
}
