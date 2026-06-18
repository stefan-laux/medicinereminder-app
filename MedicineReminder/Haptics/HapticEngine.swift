import UIKit

/// Centralized haptic feedback for the app. Distinct patterns map to distinct
/// user-meaningful outcomes so the feel of the app is consistent everywhere.
///
/// All members are `@MainActor` because `UIFeedbackGenerator` and its subclasses
/// must be created and triggered on the main thread.
@MainActor
public enum HapticEngine {

    // MARK: Public API (contract §8)

    /// A dose was successfully logged as taken. Crisp, positive "success" tap.
    public static func taken() {
        notify(.success)
    }

    /// A dose was skipped. Softer "warning" pattern to acknowledge without celebrating.
    public static func skipped() {
        notify(.warning)
    }

    /// A new medicine was added. A medium impact to confirm the create action.
    public static func added() {
        impact(.medium)
    }

    /// A streak / adherence milestone was reached. A heavier celebratory burst:
    /// a success notification followed by a rigid impact a beat later.
    public static func milestone() {
        notify(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            impact(.heavy, intensity: 1.0)
        }
    }

    /// Lightweight selection change (segmented pickers, chips, list selection).
    public static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    // MARK: Private helpers (fileprivate to this file only)

    private static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle,
                               intensity: CGFloat = 0.85) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: intensity)
    }
}
