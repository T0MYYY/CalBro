import SwiftUI

// MARK: - Profile Hub

struct ProfileHubView: View {
    @Bindable var navigation: AppNavigationViewModel
    @Bindable var goals: GoalsViewModel
    @State private var showEditProfile = false
    private let mealStore = MealLogStore.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Header card
                profileHeaderCard

                // TDEE / calorie breakdown
                CBCard {
                    TDEEBreakdownCard(items: goals.tdeeItems)
                }

                // Macro targets
                CBCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Daily macro targets")
                            .font(CBTypography.body(15, weight: .semibold))
                            .foregroundStyle(CBColors.ink)
                        HStack(spacing: 8) {
                            MacroTarget(label: "Protein", grams: goals.profile.proteinTargetG, color: CBColors.plum)
                            MacroTarget(label: "Carbs",   grams: goals.profile.carbTargetG,    color: CBColors.ocean)
                            MacroTarget(label: "Fat",     grams: goals.profile.fatTargetG,     color: CBColors.gold)
                        }
                    }
                }

                // Weekly progress
                CBCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("This week")
                            .font(CBTypography.body(15, weight: .semibold))
                            .foregroundStyle(CBColors.ink)
                        HStack(spacing: 12) {
                            weekStat(value: "\(loggedDaysThisWeek)", label: "days logged", color: CBColors.sage)
                            weekStat(value: "\(weekAvgCalories) kcal", label: "daily avg", color: CBColors.terra)
                            weekStat(value: "\(streak)", label: "day streak", color: CBColors.plum)
                        }
                    }
                }

                // Divider
                Rectangle().fill(CBColors.inkFaint).frame(height: 1).padding(.horizontal)

                // Navigation rows
                navRows
            }
            .padding(.horizontal, CBSpacing.page)
            .padding(.bottom, 96)
        }
        .background(CBColors.bg)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditProfile) {
            ProfileEditView(profile: goals.profile) { updated in
                saveProfile(updated)
                goals.refreshFromDefaults()
            }
        }
    }

    // MARK: Header

    private var profileHeaderCard: some View {
        CBCard(background: CBColors.terra.opacity(0.04), border: CBColors.terra.opacity(0.25)) {
            HStack(spacing: 16) {
                // Initials avatar
                ZStack {
                    Circle().fill(CBColors.terra)
                        .frame(width: 56, height: 56)
                    Text(initials)
                        .font(CBTypography.body(20, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    PillTag(text: goals.profile.goal.title, color: CBColors.terra, filled: true)
                    Text("\(goals.profile.weightDisplay) · \(goals.profile.heightDisplay) · \(goals.profile.age) yrs")
                        .font(CBTypography.body(14))
                        .foregroundStyle(CBColors.inkMid)
                    if goals.profile.weeklyWeightChangeKg != 0 {
                        let kgPerWeek = abs(goals.profile.weeklyWeightChangeKg)
                        let dir = goals.profile.weeklyWeightChangeKg < 0 ? "Lose" : "Gain"
                        Text("\(dir) ~\(goals.profile.weightRateDisplay(kgPerWeek: kgPerWeek))")
                            .font(CBTypography.body(13, weight: .medium))
                            .foregroundStyle(CBColors.sage)
                    }
                }

                Spacer()

                Button("Edit") { showEditProfile = true }
                    .font(CBTypography.body(15, weight: .semibold))
                    .foregroundStyle(CBColors.terra)
                    .buttonStyle(.plain)
            }
        }
    }

    // MARK: Nav rows

    private var navRows: some View {
        VStack(spacing: 0) {
            navRow(title: "Weight prediction", subtitle: "Scenario simulator and target dates",
                   icon: "chart.line.uptrend.xyaxis", color: CBColors.sage) {
                navigation.navigate(.prediction, in: .profile)
            }
            navRow(title: "Plateau detection", subtitle: "Strategy cards for when progress stalls",
                   icon: "waveform.path.ecg", color: CBColors.gold) {
                navigation.navigate(.plateau, in: .profile)
            }
            navRow(title: "Apple Health & Reminders", subtitle: "Sync activity and meal logging alerts",
                   icon: "heart.fill", color: CBColors.ocean) {
                navigation.navigate(.integrations, in: .profile)
            }
            navRow(title: "Widget previews", subtitle: "Lock screen and home screen widgets",
                   icon: "squares.below.rectangle", color: CBColors.plum) {
                navigation.navigate(.widgets, in: .profile)
            }
        }
    }

    private func navRow(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(CBTypography.body(15, weight: .medium)).foregroundStyle(CBColors.ink)
                    Text(subtitle).font(CBTypography.body(13)).foregroundStyle(CBColors.inkMid)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(CBColors.inkMid).font(.system(size: 13))
            }
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) { Rectangle().fill(CBColors.inkLine).frame(height: 1) }
        }
        .buttonStyle(.plain)
    }

    // MARK: Stats helpers

    private var initials: String { "CB" }  // No name in profile — use app initials

    private var loggedDaysThisWeek: Int {
        let cal = Calendar.current, today = cal.startOfDay(for: Date())
        return (0..<7).filter { i in
            let d = cal.date(byAdding: .day, value: i - 6, to: today)!
            return mealStore.meals.contains { cal.isDate($0.timestamp, inSameDayAs: d) }
        }.count
    }

    private var weekAvgCalories: Int {
        let cal = Calendar.current, today = cal.startOfDay(for: Date())
        var total = 0, days = 0
        for i in 0..<7 {
            let d = cal.date(byAdding: .day, value: i - 6, to: today)!
            let consumed = mealStore.meals
                .filter { cal.isDate($0.timestamp, inSameDayAs: d) }
                .reduce(0) { $0 + $1.adjustedCalories }
            if consumed > 0 { total += consumed; days += 1 }
        }
        return days > 0 ? total / days : 0
    }

    private var streak: Int {
        let cal = Calendar.current
        var day = cal.startOfDay(for: Date()), count = 0
        while mealStore.meals.contains(where: { cal.isDate($0.timestamp, inSameDayAs: day) }) {
            count += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    private func weekStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value).font(CBTypography.body(16, weight: .bold)).foregroundStyle(color)
            Text(label).font(CBTypography.body(11)).foregroundStyle(CBColors.inkMid)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: Save profile

    private func saveProfile(_ profile: UserProfile) {
        let snap = AppStateSnapshot(onboardingComplete: true, profile: profile)
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: "calBuddy.appState.v1")
        }
    }
}

private struct MacroTarget: View {
    let label: String; let grams: Int; let color: Color
    var body: some View {
        VStack(spacing: 3) {
            Text("\(grams)g").font(CBTypography.body(17, weight: .bold)).foregroundStyle(color)
            Text(label).font(CBTypography.body(11)).foregroundStyle(CBColors.inkMid)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Profile Edit Sheet

struct ProfileEditView: View {
    let onSave: (UserProfile) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var profile: UserProfile

    init(profile: UserProfile, onSave: @escaping (UserProfile) -> Void) {
        _profile = State(initialValue: profile)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Units") {
                    Picker("Units", selection: $profile.units) {
                        ForEach(UnitSystem.allCases) { u in Text(u.rawValue).tag(u) }
                    }
                    .pickerStyle(.segmented)
                    Text("Calories always shown in kcal. Switches height & weight display.")
                        .font(CBTypography.body(12))
                        .foregroundStyle(CBColors.inkMid)
                }

                Section("Body") {
                    Picker("Sex", selection: $profile.sex) {
                        ForEach(BiologicalSex.allCases) { s in Text(s.rawValue).tag(s) }
                    }
                    Stepper("Age: \(profile.age)", value: $profile.age, in: 13...99)
                    Stepper("Height: \(profile.heightDisplay)", value: $profile.heightCentimeters, in: 100...240, step: 1)
                    Stepper("Weight: \(profile.weightDisplay)", value: $profile.weightKilograms, in: 30...300, step: 1)
                }

                Section("Goal") {
                    Picker("Goal", selection: $profile.goal) {
                        ForEach(FitnessGoal.allCases) { g in Text(g.title).tag(g) }
                    }
                    .pickerStyle(.menu)
                    Picker("Activity", selection: $profile.activityLevel) {
                        ForEach(ActivityLevel.allCases) { a in Text(a.rawValue).tag(a) }
                    }
                    .pickerStyle(.menu)
                }

                Section("Diet") {
                    ForEach(DietPreference.allCases) { pref in
                        Toggle(pref.displayLabel, isOn: Binding(
                            get: { profile.dietPreferences.contains(pref) },
                            set: { on in
                                if on { profile.dietPreferences.insert(pref); profile.dietPreferences.remove(.noRestriction) }
                                else  { profile.dietPreferences.remove(pref); if profile.dietPreferences.isEmpty { profile.dietPreferences.insert(.noRestriction) } }
                            }
                        ))
                        .tint(CBColors.terra)
                    }
                }

                Section("Preview") {
                    let p = computedProfile
                    LabeledContent("BMR", value: "\(p.bmr.formatted()) kcal")
                    LabeledContent("TDEE", value: "\(p.tdee.formatted()) kcal")
                    LabeledContent("Daily target", value: "\(p.calorieTarget.formatted()) kcal")
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(CBColors.terra)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var p = profile
                        p.recalculateTargets()
                        onSave(p)
                        dismiss()
                    }
                    .font(.body.bold())
                    .foregroundStyle(CBColors.terra)
                }
            }
        }
    }

    private var computedProfile: UserProfile {
        var p = profile
        p.recalculateTargets()
        return p
    }
}

// MARK: - Goals Overview

struct GoalsOverviewView: View {
    @Bindable var viewModel: GoalsViewModel

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "My Goal", showsBack: true)
            ScrollView {
                VStack(spacing: 14) {
                    GoalSummaryCard(profile: viewModel.profile)
                    CBCard { TDEEBreakdownCard(items: viewModel.tdeeItems) }
                    if let p = viewModel.prediction {
                        CBCard(background: CBColors.sage.opacity(0.04), border: CBColors.sage.opacity(0.35)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Prediction").font(CBTypography.body(14, weight: .semibold))
                                Text(p.summary).font(CBTypography.body(15, weight: .bold)).foregroundStyle(CBColors.ink)
                                Text("Avg deficit: \(p.averageDeficit) kcal/day")
                                    .font(CBTypography.body(13)).foregroundStyle(CBColors.inkMid)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, CBSpacing.page).padding(.bottom, 96)
            }
        }
        .background(CBColors.bg)
        .navigationBarBackButtonHidden()
        .edgeSwipeBackEnabled()
    }
}

// MARK: - Weight Prediction

struct WeightPredictionView: View {
    @Bindable var viewModel: GoalsViewModel

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Predict", subtitle: "Based on your profile data", showsBack: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    CBCard(background: CBColors.sage.opacity(0.04), border: CBColors.sage.opacity(0.35)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("At current pace").font(CBTypography.body(14)).foregroundStyle(CBColors.inkMid)
                            Text(viewModel.prediction?.summary ?? "Calculating…")
                                .font(CBTypography.body(20, weight: .bold)).foregroundStyle(CBColors.ink)
                            Text("Daily deficit · \(viewModel.prediction?.averageDeficit ?? Int(viewModel.deficit)) kcal")
                                .font(CBTypography.body(14)).foregroundStyle(CBColors.inkMid)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Scenario simulator").font(CBTypography.body(14, weight: .semibold))
                        HStack(spacing: 8) {
                            ForEach(PredictionScenario.allCases) { scenario in
                                ScenarioButton(scenario: scenario, selected: viewModel.selectedScenario == scenario) {
                                    Task { await viewModel.selectScenario(scenario) }
                                }
                            }
                        }
                        CBCard {
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Daily deficit").font(CBTypography.body(14)).foregroundStyle(CBColors.inkMid)
                                    Spacer()
                                    Text("-\(Int(viewModel.deficit)) kcal").font(CBTypography.body(15, weight: .bold))
                                }
                                Slider(value: $viewModel.deficit, in: 100...1000, step: 50) { _ in
                                    Task { await viewModel.updateDeficit(viewModel.deficit) }
                                }
                                .tint(CBColors.terra)
                                HStack {
                                    Text("-100").foregroundStyle(CBColors.inkMid)
                                    Spacer()
                                    Text("-1,000 kcal").foregroundStyle(CBColors.inkMid)
                                }
                                .font(CBTypography.mono(10))
                            }
                        }
                    }
                    Text("Metabolic model recalibrates every 2 weeks using real weight data")
                        .font(CBTypography.body(13)).foregroundStyle(CBColors.inkMid)
                }
                .padding(.horizontal, CBSpacing.page).padding(.bottom, 96)
            }
        }
        .background(CBColors.bg).navigationBarBackButtonHidden().edgeSwipeBackEnabled()
        .task { if viewModel.prediction == nil { await viewModel.selectScenario(.current) } }
    }
}

// MARK: - Plateau Alert

struct PlateauAlertView: View {
    @State private var selectedStrategy: String?
    private let profile: UserProfile = {
        guard let data = UserDefaults.standard.data(forKey: "calBuddy.appState.v1"),
              let snap = try? JSONDecoder().decode(AppStateSnapshot.self, from: data)
        else { return UserProfile() }
        return snap.profile
    }()

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Plateau Detected", showsBack: true)
            ScrollView {
                VStack(spacing: 14) {
                    CBCard(background: CBColors.gold.opacity(0.05), border: CBColors.gold.opacity(0.4)) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                PillTag(text: "Plateau", color: CBColors.gold, filled: true)
                                Text("\(profile.weightDisplay) · 14+ days")
                                    .font(CBTypography.body(19, weight: .bold)).foregroundStyle(CBColors.ink)
                                Text("Metabolism may have adapted.\nTime to adjust strategy.")
                                    .font(CBTypography.body(14)).foregroundStyle(CBColors.inkMid)
                            }
                            Spacer()
                            CalorieRing(progress: 0, label: "14d", subtitle: "flat", size: 58, stroke: 6, color: CBColors.gold, display: false)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What to try").font(CBTypography.body(15, weight: .semibold))
                        StrategyRow(title: "Refeed day", subtitle: "Eat at TDEE to reset leptin levels",
                                    selected: selectedStrategy == "Refeed day") { selectedStrategy = "Refeed day" }
                        StrategyRow(title: "Add light cardio", subtitle: "A 20-min walk can break adaptation",
                                    selected: selectedStrategy == "Add light cardio") { selectedStrategy = "Add light cardio" }
                        StrategyRow(title: "Improve sleep", subtitle: "Poor sleep raises cortisol and hunger",
                                    selected: selectedStrategy == "Improve sleep") { selectedStrategy = "Improve sleep" }
                        StrategyRow(title: "Recalibrate TDEE", subtitle: "Update your target weight to continue",
                                    cta: true, selected: selectedStrategy == "Recalibrate TDEE") { selectedStrategy = "Recalibrate TDEE" }
                    }
                    CBCard(background: CBColors.bgSoft) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Weight History Coming Soon", systemImage: "chart.line.uptrend.xyaxis")
                                .font(CBTypography.body(14, weight: .semibold))
                                .foregroundStyle(CBColors.inkMid)
                            Text("Log your daily weight to enable automatic plateau detection.")
                                .font(CBTypography.body(13)).foregroundStyle(CBColors.inkMid)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, CBSpacing.page).padding(.bottom, 96)
            }
        }
        .background(CBColors.bg).navigationBarBackButtonHidden().edgeSwipeBackEnabled()
    }
}

// MARK: - Shared subviews

private struct GoalSummaryCard: View {
    let profile: UserProfile
    var body: some View {
        CBCard(background: CBColors.terra.opacity(0.03), border: CBColors.terra.opacity(0.33)) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    PillTag(text: "Active goal", color: CBColors.terra)
                    Text(profile.goal.title).font(CBTypography.body(18, weight: .bold)).foregroundStyle(CBColors.ink)
                    Text("\(profile.weightDisplay) · \(profile.age) yrs · \(profile.heightDisplay)")
                        .font(CBTypography.body(14)).foregroundStyle(CBColors.inkMid)
                    Text(profile.activityLevel.rawValue)
                        .font(CBTypography.body(12)).foregroundStyle(CBColors.inkMid)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(profile.calorieTarget.formatted())").font(CBTypography.display(24)).foregroundStyle(CBColors.terra)
                    Text("kcal/day").font(CBTypography.body(11)).foregroundStyle(CBColors.inkMid)
                }
            }
        }
    }
}

private struct ScenarioButton: View {
    let scenario: PredictionScenario; let selected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(scenario.label)
                .font(CBTypography.body(13, weight: .semibold))
                .foregroundStyle(selected ? CBColors.controlOnFill : CBColors.ink)
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(selected ? CBColors.controlFill : Color.clear)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? CBColors.controlFill : CBColors.inkFaint, lineWidth: 1.5))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct StrategyRow: View {
    let title: String; let subtitle: String; var cta = false; var selected = false; let action: () -> Void
    var body: some View {
        Button(action: action) {
            CBCard(background: background, border: border) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(CBTypography.body(15, weight: cta || selected ? .bold : .medium))
                            .foregroundStyle(cta ? CBColors.terra : CBColors.ink)
                        Text(subtitle).font(CBTypography.body(13)).foregroundStyle(CBColors.inkMid)
                    }
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : (cta ? "arrow.right" : "circle"))
                        .foregroundStyle(selected ? CBColors.sage : (cta ? CBColors.terra : CBColors.inkFaint))
                }
            }
        }
        .buttonStyle(.plain)
    }
    private var background: Color { selected ? CBColors.sage.opacity(0.08) : (cta ? CBColors.terra.opacity(0.05) : CBColors.bg) }
    private var border: Color { selected ? CBColors.sage.opacity(0.55) : (cta ? CBColors.terra : CBColors.inkFaint) }
}
