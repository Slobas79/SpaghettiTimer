//
//  TutorialHelpButton.swift
//  SpaghettiTimer
//
//  The Help (?) trigger from the tutorial design handoff: a round button
//  that starts a screen's coach-mark tour on demand. Three styles — the
//  38pt accent-tinted button in the Home screen's bottom-right corner, and
//  the 34pt nav-bar button next to Start on the New Timer sheet.
//

import SwiftUI

struct TutorialHelpButton: View {
    enum Style {
        /// Home bottom-right corner: 38pt, accent-tinted dark fill, accent
        /// ring, drop shadow. Sits clear of the running banner (top) and the
        /// centre + FAB (bottom-centre).
        case corner
        /// New Timer nav bar: 34pt, plain white 8% fill.
        case nav
    }

    let style: Style
    let action: () -> Void

    private var diameter: CGFloat { style == .corner ? 38 : 34 }

    var body: some View {
        Button(action: action) {
            Image(systemName: "questionmark")
                .font(.system(size: style == .corner ? 15 : 14, weight: .semibold))
                .foregroundStyle(Theme.tourHelpGlyph)
                .frame(width: diameter, height: diameter)
                .background(
                    Circle().fill(style == .corner ? Theme.tourHelpBG : Theme.tourHelpNavBG)
                )
                .overlay {
                    if style == .corner {
                        Circle().strokeBorder(Theme.tourHelpRing, lineWidth: 1)
                    }
                }
                .shadow(color: style == .corner ? .black.opacity(0.45) : .clear,
                        radius: 12, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show tips")
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        HStack(spacing: 30) {
            TutorialHelpButton(style: .corner) {}
            TutorialHelpButton(style: .nav) {}
        }
    }
}
