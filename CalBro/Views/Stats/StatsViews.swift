import SwiftUI

struct StatsCaloriesView: View {
    @Bindable var viewModel: StatsViewModel
    @Bindable var navigation: AppNavigationViewModel

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(
                title: "Stats",
                subtitle: "This week · \(weekRangeLabel)",
                trailing: AnyView(
                    Button {
                        navigation.navigate(.weeklyReport, in: .stats)
                    } label: {
                        PillTag(text: "Report >", color: CBColors.inkMid)
                    }
                    .buttonStyle(.plain)
                )
            )
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        MetricCard(
                            value: viewModel.weekAvgCalories > 0 ? "\(viewModel.weekAvgCalories.formatted()) kcal" : "—",
                            label: "Avg"
                        )
                        MetricCard(
                            value: viewModel.calorieTargetLabel,
                            label: "Target"
                        )
                        MetricCard(
                            value: "\(viewModel.loggedDays)/7 days",
                            label: "Logged",
                            color: viewModel.loggedDays >= 5 ? CBColors.sage : CBColors.gold
                        )
                    }
                    Rectangle().fill(CBColors.inkFaint).frame(height: 1)
                    TrendBarChart(bars: viewModel.calorieBars)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Weekly macro averages")
                            .font(CBTypography.body(13)).foregroundStyle(CBColors.inkMid)
                        ForEach(viewModel.weeklyMacros) { macro in
                            MacroBar(macro: macro)
                        }
                    }
                }
                .padding(.horizontal, CBSpacing.page)
                .padding(.bottom, 96)
            }
        }
        .background(CBColors.bg)
    }

    private var weekRangeLabel: String {
        let cal = Calendar.current, today = cal.startOfDay(for: Date())
        let offset = (cal.component(.weekday, from: today) + 5) % 7
        let monday = cal.date(byAdding: .day, value: -offset, to: today)!
        let sunday = cal.date(byAdding: .day, value: 6 - offset, to: today)!
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return "\(f.string(from: monday))–\(f.string(from: sunday))"
    }
}

struct StatsReportView: View {
    @State var stats: StatsViewModel

    init(stats: StatsViewModel? = nil) {
        _stats = State(initialValue: stats ?? StatsViewModel())
    }

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Weekly Report", subtitle: weekRangeLabel, showsBack: true)
            ScrollView {
                VStack(spacing: 14) {
                    // Summary ring
                    HStack(spacing: 20) {
                        CalorieRing(
                            progress: adherenceRatio,
                            label: "\(Int(adherenceRatio * 100))%",
                            subtitle: "",
                            size: 92, stroke: 9,
                            color: adherenceRatio >= 0.7 ? CBColors.sage : CBColors.gold,
                            display: false
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(weekSummaryLabel).font(CBTypography.title(22))
                            Text("\(stats.loggedDays) / 7 days on target")
                            Text("\(stats.streak > 0 ? "\(stats.streak)-day streak" : "No streak yet")")
                        }
                        .font(CBTypography.body(14))
                        .foregroundStyle(CBColors.inkMid)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Rectangle().fill(CBColors.inkFaint).frame(height: 1)

                    // Calorie trend (real data)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Calorie trend").font(CBTypography.body(15, weight: .semibold))
                        TrendBarChart(bars: stats.calorieBars)
                    }

                    // Macro averages
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Macro averages").font(CBTypography.body(15, weight: .semibold))
                        ForEach(stats.weeklyMacros) { macro in MacroBar(macro: macro) }
                    }

                    // Insights
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Insights").font(CBTypography.body(15, weight: .semibold))
                        InsightRow(label: "Days logged", value: "\(stats.loggedDays) / 7")
                        InsightRow(label: "Avg calories",
                                   value: stats.weekAvgCalories > 0 ? "\(stats.weekAvgCalories.formatted()) kcal" : "No data")
                        if let bestDay = stats.bestDayLabel {
                            InsightRow(label: "Best day", value: bestDay)
                        }
                        if let mostLogged = stats.mostLoggedFood {
                            InsightRow(label: "Most logged", value: mostLogged)
                        }
                        InsightRow(label: "Streak", value: stats.streak > 0 ? "\(stats.streak) days" : "Start today!")
                    }
                }
                .padding(.horizontal, CBSpacing.page)
                .padding(.top, 16)
                .padding(.bottom, 96)
            }
        }
        .background(CBColors.bg)
        .navigationBarBackButtonHidden()
        .edgeSwipeBackEnabled()
    }

    private var weekRangeLabel: String {
        let cal = Calendar.current, today = cal.startOfDay(for: Date())
        let offset = (cal.component(.weekday, from: today) + 5) % 7
        let monday = cal.date(byAdding: .day, value: -offset, to: today)!
        let sunday = cal.date(byAdding: .day, value: 6 - offset, to: today)!
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return "\(f.string(from: monday))–\(f.string(from: sunday))"
    }

    private var adherenceRatio: Double {
        guard stats.loggedDays > 0 else { return 0 }
        return Double(stats.loggedDays) / 7.0
    }

    private var weekSummaryLabel: String {
        let pct = Int(adherenceRatio * 100)
        switch pct {
        case 86...: return "Great week!"
        case 57...: return "Good week!"
        case 29...: return "Getting there"
        default:    return "Log more!"
        }
    }
}

private struct InsightRow: View {
    let label: String; let value: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(CBColors.inkMid)
            Spacer()
            Text(value).fontWeight(.medium).foregroundStyle(CBColors.ink)
        }
        .font(CBTypography.body(14))
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) { Rectangle().fill(CBColors.inkLine).frame(height: 1) }
    }
}
