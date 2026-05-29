import SwiftUI

struct CalendarMonthView: View {
    @Bindable var viewModel: CalendarViewModel

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: viewModel.monthTitle, showsBack: true, trailing: AnyView(monthControls))

            HStack {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                    Text(day)
                        .font(CBTypography.body(12))
                        .foregroundStyle(CBColors.inkMid)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)

            let weeks = viewModel.weeks
            VStack(spacing: 4) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 4) {
                        ForEach(row) { cell in
                            CalendarDayCell(
                                day: cell.day,
                                status: cell.status,
                                isToday: cell.isToday,
                                isSelected: cell.day != nil && cell.day == viewModel.selectedDay,
                                action: { if let day = cell.day { viewModel.select(day: day) } }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        viewModel.handleMonthSwipe(
                            width: value.translation.width,
                            height: value.translation.height,
                            startX: value.startLocation.x
                        )
                    }
            )

            HStack(spacing: 14) {
                LegendItem(label: "On target", color: CBColors.sage)
                LegendItem(label: "Over", color: CBColors.terra)
                LegendItem(label: "No log", color: CBColors.inkFaint)
                Spacer()
            }
            .padding(.horizontal, CBSpacing.page)
            .padding(.vertical, 10)

            let summary = viewModel.summary
            CBCard {
                HStack {
                    MetricCard(value: "\(summary.onTarget)", label: "On target")
                    MetricCard(value: "\(summary.over)", label: "Over")
                    MetricCard(value: "\(summary.missed)", label: "Missed")
                }
            }
            .padding(.horizontal, CBSpacing.page)

            Spacer()
        }
        .background(CBColors.bg)
        .navigationBarBackButtonHidden()
        .edgeSwipeBackEnabled()
    }

    private var monthControls: some View {
        HStack(spacing: 18) {
            Button(action: viewModel.previousMonth) {
                Image(systemName: "chevron.left")
            }
            Button(action: viewModel.nextMonth) {
                Image(systemName: "chevron.right")
            }
        }
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(CBColors.inkMid)
        .buttonStyle(.plain)
    }
}

private struct LegendItem: View {
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color.opacity(0.35))
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(color, lineWidth: 1))
                .frame(width: 8, height: 8)
            Text(label)
                .font(CBTypography.body(12))
                .foregroundStyle(CBColors.inkMid)
        }
    }
}
