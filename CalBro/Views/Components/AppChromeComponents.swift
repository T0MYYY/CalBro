import SwiftUI

struct BottomTabBar: View {
    @Binding var selectedTab: AppTab
    @Namespace private var indicator

    var body: some View {
        GeometryReader { geo in
            let tabs: [AppTab] = [.today, .stats, .profile]
            let tabW = geo.size.width / CGFloat(tabs.count)

            ZStack(alignment: .leading) {
                // Sliding selection capsule
                if let idx = tabs.firstIndex(of: selectedTab) {
                    Capsule()
                        .fill(CBColors.terra.opacity(0.12))
                        .frame(width: tabW - 16, height: 46)
                        .overlay(Capsule().stroke(CBColors.terra.opacity(0.18), lineWidth: 1))
                        .offset(x: CGFloat(idx) * tabW + 8)
                        .animation(.spring(duration: 0.38, bounce: 0.2), value: selectedTab)
                }

                HStack(spacing: 0) {
                    ForEach(tabs) { tab in
                        tabButton(tab)
                            .frame(width: tabW)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 9)
        .padding(.bottom, 8)
        .frame(height: 66)
        .cbGlass(.regular, cornerRadius: 33, tint: CBColors.terra.opacity(0.04), interactive: true)
        .shadow(color: CBColors.ink.opacity(0.08), radius: 18, x: 0, y: 8)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 21, weight: selectedTab == tab ? .semibold : .regular))
                    .scaleEffect(selectedTab == tab ? 1.08 : 1.0)
                Text(tab.rawValue)
                    .font(CBTypography.body(12, weight: selectedTab == tab ? .semibold : .regular))
            }
            .foregroundStyle(selectedTab == tab ? CBColors.terra : CBColors.ink.opacity(0.38))
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .animation(.spring(duration: 0.25), value: selectedTab)
        }
        .buttonStyle(.plain)
    }
}

struct FloatingActionButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(CBColors.terra)
                .frame(width: 58, height: 58)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .cbGlass(.regular, cornerRadius: 29, tint: CBColors.terra.opacity(0.22), interactive: true)
        .shadow(color: CBColors.ink.opacity(0.14), radius: 16, x: 0, y: 8)
    }
}

struct NavHeader: View {
    let title: String
    var subtitle: String?
    var showsBack = false
    var trailing: AnyView?
    @Environment(\.dismiss) private var dismiss

    init(title: String, subtitle: String? = nil, showsBack: Bool = false, trailing: AnyView? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.showsBack = showsBack
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 8) {
            if showsBack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(CBColors.inkMid)
                }
                .buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(CBTypography.title(22))
                    .foregroundStyle(CBColors.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(CBTypography.body(13))
                        .foregroundStyle(CBColors.inkMid)
                }
            }
            Spacer()
            trailing
        }
        .padding(.horizontal, CBSpacing.page)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }
}

struct WeekStrip: View {
    let monthLabel: String
    let streakLabel: String
    let days: [String]
    let dates: [Int]
    let statuses: [NutritionColorKey]
    let selectedIndex: Int
    let onSelect: (Int) -> Void
    var onOpenCalendar: () -> Void = {}

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: onOpenCalendar) {
                    Text(monthLabel)
                        .font(CBTypography.body(13, weight: .medium))
                        .foregroundStyle(CBColors.inkMid)
                }
                .buttonStyle(.plain)
                Spacer()
                Button(action: onOpenCalendar) {
                    Text(streakLabel)
                        .font(CBTypography.body(13, weight: .semibold))
                        .foregroundStyle(CBColors.terra)
                }
                .buttonStyle(.plain)
            }
            HStack {
                ForEach(days.indices, id: \.self) { index in
                    let isSelected = selectedIndex == index
                    Button {
                        onSelect(index)
                    } label: {
                        VStack(spacing: 4) {
                            Text(days[index])
                                .font(CBTypography.body(11, weight: .medium))
                                .foregroundStyle(isSelected ? CBColors.terra : CBColors.inkMid)
                            Text("\(dates[index])")
                                .font(CBTypography.body(15, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(isSelected ? Color.white : CBColors.ink)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(isSelected ? CBColors.terra : CBColors.inkFaint.opacity(0.45))
                                )
                                .clipShape(Circle())
                            Circle()
                                .fill(CBColors.nutrition(statuses[index]))
                                .opacity(statuses[index] == .ink ? 0.0 : 1)
                                .frame(width: 6, height: 6)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(CBColors.inkFaint).frame(height: 1)
        }
    }
}

struct CalendarDayCell: View {
    let day: Int?
    let status: NutritionColorKey?
    let isToday: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(background)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(border, lineWidth: border == .clear ? 0 : 1))
                VStack(spacing: 2) {
                    if let day {
                        Text("\(day)")
                            .font(CBTypography.body(14, weight: isToday ? .bold : .regular))
                            .foregroundStyle(isToday ? CBColors.controlOnFill : CBColors.ink)
                        if let status, !isToday {
                            Circle()
                                .fill(CBColors.nutrition(status))
                                .frame(width: 5, height: 5)
                        }
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .disabled(day == nil)
    }

    private var background: Color {
        if isToday { return CBColors.controlFill }
        if isSelected { return CBColors.terra.opacity(0.14) }
        if let status, status != .ink { return CBColors.nutrition(status).opacity(0.13) }
        return .clear
    }

    private var border: Color {
        if isSelected { return CBColors.terra.opacity(0.55) }
        if let status, status != .ink { return CBColors.nutrition(status).opacity(0.28) }
        return .clear
    }
}

struct TrendBarChart: View {
    let bars: [TrendBar]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Daily calories vs. target")
                .font(CBTypography.body(13))
                .foregroundStyle(CBColors.inkMid)
            ZStack(alignment: .top) {
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundStyle(CBColors.terra.opacity(0.35))
                    .frame(height: 1)
                    .offset(y: 4)
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(bars) { bar in
                        VStack(spacing: 4) {
                            Text(bar.valueLabel)
                                .font(CBTypography.mono(9))
                                .foregroundStyle(bar.progress > 1 ? CBColors.terra : CBColors.inkMid)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(bar.isToday ? CBColors.terra : (bar.progress > 1 ? CBColors.terra.opacity(0.55) : CBColors.sage.opacity(0.55)))
                                .frame(height: CGFloat(min(bar.progress, 1.15)) * 90)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(bar.isToday ? CBColors.terra : .clear, lineWidth: 1.5))
                            Text(bar.day)
                                .font(CBTypography.body(11, weight: bar.isToday ? .bold : .regular))
                                .foregroundStyle(bar.isToday ? CBColors.ink : CBColors.inkMid)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 122, alignment: .bottom)
            }
        }
    }
}

struct TDEEBreakdownCard: View {
    let items: [TDEEItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Calorie budget")
                .font(CBTypography.body(15, weight: .semibold))
                .foregroundStyle(CBColors.ink)
            ForEach(items) { item in
                VStack(spacing: 3) {
                    HStack {
                        Text(item.label)
                            .font(CBTypography.body(13, weight: item.colorKey == .terra ? .bold : .regular))
                            .foregroundStyle(item.colorKey == .terra ? CBColors.ink : CBColors.inkMid)
                        Spacer()
                        Text(item.value)
                            .font(CBTypography.body(13, weight: .semibold))
                            .foregroundStyle(item.colorKey == .terra ? CBColors.terra : CBColors.ink)
                    }
                    ProgressBar(progress: item.progress, color: CBColors.nutrition(item.colorKey), height: 5)
                }
            }
        }
    }
}
