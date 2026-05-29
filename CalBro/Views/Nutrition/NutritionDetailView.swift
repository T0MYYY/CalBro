import SwiftUI

struct NutritionDetailView: View {
    @Bindable var viewModel: NutritionViewModel

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Nutrition", subtitle: "Today · May 28", showsBack: true)
            ScrollView {
                VStack(spacing: 14) {
                    HStack(alignment: .top) {
                        ForEach(viewModel.dailyNutrition.macros) { macro in
                            VStack(spacing: 3) {
                                MacroRing(macro: macro, size: macro.id == "calories" ? 68 : 52, stroke: macro.id == "calories" ? 7 : 5)
                                Text(macro.label)
                                    .font(CBTypography.body(11))
                                    .foregroundStyle(CBColors.inkMid)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    Rectangle()
                        .fill(CBColors.inkFaint)
                        .frame(height: 1)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Micronutrients")
                                .font(CBTypography.body(15, weight: .semibold))
                            Spacer()
                            PillTag(text: "20+ tracked", color: CBColors.inkMid)
                        }
                        ForEach(viewModel.dailyNutrition.micronutrients) { micro in
                            VStack(spacing: 3) {
                                HStack {
                                    Text(micro.name)
                                        .font(CBTypography.body(14))
                                        .foregroundStyle(CBColors.inkMid)
                                    Spacer()
                                    Text("\(micro.value) / \(micro.target)")
                                        .font(CBTypography.body(13, weight: .medium))
                                        .foregroundStyle(CBColors.ink)
                                }
                                ProgressBar(progress: micro.progress, color: CBColors.nutrition(micro.colorKey), height: 5)
                            }
                        }
                        Button("Show all nutrients >") {}
                            .font(CBTypography.body(13))
                            .foregroundStyle(CBColors.inkMid)
                            .frame(maxWidth: .infinity)
                            .buttonStyle(.plain)
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
