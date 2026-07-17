//
//  TutorialSplash.swift
//  SpaghettiTimer
//
//  First-launch splash: a big seven-segment digit counting 3 → 2 → 1, styled
//  exactly like the app icon, that plays before the first-run Home tour so the
//  coach marks don't appear out of nowhere. Reads as the app "booting up" in
//  its own brand language. Mirrors the "First-launch splash" design delta.
//

import SwiftUI

/// The full-screen intro splash. Fades in, ticks the digit 3 → 2 → 1 on a
/// 900ms cadence (each tick replays the pop), then fades out and hands off to
/// the Home tour via `onFinish`. "Skip intro" calls `onSkip`, which skips the
/// splash **and** the tour.
struct TutorialSplash: View {
    /// The countdown finished — start the Home tour.
    let onFinish: () -> Void
    /// The user tapped "Skip intro" — skip the splash and the tour.
    let onSkip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var count = 3
    @State private var showDigit = false   // gates the first pop-in
    @State private var bloom = false       // glow bloom on appear
    @State private var showCaption = false
    @State private var showSkip = false
    @State private var leaving = false

    /// Icon glyphs are authored in a 300×480 space; render at ~170pt wide.
    private static let digitScale: CGFloat = 170.0 / 300.0

    /// The springy pop: scale 0.82 → 1, ~0.55s, `cubic-bezier(.34,1.4,.45,1)`.
    /// Reduce Motion drops the overshoot for a plain opacity tick.
    private var pop: Animation {
        reduceMotion ? .easeInOut(duration: 0.2)
                     : .timingCurve(0.34, 1.4, 0.45, 1, duration: 0.55)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Large radial accent glow blooming behind the digit.
            RadialGradient(
                colors: [Theme.accent.opacity(0.18), .clear],
                center: .center, startRadius: 0, endRadius: 210
            )
            .frame(width: 420, height: 420)
            .scaleEffect(bloom ? 1 : 0.9)
            .opacity(bloom ? 1 : 0)
            .accessibilityHidden(true)

            VStack(spacing: 40) {
                ZStack {
                    if showDigit {
                        SevenSegDigit(digit: count)
                            .scaleEffect(Self.digitScale)
                            .frame(width: 170, height: 480 * Self.digitScale)
                            // Icon-style glow around the lit segments.
                            .shadow(color: Theme.accent.opacity(0.45), radius: 17)
                            .id(count)
                            .transition(reduceMotion
                                ? .opacity
                                : .scale(scale: 0.82).combined(with: .opacity))
                    }
                }
                .frame(width: 170, height: 480 * Self.digitScale)
                .animation(pop, value: count)
                .accessibilityHidden(true)

                Text("Getting you set up…")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.splashCaption)
                    .opacity(showCaption ? 1 : 0)
                    .offset(y: showCaption ? 0 : 8)
            }

            VStack {
                Spacer()
                Button {
                    guard !leaving else { return }
                    leave(then: onSkip)
                } label: {
                    Text("Skip intro")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.mutedTime)
                        .padding(12)
                }
                .buttonStyle(.plain)
                .opacity(showSkip ? 1 : 0)
                .padding(.bottom, 44)
            }
        }
        .opacity(leaving ? 0 : 1)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel("Getting you set up")
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { bloom = true }
            withAnimation(pop) { showDigit = true }
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) { showCaption = true }
            withAnimation(.easeOut(duration: 0.4).delay(0.8)) { showSkip = true }
        }
        .task { await runCountdown() }
    }

    /// Ticks the digit down every 900ms, then fades out 900ms after "1".
    private func runCountdown() async {
        while !leaving {
            try? await Task.sleep(for: .milliseconds(900))
            if Task.isCancelled || leaving { return }
            if count > 1 {
                count -= 1
            } else {
                leave(then: onFinish)
                return
            }
        }
    }

    /// Fades the whole splash out (~0.45s) and then hands off.
    private func leave(then completion: @escaping () -> Void) {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .easeIn(duration: 0.45)) {
            leaving = true
        }
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            completion()
        }
    }
}

// MARK: - Seven-segment digit

/// A single seven-segment glyph drawn from rounded bars on pure black, exactly
/// like the app icon: lit segments in the accent, unlit segments in a very dark
/// accent tint. Authored in a 300×480 coordinate space.
private struct SevenSegDigit: View {
    let digit: Int

    /// Which segments are lit per digit. A top · B top-right · C bottom-right ·
    /// D bottom · E bottom-left · F top-left · G middle.
    private static let segmentMap: [Int: Set<Character>] = [
        1: ["B", "C"],
        2: ["A", "B", "G", "E", "D"],
        3: ["A", "B", "G", "C", "D"]
    ]

    /// Each bar's rect in the 300×480 icon space, keyed by segment.
    private static let bars: [(Character, CGRect)] = [
        ("A", CGRect(x: 24,  y: 0,   width: 252, height: 62)),
        ("F", CGRect(x: 0,   y: 78,  width: 58,  height: 126)),
        ("B", CGRect(x: 242, y: 78,  width: 58,  height: 126)),
        ("G", CGRect(x: 24,  y: 209, width: 252, height: 62)),
        ("E", CGRect(x: 0,   y: 276, width: 58,  height: 126)),
        ("C", CGRect(x: 242, y: 276, width: 58,  height: 126)),
        ("D", CGRect(x: 24,  y: 418, width: 252, height: 62))
    ]

    var body: some View {
        let lit = Self.segmentMap[digit] ?? []
        Canvas { ctx, _ in
            for (segment, rect) in Self.bars {
                let bar = Path(roundedRect: rect, cornerRadius: 18, style: .continuous)
                ctx.fill(bar, with: .color(lit.contains(segment) ? Theme.accent : Theme.segUnlit))
            }
        }
        .frame(width: 300, height: 480)
    }
}

// MARK: - Preview

#Preview {
    TutorialSplash(onFinish: {}, onSkip: {})
}
