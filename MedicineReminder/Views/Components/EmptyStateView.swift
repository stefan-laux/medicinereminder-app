//
//  EmptyStateView.swift
//  MedicineReminder
//
//  A thin, app-styled wrapper around `ContentUnavailableView` so every empty
//  state (no medicines, all doses done, no analytics yet) reads consistently
//  and exposes an optional call-to-action button.
//

import SwiftUI

/// App-standard empty state. Wraps `ContentUnavailableView` and optionally
/// surfaces a primary action button beneath the description.
///
/// ```swift
/// EmptyStateView(
///     "No Medicines Yet",
///     systemImage: "pills.fill",
///     description: "Add your first medicine to start tracking doses.",
///     actionTitle: "Add Medicine"
/// ) { showingAdd = true }
/// ```
public struct EmptyStateView: View {
    private let title: String
    private let systemImage: String
    private let description: String?
    private let tint: Color
    private let actionTitle: String?
    private let action: (() -> Void)?

    /// - Parameters:
    ///   - title: Headline describing the empty state.
    ///   - systemImage: SF Symbol shown above the title.
    ///   - description: Optional supporting sentence.
    ///   - tint: Accent for the symbol and action button. Defaults to `.accentColor`.
    ///   - actionTitle: Optional primary button title.
    ///   - action: Closure run when the primary button is tapped.
    public init(_ title: String,
                systemImage: String,
                description: String? = nil,
                tint: Color = .accentColor,
                actionTitle: String? = nil,
                action: (() -> Void)? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
        self.tint = tint
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
                    .font(AppFont.title)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
            }
        } description: {
            if let description {
                Text(description)
            }
        } actions: {
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .buttonStyle(.borderedProminent)
                .tint(tint)
                .accessibilityLabel(actionTitle)
            }
        }
    }
}

#if DEBUG
#Preview("Empty State") {
    EmptyStateView(
        "No Medicines Yet",
        systemImage: "pills.fill",
        description: "Add your first medicine to start tracking your doses and building a streak.",
        tint: MedicineColor.blue.color,
        actionTitle: "Add Medicine"
    ) {}
}

#Preview("All Done") {
    EmptyStateView(
        "All Caught Up",
        systemImage: "checkmark.seal.fill",
        description: "You've logged every dose for today. Nice work!",
        tint: .green
    )
}
#endif
