import SwiftUI

struct RootView: View {
    @State private var onboarding = OnboardingViewModel()

    var body: some View {
        Group {
            if onboarding.isComplete {
                MainTabView(profile: onboarding.profile)
            } else {
                OnboardingFlowView(viewModel: onboarding)
            }
        }
        .background(CBColors.bg)
        .font(CBTypography.body())
    }
}

#Preview {
    RootView()
}
