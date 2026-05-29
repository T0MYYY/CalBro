import SwiftUI

struct OnboardingFlowView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        ZStack {
            CBColors.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                switch viewModel.step {
                case .goal:
                    GoalSelectionStep(viewModel: viewModel)
                case .body:
                    BodyStatsStep(viewModel: viewModel)
                case .activity:
                    ActivityStep(viewModel: viewModel)
                case .diet:
                    DietPreferencesStep(viewModel: viewModel)
                case .result:
                    TargetResultStep(viewModel: viewModel)
                }
            }
            .frame(maxWidth: 390, maxHeight: 800)
            .background(CBColors.bg)
        }
    }
}

private struct StepProgressHeader: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        HStack(spacing: 12) {
            Button(action: viewModel.back) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(CBColors.inkMid)
            }
            .buttonStyle(.plain)
            ProgressBar(progress: viewModel.progress, color: CBColors.ink, height: 5)
            Text(viewModel.progressText)
                .font(CBTypography.body(13))
                .foregroundStyle(CBColors.inkMid)
        }
        .padding(.horizontal, CBSpacing.page)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(CBColors.inkFaint).frame(height: 1)
        }
    }
}

private struct StepDots: View {
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(index == 0 ? CBColors.ink : CBColors.inkFaint)
                    .frame(width: index == 0 ? 24 : 8, height: 8)
            }
        }
    }
}

private struct GoalSelectionStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepDots()
                .frame(maxWidth: .infinity)
                .padding(.bottom, 20)
            Text("What's your goal?")
                .font(CBTypography.title())
                .foregroundStyle(CBColors.ink)
                .padding(.bottom, 6)
            Text("Shapes your daily calorie target")
                .font(CBTypography.body())
                .foregroundStyle(CBColors.inkMid)
                .padding(.bottom, 18)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(FitnessGoal.allCases) { goal in
                    GoalCard(goal: goal, selected: viewModel.profile.goal == goal) {
                        viewModel.selectGoal(goal)
                    }
                }
            }
            .padding(.bottom, 20)
            PrimaryButton(title: "Next ->", action: viewModel.next)
            Spacer()
        }
        .padding(.horizontal, CBSpacing.page)
        .padding(.top, 14)
    }
}

private struct GoalCard: View {
    let goal: FitnessGoal
    let selected: Bool
    let action: () -> Void

    private var color: Color {
        switch goal {
        case .loseFat: CBColors.terra
        case .buildMuscle: CBColors.ocean
        case .gainWeight: CBColors.gold
        case .maintain: CBColors.sage
        case .betterNutrition: CBColors.plum
        case .healthCondition: Color(hex: 0xb04060)
        }
    }

    private var icon: String {
        switch goal {
        case .loseFat: "arrow.down"
        case .buildMuscle: "arrow.up.arrow.down"
        case .gainWeight: "arrow.up"
        case .maintain: "circle"
        case .betterNutrition: "circle.lefthalf.filled"
        case .healthCondition: "heart"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(color)
                Text(goal.rawValue)
                    .font(CBTypography.body(15, weight: .bold))
                    .foregroundStyle(CBColors.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 105, alignment: .leading)
            .background(selected ? color.opacity(0.07) : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: CBSpacing.cardRadius).stroke(selected ? color : CBColors.inkFaint, lineWidth: 1.5))
            .clipShape(RoundedRectangle(cornerRadius: CBSpacing.cardRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct BodyStatsStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepProgressHeader(viewModel: viewModel)
            VStack(alignment: .leading, spacing: 20) {
                StepTitle(title: "About you", subtitle: "Used to calculate your metabolism")
                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel("Biological sex")
                    HStack(spacing: 10) {
                        ForEach(BiologicalSex.allCases) { sex in
                            SelectableCapsule(title: sex.rawValue, selected: viewModel.profile.sex == sex) {
                                viewModel.selectSex(sex)
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel("Age")
                    CBCard {
                        HStack {
                            Button("-") { viewModel.adjustAge(by: -1) }
                            Spacer()
                            EditableNumberField(
                                value: Binding(
                                    get: { viewModel.profile.age },
                                    set: { viewModel.updateAge($0) }
                                ),
                                unit: "years",
                                width: 96
                            )
                            Spacer()
                            Button("+") { viewModel.adjustAge(by: 1) }
                        }
                        .font(CBTypography.body(20))
                        .foregroundStyle(CBColors.ink)
                    }
                }
                HStack(spacing: 10) {
                    StatField(
                        label: "Height",
                        value: Binding(
                            get: { viewModel.profile.heightCentimeters },
                            set: { viewModel.updateHeight($0) }
                        ),
                        unit: "cm"
                    )
                    StatField(
                        label: "Weight",
                        value: Binding(
                            get: { viewModel.profile.weightKilograms },
                            set: { viewModel.updateWeight($0) }
                        ),
                        unit: "kg"
                    )
                }
                PrimaryButton(title: "Next ->", action: viewModel.next)
            }
            .padding(.horizontal, CBSpacing.page)
            Spacer()
        }
    }
}

private struct ActivityStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            StepProgressHeader(viewModel: viewModel)
            VStack(alignment: .leading, spacing: 10) {
                StepTitle(title: "How active are you?", subtitle: "Sets your activity multiplier")
                    .padding(.bottom, 6)
                ForEach(ActivityLevel.allCases) { level in
                    Button {
                        viewModel.selectActivity(level)
                    } label: {
                        let selected = viewModel.profile.activityLevel == level
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(level.rawValue)
                                    .font(CBTypography.body(16, weight: selected ? .bold : .medium))
                                    .foregroundStyle(selected ? CBColors.controlOnFill : CBColors.ink)
                                Text(level.subtitle)
                                    .font(CBTypography.body(13))
                                    .foregroundStyle(selected ? CBColors.controlOnFill.opacity(0.58) : CBColors.inkMid)
                            }
                            Spacer()
                            Text(level.multiplierLabel)
                                .font(CBTypography.body(13, weight: .semibold))
                                .foregroundStyle(selected ? CBColors.controlOnFill.opacity(0.78) : CBColors.inkMid)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(selected ? CBColors.controlOnFill.opacity(0.12) : CBColors.inkFaint)
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(selected ? CBColors.controlFill : Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: CBSpacing.cardRadius).stroke(selected ? CBColors.controlFill : CBColors.inkFaint, lineWidth: 1.5))
                        .clipShape(RoundedRectangle(cornerRadius: CBSpacing.cardRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                PrimaryButton(title: "Next ->", action: viewModel.next)
                    .padding(.top, 6)
            }
            .padding(.horizontal, CBSpacing.page)
            .padding(.top, 18)
            Spacer()
        }
    }
}

private struct DietPreferencesStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            StepProgressHeader(viewModel: viewModel)
            VStack(alignment: .leading, spacing: 20) {
                StepTitle(title: "Any dietary preferences?", subtitle: "Select all that apply")
                FlowLayout(spacing: 10) {
                    ForEach(DietPreference.allCases) { preference in
                        let selected = viewModel.profile.dietPreferences.contains(preference)
                        Button {
                            viewModel.toggleDietPreference(preference)
                        } label: {
                            HStack(spacing: 6) {
                                Text(preference.displayLabel)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .opacity(selected ? 1 : 0)
                            }
                                .font(CBTypography.body(15, weight: selected ? .semibold : .regular))
                                .foregroundStyle(selected ? CBColors.controlOnFill : CBColors.ink)
                                .frame(minWidth: chipWidth(for: preference), minHeight: 22)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(selected ? CBColors.controlFill : Color.clear)
                                .overlay(Capsule().stroke(selected ? CBColors.controlFill : CBColors.inkFaint, lineWidth: 1.5))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                PrimaryButton(title: "See my targets ->", action: viewModel.next)
                Button("Skip for now", action: viewModel.skipDiet)
                    .font(CBTypography.body(14))
                    .foregroundStyle(CBColors.inkMid)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, CBSpacing.page)
            .padding(.top, 18)
        }
    }

    private func chipWidth(for preference: DietPreference) -> CGFloat {
        switch preference {
        case .noRestriction: 124
        case .vegetarian, .glutenFree, .dairyFree, .highProtein: 108
        case .lowCarb: 88
        case .vegan, .keto: 70
        }
    }
}

private struct TargetResultStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your daily targets")
                .font(CBTypography.body())
                .foregroundStyle(CBColors.inkMid)
            VStack(spacing: 4) {
                Text(viewModel.displayCalories.formatted())
                    .font(CBTypography.display(80))
                    .foregroundStyle(CBColors.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("kcal / day")
                    .font(CBTypography.body(16))
                    .foregroundStyle(CBColors.inkMid)
            }
            .frame(maxWidth: .infinity)
            HStack(spacing: 10) {
                MacroTarget(label: "Protein", value: "\(viewModel.displayProtein)g", color: CBColors.plum)
                MacroTarget(label: "Carbs",   value: "\(viewModel.displayCarbs)g",   color: CBColors.ocean)
                MacroTarget(label: "Fat",     value: "\(viewModel.displayFat)g",     color: CBColors.gold)
            }
            CBCard(background: CBColors.bgSoft) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(viewModel.profile.goal.title)
                            .font(CBTypography.body(15, weight: .semibold))
                            .foregroundStyle(CBColors.ink)
                        Spacer()
                        PillTag(text: viewModel.weeklyDeltaLabel, color: CBColors.sage)
                    }
                    Text(viewModel.goalTimelineLabel)
                        .font(CBTypography.body(14))
                        .foregroundStyle(CBColors.inkMid)
                }
            }
            HStack {
                MetricCard(value: "\(viewModel.displayBMR.formatted()) kcal", label: "BMR")
                MetricCard(value: "\(viewModel.displayTDEE.formatted()) kcal", label: "TDEE")
                MetricCard(
                    value: "\(viewModel.profile.goal.dailyAdjustment < 0 ? "-" : "+")\(abs(viewModel.profile.goal.dailyAdjustment)) kcal",
                    label: viewModel.profile.goal.dailyAdjustment < 0 ? "Deficit" : "Surplus",
                    color: viewModel.profile.goal.dailyAdjustment < 0 ? CBColors.terra : CBColors.sage
                )
            }
            PrimaryButton(title: "Start Tracking", action: viewModel.next)
            Spacer()
        }
        .padding(.horizontal, CBSpacing.page)
        .padding(.top, 20)
    }
}

private struct StepTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(CBTypography.title())
                .foregroundStyle(CBColors.ink)
            Text(subtitle)
                .font(CBTypography.body())
                .foregroundStyle(CBColors.inkMid)
        }
    }
}

private struct FieldLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(CBTypography.body(14))
            .foregroundStyle(CBColors.inkMid)
    }
}

private struct SelectableCapsule: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(CBTypography.body(15, weight: selected ? .bold : .regular))
                .foregroundStyle(selected ? CBColors.controlOnFill : CBColors.inkMid)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selected ? CBColors.controlFill : Color.clear)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? CBColors.controlFill : CBColors.inkFaint, lineWidth: 1.5))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct StatField: View {
    let label: String
    @Binding var value: Int
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel(label)
            CBCard {
                EditableNumberField(value: $value, unit: unit, width: 76)
            }
        }
    }
}

private struct EditableNumberField: View {
    @Binding var value: Int
    let unit: String
    let width: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            TextField("", value: $value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(CBTypography.display(unit == "years" ? 32 : 28))
                .foregroundStyle(CBColors.ink)
                .frame(width: width)
                .textFieldStyle(.plain)
                .accessibilityLabel(unit)
            Text(unit)
                .font(CBTypography.body(14))
                .foregroundStyle(CBColors.inkMid)
            if unit != "years" {
                Spacer(minLength: 0)
            }
        }
    }
}

private struct MacroTarget: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(CBTypography.display(22))
                .foregroundStyle(color)
            Text(label)
                .font(CBTypography.body(12))
                .foregroundStyle(CBColors.inkMid)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.05))
        .overlay(RoundedRectangle(cornerRadius: CBSpacing.cardRadius).stroke(color.opacity(0.27), lineWidth: 1.5))
        .clipShape(RoundedRectangle(cornerRadius: CBSpacing.cardRadius, style: .continuous))
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 350
        var rowWidth: CGFloat = 0
        var height: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > width, rowWidth > 0 {
                height += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: height + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    OnboardingFlowView(viewModel: OnboardingViewModel())
}
