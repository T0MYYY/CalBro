import SwiftUI

struct DashboardView: View {
    @Bindable var viewModel: DashboardViewModel
    @Bindable var navigation: AppNavigationViewModel
    private let mealStore = MealLogStore.shared
    @State private var editingMeal: LoggedMeal?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            CBColors.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    WeekStrip(
                        monthLabel: viewModel.monthLabel,
                        streakLabel: viewModel.streakLabel,
                        days: viewModel.days,
                        dates: viewModel.dates,
                        statuses: viewModel.dayStatuses,
                        selectedIndex: viewModel.selectedWeekdayIndex,
                        onSelect: viewModel.selectWeekday,
                        onOpenCalendar: { navigation.navigate(.calendar, in: .today) }
                    )

                    VStack(spacing: 12) {
                        Button { navigation.navigate(.nutrition, in: .today) } label: {
                            VStack(spacing: 8) {
                                CalorieRing(
                                    progress: viewModel.nutrition.calorieProgress,
                                    label: "\(viewModel.nutrition.caloriesConsumed.formatted())",
                                    subtitle: "kcal"
                                )
                                Text(viewModel.nutrition.caloriesConsumed == 0
                                     ? "Tap to see targets"
                                     : "\(viewModel.nutrition.remainingCalories) kcal remaining")
                                    .font(CBTypography.body(14))
                                    .foregroundStyle(CBColors.inkMid)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)

                        HStack {
                            ForEach(viewModel.nutrition.macros) { macro in
                                VStack(spacing: 3) {
                                    MacroRing(macro: macro)
                                    Text(macro.label).font(CBTypography.body(12)).foregroundStyle(CBColors.inkMid)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, 24)

                        Rectangle().fill(CBColors.inkFaint).frame(height: 1).padding(.horizontal, CBSpacing.page)

                        if viewModel.hasNoMeals {
                            emptyMealsView
                        } else {
                            VStack(spacing: 7) {
                                ForEach(mealStore.mealsForToday()) { logged in
                                    LoggedMealRow(meal: logged,
                                                  onDelete: { mealStore.remove(id: logged.id) },
                                                  onEdit:   { editingMeal = logged })
                                }
                            }
                            .padding(.horizontal, CBSpacing.page)
                        }
                    }
                    .padding(.top, 14)
                    .padding(.bottom, 140)
                }
            }

            FloatingActionButton { navigation.showCameraSheet() }
                .padding(.trailing, 20)
                .padding(.bottom, 82)
        }
        .navigationBarBackButtonHidden()
        .sheet(item: $editingMeal) { meal in
            MealEditSheet(meal: meal) { updated in
                mealStore.update(updated)
            }
        }
    }

    private var emptyMealsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(CBColors.inkMid)
            Text("No meals logged today")
                .font(CBTypography.body(16, weight: .semibold))
                .foregroundStyle(CBColors.inkMid)
            Text("Tap + or scan food with the camera")
                .font(CBTypography.body(14))
                .foregroundStyle(CBColors.inkMid.opacity(0.7))
            Button { navigation.showCameraSheet() } label: {
                Text("Scan a Meal")
                    .font(CBTypography.body(15, weight: .semibold))
                    .foregroundStyle(CBColors.controlOnFill)
                    .padding(.horizontal, 28).padding(.vertical, 12)
                    .background(CBColors.controlFill)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 32)
    }
}

// MARK: - Meal row with swipe edit + delete

private struct LoggedMealRow: View {
    let meal: LoggedMeal
    let onDelete: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 10) {
                Circle().fill(CBColors.terra).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 1) {
                    Text(meal.name).font(CBTypography.body(15, weight: .semibold)).foregroundStyle(CBColors.ink)
                    Text(meal.timeLabel).font(CBTypography.body(12)).foregroundStyle(CBColors.inkMid)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(meal.adjustedCalories) kcal").font(CBTypography.body(14, weight: .semibold)).foregroundStyle(CBColors.ink)
                if meal.servingMultiplier != 1.0 {
                    Text("\(meal.servingMultiplier, specifier: "%.1f")×").font(CBTypography.mono(11)).foregroundStyle(CBColors.inkMid)
                }
            }
            // Reliable action menu — swipeActions do NOT work inside ScrollView+VStack
            Menu {
                Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
                Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(CBColors.inkMid)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(CBColors.bg)
        .overlay(RoundedRectangle(cornerRadius: CBSpacing.cardRadius).stroke(CBColors.inkFaint, lineWidth: 1.5))
        .clipShape(RoundedRectangle(cornerRadius: CBSpacing.cardRadius, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
        .contextMenu {
            Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
            Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
        }
    }
}

// MARK: - Meal edit sheet

struct MealEditSheet: View {
    let meal: LoggedMeal
    let onSave: (LoggedMeal) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var multiplier: Double
    @State private var name: String
    @FocusState private var nameFocused: Bool

    init(meal: LoggedMeal, onSave: @escaping (LoggedMeal) -> Void) {
        self.meal = meal
        self.onSave = onSave
        _multiplier = State(initialValue: meal.servingMultiplier)
        _name = State(initialValue: meal.name)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Editable name + time
                VStack(spacing: 6) {
                    TextField("Meal name", text: $name)
                        .font(CBTypography.title(22))
                        .foregroundStyle(CBColors.ink)
                        .multilineTextAlignment(.center)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit { nameFocused = false }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(nameFocused ? CBColors.inkFaint.opacity(0.5) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(.horizontal, CBSpacing.page)
                    Text(meal.timeLabel)
                        .font(CBTypography.body(14))
                        .foregroundStyle(CBColors.inkMid)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                // Macro preview
                HStack(spacing: 12) {
                    nutrientBox(label: "Calories", value: "\(Int((Double(meal.calories) * multiplier).rounded()))", color: CBColors.terra)
                    nutrientBox(label: "Protein",  value: "\(Int((Double(meal.proteinG) * multiplier).rounded()))g", color: CBColors.plum)
                    nutrientBox(label: "Carbs",    value: "\(Int((Double(meal.carbsG)   * multiplier).rounded()))g", color: CBColors.ocean)
                    nutrientBox(label: "Fat",      value: "\(Int((Double(meal.fatG)     * multiplier).rounded()))g", color: CBColors.gold)
                }
                .padding(.horizontal, CBSpacing.page)

                // Serving stepper
                CBCard {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Serving size")
                                .font(CBTypography.body(15, weight: .medium))
                                .foregroundStyle(CBColors.ink)
                            Spacer()
                            Text("\(multiplier, specifier: "%.1f")×  base")
                                .font(CBTypography.body(15, weight: .bold))
                                .foregroundStyle(CBColors.terra)
                        }
                        HStack(spacing: 0) {
                            ForEach([0.5, 1.0, 1.5, 2.0, 3.0], id: \.self) { v in
                                Button {
                                    withAnimation(.spring(duration: 0.25)) { multiplier = v }
                                } label: {
                                    Text("\(v, specifier: "%.1f")×")
                                        .font(CBTypography.body(13, weight: multiplier == v ? .bold : .regular))
                                        .foregroundStyle(multiplier == v ? CBColors.controlOnFill : CBColors.ink)
                                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                                        .background(multiplier == v ? CBColors.controlFill : Color.clear)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .background(CBColors.inkFaint, in: Capsule())

                        // Slider for fine control
                        Slider(value: $multiplier, in: 0.25...5.0, step: 0.25)
                            .tint(CBColors.terra)
                    }
                }
                .padding(.horizontal, CBSpacing.page)

                Spacer()

                // Save
                Button {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let updated = LoggedMeal(id: meal.id,
                                         name: trimmed.isEmpty ? meal.name : trimmed,
                                         timestamp: meal.timestamp,
                                         calories: meal.calories, proteinG: meal.proteinG,
                                         carbsG: meal.carbsG, fatG: meal.fatG,
                                         servingMultiplier: multiplier)
                    onSave(updated)
                    dismiss()
                } label: {
                    Text("Save Changes")
                        .font(CBTypography.body(17, weight: .semibold))
                        .foregroundStyle(CBColors.controlOnFill)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(CBColors.controlFill)
                        .clipShape(RoundedRectangle(cornerRadius: CBSpacing.buttonRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, CBSpacing.page)
                .padding(.bottom, 24)
            }
            .background(CBColors.bg.ignoresSafeArea())
            .navigationTitle("Edit Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(CBColors.terra)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func nutrientBox(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value).font(CBTypography.body(16, weight: .bold)).foregroundStyle(color)
            Text(label).font(CBTypography.body(11)).foregroundStyle(CBColors.inkMid)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(color.opacity(0.07))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.2), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
