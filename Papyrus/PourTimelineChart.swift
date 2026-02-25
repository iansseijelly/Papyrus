import SwiftUI
import Charts

struct PourTimelineStepData: Identifiable {
    let id = UUID()
    let startTime: TimeInterval
    let duration: TimeInterval
    let waterAmount: Double

    var endTime: TimeInterval {
        startTime + duration
    }
}

struct PourTimelineChart: View {
    let steps: [PourTimelineStepData]
    let totalBrewTime: TimeInterval
    var color: Color = .blue

    private struct ChartPoint: Identifiable {
        let id = UUID()
        let time: TimeInterval
        let cumulativeWater: Double
    }

    private var timelinePoints: [ChartPoint] {
        let sortedSteps = steps.sorted { lhs, rhs in
            if lhs.startTime == rhs.startTime {
                return lhs.duration < rhs.duration
            }
            return lhs.startTime < rhs.startTime
        }

        var points: [ChartPoint] = [ChartPoint(time: 0, cumulativeWater: 0)]
        var previousTime: TimeInterval = 0
        var cumulativeWater: Double = 0

        for step in sortedSteps {
            if step.startTime > previousTime {
                points.append(ChartPoint(time: step.startTime, cumulativeWater: cumulativeWater))
            }
            cumulativeWater += step.waterAmount
            points.append(ChartPoint(time: step.endTime, cumulativeWater: cumulativeWater))
            previousTime = step.endTime
        }

        let brewEnd = totalBrewTime
        if let last = points.last, brewEnd > last.time {
            points.append(ChartPoint(time: brewEnd, cumulativeWater: last.cumulativeWater))
        }
        return points
    }

    var body: some View {
        let gradient = LinearGradient(
            colors: [
                color.opacity(0.35),
                color.opacity(0.05)
            ],
            startPoint: .top,
            endPoint: .bottom
        )

        Chart(timelinePoints) { point in
            LineMark(
                x: .value("Time", point.time),
                y: .value("Water", point.cumulativeWater)
            )
            .interpolationMethod(.linear)
            .foregroundStyle(color)

            AreaMark(
                x: .value("Time", point.time),
                y: .value("Water", point.cumulativeWater)
            )
            .interpolationMethod(.linear)
            .foregroundStyle(gradient)
        }
        .chartXAxisLabel("Seconds")
        .chartYAxisLabel("Water (g)")
        .chartXScale(domain: 0...max(1, totalBrewTime))
    }
}
