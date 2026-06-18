//
//  SectionHeader.swift
//  MedicineReminder
//
//  A lightweight, reusable section header for lists and scroll views:
//  a rounded title, an optional subtitle / count, an optional leading
//  SF Symbol, and an optional trailing action button.
//

import SwiftUI

/// Reusable section header used by Home, Plans, Analytics and Settings.
///
/// ```swift
/// SectionHeader("Today")
/// SectionHeader("Morning", subtitle: "3 medicines", systemImage: "sunrise.fill")
/// SectionHeader("Medicines", actionTitle: "Add") { showingAdd = true }
/// ```
public struct SectionHeader: View {
    private let title: String
    private let subtitle: String?
    private let systemImage: String?
    private let tint: Color
    private let actionTitle: String?
    private let action: (() -> Void)?

    /// - Parameters:
    ///   - title: The section title (rendered in SF Pro Rounded).
    ///   - subtitle: Optional trailing detail / count text.
    ///   - systemImage: Optional leading SF Symbol.
    ///   - tint: Accent for the leading symbol and trailing action. Defaults to `.accentColor`.
    ///   - actionTitle: Optional trailing button title.
    ///   - action: Closure run when the trailing button is tapped.
    public init(_ title: String,
                subtitle: String? = nil,
                systemImage: String? = nil,
                tint: Color = .accentColor,
                actionTitle: String? = nil,
                action: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }

            Text(title)
                .font(AppFont.headline)
                .foregroundStyle(.primary)

            if let subtitle {
                Text(subtitle)
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(subtitle)
            }

            Spacer(minLength: Spacing.sm)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(tint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(actionTitle)
            }
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

#if DEBUG
#Preview("Section Headers") {
    VStack(alignment: .leading, spacing: Spacing.lg) {
        SectionHeader("Today")
        SectionHeader("Morning", subtitle: "3 medicines", systemImage: "sunrise.fill", tint: MedicineColor.tangerine.color)
        SectionHeader("Medicines", actionTitle: "Add") {}
        SectionHeader("Evening", subtitle: "2 left", systemImage: "moon.stars.fill", tint: MedicineColor.indigo.color, actionTitle: "Edit") {}
    }
    .padding()
}
#endif
