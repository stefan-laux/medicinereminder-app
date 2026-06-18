import SwiftUI

/// Top-level view that plays the launch animation, then transitions to the main
/// tab interface. The transition is a gentle cross-fade/scale that respects
/// Reduce Motion (handled inside `LaunchAnimationView`).
struct RootView: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var didLaunch = false

    var body: some View {
        ZStack {
            if didLaunch {
                MainTabView()
                    .transition(.opacity)
            } else {
                LaunchAnimationView {
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.45)) {
                        didLaunch = true
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.05)))
            }
        }
    }
}

#if DEBUG
#Preview {
    let container = SharedModelContainer.preview()
    RootView()
        .modelContainer(container)
        .environment(DoseManager(context: container.mainContext))
}
#endif
