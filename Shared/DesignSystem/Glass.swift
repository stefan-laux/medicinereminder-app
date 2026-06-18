//
//  Glass.swift
//  MedicineReminder — DesignSystem
//
//  Liquid Glass wrappers. ALL direct iOS 26 `.glassEffect` /
//  `GlassEffectContainer` usage is confined to this file; the rest of the app
//  consumes `GlassCard`, `View.liquidGlass(tint:cornerRadius:)`, and
//  `GlassContainer` and stays clean. On systems without the iOS 26 SDK at
//  runtime we degrade gracefully to `.ultraThinMaterial`.
//
//  SwiftUI-only and widget-safe (no UIKit-only / DoseManager dependencies).
//

import SwiftUI

// MARK: - liquidGlass modifier

private struct LiquidGlassModifier: ViewModifier {
    let tint: Color?
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(glassStyle, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(tintOverlay)
                .overlay(
                    shape.strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                )
        }
    }

    @available(iOS 26.0, *)
    private var glassStyle: Glass {
        if let tint {
            return .regular.tint(tint.opacity(0.25)).interactive()
        }
        return .regular
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    @ViewBuilder
    private var tintOverlay: some View {
        if let tint {
            shape.fill(tint.opacity(0.12))
        }
    }
}

public extension View {
    /// Apply a Liquid Glass surface to this view. On iOS 26 this uses the
    /// system `.glassEffect`; otherwise it falls back to a translucent
    /// material. `tint` applies the medicine accent subtly.
    func liquidGlass(tint: Color? = nil, cornerRadius: CGFloat = Radius.lg) -> some View {
        modifier(LiquidGlassModifier(tint: tint, cornerRadius: cornerRadius))
    }
}

// MARK: - GlassCard

/// A rounded glass container for arbitrary content with consistent padding
/// and an optional accent `tint`.
public struct GlassCard<Content: View>: View {
    private let tint: Color?
    private let cornerRadius: CGFloat
    private let padding: CGFloat
    private let content: Content

    public init(
        tint: Color? = nil,
        cornerRadius: CGFloat = Radius.lg,
        padding: CGFloat = Spacing.lg,
        @ViewBuilder content: () -> Content
    ) {
        self.tint = tint
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .liquidGlass(tint: tint, cornerRadius: cornerRadius)
    }
}

// MARK: - GlassContainer

/// Wraps content in an iOS 26 `GlassEffectContainer` so multiple glass
/// surfaces can morph/merge together. Degrades to a plain container on older
/// systems. Use this around groups of `GlassCard` / `.liquidGlass` views.
public struct GlassContainer<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content

    public init(spacing: CGFloat = Spacing.md, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

// MARK: - Preview

#Preview("Glass") {
    ZStack {
        LinearGradient(
            colors: [MedicineColor.blue.color.opacity(0.4), MedicineColor.violet.color.opacity(0.4)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()

        GlassContainer {
            VStack(spacing: Spacing.lg) {
                GlassCard {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Morning dose")
                            .font(AppFont.headline)
                        Text("Vitamin D · 50 mcg")
                            .font(AppFont.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GlassCard(tint: MedicineColor.coral.color) {
                    Text("Tinted glass card")
                        .font(AppFont.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text("Inline glass")
                    .font(AppFont.body)
                    .padding()
                    .liquidGlass(tint: MedicineColor.emerald.color, cornerRadius: Radius.md)
            }
            .padding()
        }
    }
}
