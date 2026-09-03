//
//  TutorialWidgetArt.swift
//  SpaghettiTimer
//
//  Static preview of the medium home-screen widget, rendered inside the
//  "Add the widget" artwork tip of the first-run tour. The real widget view
//  (`PresetsWidgetView`) lives only in the widget extension target, so this is
//  a faithful, non-interactive stand-in that reuses the shipped widget's
//  "outlined" tile language with the app accent (`Theme.accent`).
//

import SwiftUI

/// A 2×2 quick-start tile grid matching the medium `PresetsWidget`. No timeline,
/// no live countdown, no buttons — purely decorative artwork for the tour.
struct TutorialWidgetArt: View {
    /// One quick-start tile: a named one-shot, or an unnamed repeating interval
    /// whose loop glyph stands in for its identity.
    private struct Tile: Identifiable {
        let id = UUID()
        var name: String = ""
        var time: String = ""
        var isRepeat = false
    }

    // Mirrors the shipped default widget: the four built-in one-shot presets
    // (`TimerPreset.builtIns`) a fresh install shows on the Home Screen.
    private let tiles: [Tile] = [
        Tile(name: "Al Dente", time: "08:00"),
        Tile(name: "Rest Set", time: "01:30"),
        Tile(name: "Pomodoro", time: "25:00"),
        Tile(name: "Power Nap", time: "20:00")
    ]

    // Widget styling mirrored from `PresetsWidget.swift`'s `WidgetStyle`
    // (that type isn't compiled into the app target). Outlined tiles.
    private static let muted = Color(red: 138 / 255, green: 147 / 255, blue: 163 / 255)
    private static let tileFill = Color.white.opacity(0.02)
    private static let tileBorder = Color(red: 56 / 255, green: 160 / 255, blue: 255 / 255).opacity(0.32)
    private static let tileRadius: CGFloat = 17
    private static let containerRadius: CGFloat = 26
    private static let containerGradient = LinearGradient(
        colors: [Color(red: 32 / 255, green: 36 / 255, blue: 44 / 255),
                 Color(red: 20 / 255, green: 23 / 255, blue: 29 / 255)],
        startPoint: .top, endPoint: .bottom)

    private static let gridGap: CGFloat = 10

    var body: some View {
        // Fixed 2×2 grid so tiles stretch to fill the widget's height, exactly
        // like `PresetsWidgetView` (a LazyVGrid would hug content and leave the
        // bottom half empty).
        VStack(spacing: Self.gridGap) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: Self.gridGap) {
                    ForEach(0..<2, id: \.self) { col in
                        tileView(tiles[row * 2 + col])
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(14)
        .frame(width: 364, height: 170)
        .background(
            RoundedRectangle(cornerRadius: Self.containerRadius, style: .continuous)
                .fill(Self.containerGradient)
        )
        .clipShape(RoundedRectangle(cornerRadius: Self.containerRadius, style: .continuous))
        .environment(\.colorScheme, .dark)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func tileView(_ tile: Tile) -> some View {
        let iconOnly = tile.isRepeat && tile.name.isEmpty
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                if tile.isRepeat {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: iconOnly ? 26 : 18, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                if !tile.name.isEmpty {
                    Text(tile.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }
            if !iconOnly {
                Text(tile.time)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Self.muted)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Self.tileRadius, style: .continuous)
                .fill(Self.tileFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Self.tileRadius, style: .continuous)
                .strokeBorder(Self.tileBorder, lineWidth: 1.5)
        )
    }
}

#Preview {
    ZStack {
        Color.black
        TutorialWidgetArt()
    }
    .ignoresSafeArea()
}
