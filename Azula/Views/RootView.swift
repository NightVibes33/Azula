import SwiftUI

struct RootView: View {
    static let currentOnboardingVersion = 1

    @AppStorage("completedOnboardingVersion") private var completedOnboardingVersion = 0

    var body: some View {
        ZStack {
            AzulaBackground()

            if completedOnboardingVersion < Self.currentOnboardingVersion {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        completedOnboardingVersion = Self.currentOnboardingVersion
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
            } else {
                ContentView {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        completedOnboardingVersion = 0
                    }
                }
                .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
    }
}
