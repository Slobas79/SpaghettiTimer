//
//  TutorialDynamicIslandArt.swift
//  SpaghettiTimer
//
//  Static preview of the *expanded* Dynamic Island, rendered inside the
//  "Live on the Dynamic Island" artwork tip of the first-run tour. The real
//  presentation (`TimerLiveActivity`'s `DynamicIslandExpandedRegion`s) lives
//  only in the widget extension target, so this is a faithful, non-interactive
//  stand-in built from the same measurements.
//

import SwiftUI

/// The expanded island mid-countdown: title, depleting ring with the app mark,
/// big countdown, pause and dismiss buttons. No timeline, no live countdown,
/// no buttons — purely decorative artwork for the tour.
struct TutorialDynamicIslandArt: View {
    /// Authored size, matching the expanded island on a Pro-sized iPhone.
    static let designWidth: CGFloat = 372
    static let designHeight: CGFloat = 156

    /// The island's own corner radius when expanded.
    private static let cornerRadius: CGFloat = 44
    /// The real island is pure black; on the tour card's #1C1C1E surface it
    /// would vanish, so it carries the accent keyline (`keylineTint`) as a
    /// visible edge.
    private static let keyline = Theme.accent.opacity(0.35)

    /// Sizes mirrored from `TimerLiveActivity`'s expanded regions.
    private static let ringDiameter: CGFloat = 66
    private static let ringStroke: CGFloat = 6
    private static let glyphPointSize: CGFloat = 24
    private static let buttonSize: CGFloat = 52

    /// Mid-run state of the same sample timer the running-banner tip shows.
    private static let title = "5 min"
    private static let countdown = "4:12"
    private static let remainingFraction: CGFloat = 0.84

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Self.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 8)

            HStack(spacing: 14) {
                ring
                Text(Self.countdown)
                    .font(.system(size: 44, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 8)
                circleButton(systemName: "pause.fill", filled: true)
                circleButton(systemName: "xmark", filled: false)
            }
        }
        .padding(.horizontal, 19)
        .padding(.top, 30)
        .padding(.bottom, 16)
        .frame(width: Self.designWidth, height: Self.designHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .fill(.black)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .strokeBorder(Self.keyline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .environment(\.colorScheme, .dark)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Accent progress ring with the app mark at its center. The live ring is
    /// system-driven; here it's frozen at a plausible mid-run fraction.
    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.16), lineWidth: Self.ringStroke)
            Circle()
                .trim(from: 0, to: Self.remainingFraction)
                .stroke(Theme.accent,
                        style: StrokeStyle(lineWidth: Self.ringStroke, lineCap: .round))
                .rotationEffect(.degrees(-90))
            SevenSegMark(height: Self.glyphPointSize * 1.22)
        }
        .frame(width: Self.ringDiameter, height: Self.ringDiameter)
    }

    private func circleButton(systemName: String, filled: Bool) -> some View {
        Circle()
            .fill(filled ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.white.opacity(0.14)))
            .frame(width: Self.buttonSize, height: Self.buttonSize)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: Self.buttonSize * 0.4, weight: .bold))
                    .foregroundStyle(.white)
            )
    }
}

// MARK: - Brand mark

/// The app mark — the seven-segment "5" from the app icon — drawn from shapes,
/// mirroring `SevenSegMark` in `TimerLiveActivity` (that type is compiled only
/// into the widget target). Authored in the icon's 300×480 space.
private struct SevenSegMark: View {
    /// The icon's glyph lights A · F · G · C · D — a seven-segment `5`.
    private static let bars: [(lit: Bool, rect: CGRect)] = [
        (true,  CGRect(x: 24,  y: 0,   width: 252, height: 62)),   // A
        (true,  CGRect(x: 0,   y: 78,  width: 58,  height: 126)),  // F
        (false, CGRect(x: 242, y: 78,  width: 58,  height: 126)),  // B
        (true,  CGRect(x: 24,  y: 209, width: 252, height: 62)),   // G
        (false, CGRect(x: 0,   y: 276, width: 58,  height: 126)),  // E
        (true,  CGRect(x: 242, y: 276, width: 58,  height: 126)),  // C
        (true,  CGRect(x: 24,  y: 418, width: 252, height: 62))    // D
    ]

    /// Rendered height in points; width follows the icon's 300:480 aspect.
    let height: CGFloat

    var body: some View {
        let s = height / 480   // icon space → points
        Canvas { ctx, _ in
            for bar in Self.bars {
                let scaled = CGRect(x: bar.rect.minX * s, y: bar.rect.minY * s,
                                    width: bar.rect.width * s, height: bar.rect.height * s)
                let path = Path(roundedRect: scaled, cornerRadius: 18 * s, style: .continuous)
                ctx.fill(path, with: .color(bar.lit ? Theme.accent : Theme.segUnlit))
            }
        }
        .frame(width: 300 * s, height: height)
        .accessibilityHidden(true)
    }
}

#Preview {
    ZStack {
        Theme.tourCardBG
        TutorialDynamicIslandArt()
    }
    .ignoresSafeArea()
}
