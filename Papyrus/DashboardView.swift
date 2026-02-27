import Foundation
import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: [SortDescriptor(\BrewLog.createdAt, order: .reverse)]) private var brews: [BrewLog]

    private var metrics: DashboardMetrics {
        DashboardAnalytics.computeDashboardMetrics(from: brews)
    }

    private var calendarWeeks: [DashboardWeek] {
        DashboardAnalytics.buildCalendar90DayGrid(from: brews)
    }

    private var detailedBreakdown: StatisticsBreakdown {
        DashboardAnalytics.computeDetailedBreakdown(from: brews)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    metricsGrid
                    calendarCard
                    menuCard
                }
                .padding()
            }
            .navigationTitle("Dashboard")
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            metricCard(title: "Total Brews", value: "\(metrics.totalBrews)")
            metricCard(title: "This Week", value: "\(metrics.brewsThisWeek)")
            metricCard(title: "Current Streak", value: "\(metrics.currentStreakDays) days")
            metricCard(title: "Avg Brew Time", value: dashboardFormatDuration(metrics.averageBrewDurationSeconds))
        }
    }

    private var calendarCard: some View {
        dashboardCard(title: "Brew Activity (Last 90 Days)") {
            if brews.isEmpty {
                ContentUnavailableView(
                    "No brews yet",
                    systemImage: "calendar",
                    description: Text("Log your first brew to start building activity history.")
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 4) {
                        ForEach(calendarWeeks) { week in
                            VStack(spacing: 4) {
                                ForEach(Array(week.days.enumerated()), id: \.offset) { _, day in
                                    dayCell(day)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                HStack(spacing: 6) {
                    Text("Less")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ForEach(0..<5, id: \.self) { level in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(heatmapColor(level: level))
                            .frame(width: 12, height: 12)
                    }
                    Text("More")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 6)
            }
        }
    }

    private var menuCard: some View {
        dashboardCard(title: "Explore") {
            VStack(spacing: 0) {
                NavigationLink {
                    DetailedStatisticsView(breakdown: detailedBreakdown)
                } label: {
                    menuRow(title: "Detailed statistics", systemImage: "chart.xyaxis.line")
                }
                .buttonStyle(.plain)
                Divider()
                NavigationLink {
                    ChatFeedbackPlaceholderView()
                } label: {
                    menuRow(title: "Ask ChatGPT for pourover feedback", systemImage: "sparkles")
                }
                .buttonStyle(.plain)
                Divider()
                NavigationLink {
                    SettingsView()
                } label: {
                    menuRow(title: "Settings", systemImage: "gearshape")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 12))
    }

    private func menuRow(title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 12)
    }

    private func dayCell(_ day: CalendarDayActivity?) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(heatmapColor(level: day?.intensityLevel ?? 0))
            .frame(width: 12, height: 12)
            .accessibilityElement()
            .accessibilityLabel(dayLabel(day))
            .accessibilityValue(dayValue(day))
    }

    private func heatmapColor(level: Int) -> Color {
        switch level {
        case 1:
            return Color.green.opacity(0.35)
        case 2:
            return Color.green.opacity(0.5)
        case 3:
            return Color.green.opacity(0.7)
        case 4:
            return Color.green.opacity(0.9)
        default:
            return Color(.secondarySystemFill)
        }
    }

    private func dayLabel(_ day: CalendarDayActivity?) -> String {
        guard let day else { return "No date" }
        return day.date.formatted(date: .abbreviated, time: .omitted)
    }

    private func dayValue(_ day: CalendarDayActivity?) -> String {
        guard let day else { return "No activity" }
        return "\(day.count) brews"
    }
}

struct DetailedStatisticsView: View {
    let breakdown: StatisticsBreakdown

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                dashboardCard(title: "Overview") {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Total Brews", value: "\(breakdown.totalBrews)")
                        LabeledContent("Avg Dose", value: "\(Int(breakdown.averageDose.rounded())) g")
                        LabeledContent("Avg Yield", value: "\(Int(breakdown.averageYield.rounded())) g")
                        LabeledContent("Avg Brew Time", value: dashboardFormatDuration(breakdown.averageBrewDurationSeconds))
                    }
                }

                dashboardCard(title: "Ratings") {
                    HStack {
                        ratingColumn("Acidity", value: breakdown.averageAcidity)
                        ratingColumn("Balance", value: breakdown.averageBalance)
                        ratingColumn("Sweetness", value: breakdown.averageSweetness)
                    }
                }

                dashboardCard(title: "Methods") {
                    if breakdown.methods.isEmpty {
                        Text("No method data yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(breakdown.methods.prefix(6)) { stat in
                            HStack {
                                Text(stat.method)
                                Spacer()
                                Text("\(stat.count) • \(Int((stat.percentage * 100).rounded()))%")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.caption)
                        }
                    }
                }

                dashboardCard(title: "Top Flavor Tags") {
                    if breakdown.topFlavorTags.isEmpty {
                        Text("No flavor tags captured yet")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(breakdown.topFlavorTags) { tag in
                                HStack {
                                    Text(tag.name)
                                    Spacer()
                                    Text("\(tag.count)")
                                        .foregroundStyle(.secondary)
                                }
                                .font(.caption)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Detailed Statistics")
    }

    private func ratingColumn(_ title: String, value: Double) -> some View {
        VStack {
            Text(String(format: "%.1f", value))
                .font(.title3.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ChatFeedbackPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Chat Feedback Coming Soon",
            systemImage: "sparkles",
            description: Text("This will generate pour-over feedback prompts from your brew history in a future update.")
        )
        .navigationTitle("Chat Feedback")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SettingsView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
    }

    var body: some View {
        Form {
            Section("App") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Build", value: buildNumber)
            }

            Section("Data") {
                Text("Papyrus uses SwiftData. If schema changes are introduced in future updates, you may need to reset app data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }
}

@ViewBuilder
private func dashboardCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 10) {
        Text(title)
            .font(.headline)
        content()
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
}

private func dashboardFormatDuration(_ time: TimeInterval) -> String {
    guard time.isFinite else { return "--" }
    let minutes = Int(time) / 60
    let seconds = Int(time) % 60
    if minutes > 0 {
        return "\(minutes)m \(seconds)s"
    }
    return "\(seconds)s"
}
