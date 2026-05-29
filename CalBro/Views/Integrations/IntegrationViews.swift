import SwiftUI

struct HealthKitSyncView: View {
    @Bindable var viewModel: IntegrationViewModel

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Integrations", showsBack: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    CBCard(background: CBColors.bgSoft) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 14) {
                                HatchPlaceholder(label: "HK")
                                    .frame(width: 48, height: 48)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Apple Health")
                                        .font(CBTypography.body(17, weight: .bold))
                                    Text(viewModel.healthConnected ? "Connected" : viewModel.healthStatusText)
                                        .font(CBTypography.body(13, weight: .semibold))
                                        .foregroundStyle(viewModel.healthConnected ? CBColors.sage : CBColors.terra)
                                }
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { viewModel.healthConnected },
                                    set: { _ in Task { await viewModel.toggleHealthConnected() } }
                                ))
                                .labelsHidden()
                                .tint(CBColors.terra)
                            }
                            Text("Exercise burn syncs automatically to your daily calorie budget.")
                                .font(CBTypography.body(14))
                                .foregroundStyle(CBColors.inkMid)
                        }
                    }

                    SectionLabel("Read from Health")
                    VStack(spacing: 0) {
                        ForEach(viewModel.healthMetrics) { setting in
                            ToggleRow(title: setting.id.rawValue, subtitle: setting.subtitle, isOn: setting.isEnabled) {
                                viewModel.toggleMetric(setting.id)
                            }
                        }
                    }

                    SectionLabel("Smart Reminders")
                    VStack(spacing: 0) {
                        ForEach(viewModel.reminders) { reminder in
                            ToggleRow(title: reminder.id.rawValue, subtitle: reminder.detail, isOn: reminder.isEnabled) {
                                Task { await viewModel.toggleReminder(reminder.id) }
                            }
                        }
                    }
                }
                .padding(.horizontal, CBSpacing.page)
                .padding(.bottom, 96)
            }
        }
        .background(CBColors.bg)
        .navigationBarBackButtonHidden()
        .edgeSwipeBackEnabled()
    }
}

struct WidgetPreviewView: View {
    @Bindable var viewModel: IntegrationViewModel
    @State private var snapshot: WidgetNutritionSnapshot = .empty()

    private var caloriesText: String { snapshot.caloriesConsumed.formatted() }
    private var pctText: String { "\(Int((snapshot.progress * 100).rounded()))%" }

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Widgets", showsBack: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Add these from the Home Screen: long-press → + → search “CalBro”.")
                        .font(CBTypography.body(13))
                        .foregroundStyle(CBColors.inkMid)

                    SectionLabel("Lock Screen")
                    HStack(spacing: 10) {
                        LockWidgetCard(title: "Calories", value: caloriesText,
                                       subtitle: "of \(snapshot.calorieTarget.formatted()) kcal", showBar: true,
                                       progress: snapshot.progress)
                        LockWidgetCard(title: "Macros", value: "P \(snapshot.protein)g",
                                       subtitle: "C \(snapshot.carbs)g · F \(snapshot.fat)g", showBar: false,
                                       progress: snapshot.progress)
                    }
                    .padding(16)
                    .background(Color(hex: 0x111828))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    SectionLabel("Home Screen")
                    VStack {
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Today")
                                        .font(CBTypography.body(12))
                                        .foregroundStyle(Color.white.opacity(0.45))
                                    Text(caloriesText)
                                        .font(CBTypography.display(26))
                                        .foregroundStyle(.white)
                                    Text("\(snapshot.remaining) kcal left")
                                        .font(CBTypography.body(13))
                                        .foregroundStyle(Color.white.opacity(0.45))
                                }
                                Spacer()
                                CalorieRing(progress: snapshot.progress, label: pctText, subtitle: "", size: 64, stroke: 7, color: CBColors.terra, display: false)
                            }
                            HStack(spacing: 6) {
                                WidgetMacro(label: "P", value: "\(snapshot.protein)g", color: CBColors.plum)
                                WidgetMacro(label: "C", value: "\(snapshot.carbs)g", color: CBColors.ocean)
                                WidgetMacro(label: "F", value: "\(snapshot.fat)g", color: CBColors.gold)
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .padding(16)
                    .background(Color(hex: 0x111828))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(.horizontal, CBSpacing.page)
                .padding(.bottom, 96)
            }
        }
        .background(CBColors.bg)
        .navigationBarBackButtonHidden()
        .edgeSwipeBackEnabled()
        .task {
            snapshot = SharedNutritionStore.load()
            await viewModel.refreshWidgets()
        }
    }
}

private struct SectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(CBTypography.body(12, weight: .medium))
            .foregroundStyle(CBColors.inkMid)
    }
}

private struct ToggleRow: View {
    let title: String
    let subtitle: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(CBTypography.body(16, weight: .medium))
                    .foregroundStyle(CBColors.ink)
                Text(subtitle)
                    .font(CBTypography.body(13))
                    .foregroundStyle(CBColors.inkMid)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { isOn },
                set: { _ in action() }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(CBColors.terra)
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            Rectangle().fill(CBColors.inkLine).frame(height: 1)
        }
    }
}

private struct LockWidgetCard: View {
    let title: String
    let value: String
    let subtitle: String
    let showBar: Bool
    var progress: Double = 0.69

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(CBTypography.body(11))
                .foregroundStyle(Color.white.opacity(0.5))
            Text(value)
                .font(showBar ? CBTypography.display(22) : CBTypography.body(15, weight: .bold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(CBTypography.body(10))
                .foregroundStyle(Color.white.opacity(0.4))
            if showBar {
                ProgressBar(progress: progress, color: CBColors.terra, height: 4)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct WidgetMacro: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(CBTypography.body(14, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(CBTypography.body(10))
                .foregroundStyle(Color.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
