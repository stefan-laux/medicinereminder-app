//
//  AppFont.swift
//  MedicineReminder — DesignSystem
//
//  Typography tokens. Medicine names & dose headings use SF Pro Rounded
//  (`.system(..., design: .rounded)`); body/caption use the default design.
//  All styles are built from semantic text styles so they scale with
//  Dynamic Type.
//

import SwiftUI

public enum AppFont {
    /// A SF Pro Rounded font at an explicit point size.
    /// Prefer the named styles below where possible so text scales with
    /// Dynamic Type; use this only for bespoke sizing (it does not scale).
    public static func rounded(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    // MARK: - Rounded, Dynamic-Type-scaling display styles
    // These map onto semantic text styles so they respond to the user's
    // preferred content size while keeping the rounded design.

    /// Large rounded title — hero numbers, streak counts.
    public static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)

    /// Section / screen titles.
    public static let title = Font.system(.title, design: .rounded, weight: .bold)

    /// Secondary titles.
    public static let title2 = Font.system(.title2, design: .rounded, weight: .semibold)

    /// Tertiary titles.
    public static let title3 = Font.system(.title3, design: .rounded, weight: .semibold)

    /// Headline — medicine names & dose headings (rounded, emphasized).
    public static let headline = Font.system(.headline, design: .rounded, weight: .semibold)

    /// Rounded subheadline for dosage descriptions.
    public static let subheadline = Font.system(.subheadline, design: .rounded, weight: .medium)

    // MARK: - Default-design body styles

    /// Body copy uses the default (SF Pro Text) design for readability.
    public static let body = Font.body

    /// Emphasized callout for inline labels.
    public static let callout = Font.callout

    /// Footnote text.
    public static let footnote = Font.footnote

    /// Caption — metadata, timestamps.
    public static let caption = Font.caption

    /// Smaller caption.
    public static let caption2 = Font.caption2
}
