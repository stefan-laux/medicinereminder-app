import SwiftUI

/// Animated launch screen: two capsule halves spring together to form a whole
/// pill, which then settles and signals completion so `RootView` can hand off to
/// the main interface. Honors Reduce Motion by presenting the assembled state.
struct LaunchAnimationView: View {

    /// Called once the assemble animation completes (or immediately when motion
    /// is reduced, after a brief beat).
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var assembled = false
    @State private var revealText = false

    private let pillColor = MedicineColor.blue

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                pill
                    .frame(width: 160, height: 64)
                    .accessibilityHidden(true)

                Text("MedicineReminder")
                    .font(AppFont.title)
                    .foregroundStyle(.primary)
                    .opacity(revealText ? 1 : 0)
                    .offset(y: revealText ? 0 : 12)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("MedicineReminder"))
        .onAppear(perform: runSequence)
    }

    // MARK: Pill assembly

    private var pill: some View {
        ZStack {
            // Left half slides in from the left.
            PillHalf(color: pillColor, side: .leading)
                .offset(x: assembled ? 0 : -90)
                .rotationEffect(.degrees(assembled ? 0 : -14))

            // Right half slides in from the right.
            PillHalf(color: pillColor, side: .trailing)
                .offset(x: assembled ? 0 : 90)
                .rotationEffect(.degrees(assembled ? 0 : 14))
        }
        .scaleEffect(assembled ? 1 : 0.85)
        .shadow(color: pillColor.color.opacity(assembled ? 0.35 : 0), radius: 18, y: 8)
    }

    // MARK: Sequencing

    private func runSequence() {
        guard !reduceMotion else {
            // Reduced motion: present the final composition, brief pause, hand off.
            assembled = true
            revealText = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { onFinished() }
            return
        }

        withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) {
            assembled = true
        }
        withAnimation(.smooth(duration: 0.4).delay(0.45)) {
            revealText = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
            onFinished()
        }
    }
}

/// One half of the launch pill. A rounded rectangle clipped to one side, tinted
/// with the medicine gradient (lighter on the trailing half for depth).
private struct PillHalf: View {
    enum Side { case leading, trailing }

    let color: MedicineColor
    let side: Side

    var body: some View {
        GeometryReader { proxy in
            RoundedRectangle(cornerRadius: proxy.size.height / 2, style: .continuous)
                .fill(side == .leading ? AnyShapeStyle(color.gradient) : AnyShapeStyle(color.soft))
                .frame(width: proxy.size.width, height: proxy.size.height)
                .mask(alignment: side == .leading ? .leading : .trailing) {
                    Rectangle()
                        .frame(width: proxy.size.width / 2)
                }
        }
    }
}

#if DEBUG
#Preview {
    LaunchAnimationView(onFinished: {})
}
#endif
