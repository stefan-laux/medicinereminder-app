//
//  Radius.swift
//  MedicineReminder — DesignSystem
//
//  Corner-radius scale for cards, chips, and glass surfaces.
//

import CoreGraphics

public enum Radius {
    /// 6 pt — small chips / badges.
    public static let sm: CGFloat = 6
    /// 10 pt — buttons / inline controls.
    public static let md: CGFloat = 10
    /// 16 pt — standard cards.
    public static let lg: CGFloat = 16
    /// 24 pt — large glass containers / sheets.
    public static let xl: CGFloat = 24
    /// 999 pt — fully pill-shaped / circular surfaces.
    public static let pill: CGFloat = 999
}
