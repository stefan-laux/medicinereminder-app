//
//  ConfettiCanvas.swift
//  MedicineReminder
//
//  A self-contained SwiftUI `Canvas` confetti burst used to celebrate streak
//  milestones. Pieces are generated from a fixed seed so a given burst always
//  looks the same (deterministic-ish), driven by `TimelineView(.animation)`.
//  Fully Reduce-Motion aware: when motion is reduced it shows a calm, static
//  scatter instead of a falling animation.
//

import SwiftUI

/// An overlay confetti burst. Drop it on top of a celebratory view and flip
/// `isActive` to `true` to fire it; it fades itself out after `duration`.
///
/// ```swift
/// .overlay {
///     ConfettiCanvas(isActive: $celebrate, colors: MedicineColor.allCases.map(\.color))
///         .allowsHitTesting(false)
/// }
/// ```
public struct ConfettiCanvas: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding private var isActive: Bool
    private let pieceCount: Int
    private let duration: TimeInterval
    private let colors: [Color]
    private let seed: UInt64

    @State private var startDate: Date?

    /// - Parameters:
    ///   - isActive: Binding that fires the burst when set to `true`. The view
    ///     resets it to `false` once the animation completes.
    ///   - pieceCount: Number of confetti pieces. Defaults to `60`.
    ///   - duration: Visible lifetime of the burst in seconds. Defaults to `2.2`.
    ///   - colors: Palette to draw from. Defaults to the full medicine palette.
    ///   - seed: Deterministic seed so a burst is reproducible. Defaults to `42`.
    public init(isActive: Binding<Bool>,
                pieceCount: Int = 60,
                duration: TimeInterval = 2.2,
                colors: [Color] = MedicineColor.allCases.map(\.color),
                seed: UInt64 = 42) {
        self._isActive = isActive
        self.pieceCount = max(1, pieceCount)
        self.duration = duration
        self.colors = colors.isEmpty ? [.accentColor] : colors
        self.seed = seed
    }

    public var body: some View {
        GeometryReader { proxy in
            content(in: proxy.size)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: isActive) { _, active in
            guard active else { return }
            if reduceMotion {
                // Honor Reduce Motion: render a brief static scatter, no falling.
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(min(duration, 1.2)))
                    isActive = false
                }
            } else {
                startDate = Date()
            }
        }
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if reduceMotion {
            if isActive {
                Canvas { context, canvasSize in
                    drawStatic(in: &context, size: canvasSize)
                }
                .transition(.opacity)
            }
        } else if let startDate {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { timeline in
                let elapsed = timeline.date.timeIntervalSince(startDate)
                Canvas { context, canvasSize in
                    drawFalling(in: &context, size: canvasSize, elapsed: elapsed)
                }
                .opacity(opacity(for: elapsed))
                .onChange(of: elapsed >= duration) { _, finished in
                    if finished { reset() }
                }
            }
        }
    }

    private func reset() {
        startDate = nil
        isActive = false
    }

    private func opacity(for elapsed: TimeInterval) -> Double {
        let fadeStart = duration * 0.7
        guard elapsed > fadeStart else { return 1 }
        let t = (elapsed - fadeStart) / (duration - fadeStart)
        return max(0, 1 - t)
    }

    // MARK: - Drawing

    private func drawFalling(in context: inout GraphicsContext, size: CGSize, elapsed: TimeInterval) {
        let progress = min(1, elapsed / duration)
        for index in 0..<pieceCount {
            let piece = piece(index: index, size: size)
            let fall = piece.fallDistance * easeOut(progress)
            let sway = sin((elapsed * piece.swaySpeed) + piece.phase) * piece.swayAmplitude
            let y = piece.origin.y + fall
            let x = piece.origin.x + sway
            let angle = piece.spin * elapsed
            draw(piece: piece, at: CGPoint(x: x, y: y), angle: angle, in: &context)
        }
    }

    private func drawStatic(in context: inout GraphicsContext, size: CGSize) {
        for index in 0..<pieceCount {
            let piece = piece(index: index, size: size)
            // Scatter calmly around the upper area, no motion.
            let point = CGPoint(x: piece.origin.x,
                                y: piece.origin.y + piece.fallDistance * 0.18)
            draw(piece: piece, at: point, angle: piece.phase, in: &context)
        }
    }

    private func draw(piece: Piece, at point: CGPoint, angle: Double, in context: inout GraphicsContext) {
        var layer = context
        layer.translateBy(x: point.x, y: point.y)
        layer.rotate(by: .radians(angle))
        let rect = CGRect(x: -piece.size.width / 2,
                          y: -piece.size.height / 2,
                          width: piece.size.width,
                          height: piece.size.height)
        let path = piece.isCircle
            ? Path(ellipseIn: rect)
            : Path(roundedRect: rect, cornerRadius: 1.5)
        layer.fill(path, with: .color(piece.color))
    }

    private func easeOut(_ t: Double) -> Double { 1 - pow(1 - t, 2) }

    // MARK: - Deterministic piece generation

    private struct Piece {
        let origin: CGPoint
        let size: CGSize
        let color: Color
        let fallDistance: CGFloat
        let swayAmplitude: CGFloat
        let swaySpeed: Double
        let spin: Double
        let phase: Double
        let isCircle: Bool
    }

    /// Build a piece deterministically from `seed` + `index`, so a given burst
    /// always renders identically across launches.
    private func piece(index: Int, size: CGSize) -> Piece {
        var rng = SplitMix64(seed: seed &+ UInt64(index) &* 0x9E3779B97F4A7C15)
        let width = max(size.width, 1)
        let height = max(size.height, 1)

        let originX = rng.nextDouble() * width
        let originY = -rng.nextDouble() * height * 0.25      // start just above the top edge
        let pieceW = 5 + rng.nextDouble() * 7
        let pieceH = 7 + rng.nextDouble() * 9
        let color = colors[Int(rng.next() % UInt64(colors.count))]
        let fall = height * (0.9 + rng.nextDouble() * 0.6)
        let swayAmp = 12 + rng.nextDouble() * 26
        let swaySpeed = 2 + rng.nextDouble() * 3
        let spin = (rng.nextDouble() * 2 - 1) * 6
        let phase = rng.nextDouble() * 2 * .pi
        let isCircle = rng.nextDouble() < 0.35

        return Piece(origin: CGPoint(x: originX, y: originY),
                     size: CGSize(width: pieceW, height: pieceH),
                     color: color,
                     fallDistance: fall,
                     swayAmplitude: swayAmp,
                     swaySpeed: swaySpeed,
                     spin: spin,
                     phase: phase,
                     isCircle: isCircle)
    }
}

/// Tiny deterministic PRNG (SplitMix64) so confetti is reproducible without
/// pulling in Foundation randomness. Kept private to this file.
private struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Uniform Double in `[0, 1)`.
    mutating func nextDouble() -> Double {
        Double(next() >> 11) * (1.0 / 9007199254740992.0)
    }
}

#if DEBUG
private struct ConfettiPreviewHost: View {
    @State private var fire = false
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: Spacing.lg) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.orange)
                Text("7 day streak!")
                    .font(AppFont.title)
                Button("Celebrate") { fire = true }
                    .buttonStyle(.borderedProminent)
            }
        }
        .overlay {
            ConfettiCanvas(isActive: $fire)
        }
    }
}

#Preview("Confetti") {
    ConfettiPreviewHost()
}
#endif
