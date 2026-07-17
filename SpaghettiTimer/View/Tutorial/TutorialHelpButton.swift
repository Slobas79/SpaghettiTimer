//
//  TutorialHelpButton.swift
//  SpaghettiTimer
//
//  The Help (?) trigger from the tutorial design handoff: a round button
//  that starts a screen's coach-mark tour on demand. Two styles — the
//  44pt accent-tinted floating button at the bottom of the Home grid, and
//  the 34pt nav-bar button next to Start on the New Timer sheet.
//

import SwiftUI

struct TutorialHelpButton: View {
    enum Style {
        /// Home: 44pt, accent-tinted dark fill, accent ring, drop shadow.
        case bottom
        /// New Timer nav bar: 34pt, plain white 8% fill.
        case nav
    }

    let style: Style
    let action: () -> Void

    private var diameter: CGFloat { style == .bottom ? 44 : 34 }

    var body: some View {
        Button(action: action) {
            Image(systemName: "questionmark")
                .font(.system(size: style == .bottom ? 17 : 14, weight: .semibold))
                .foregroundStyle(Theme.tourHelpGlyph)
                .frame(width: diameter, height: diameter)
                .background(
                    Circle().fill(style == .bottom ? Theme.tourHelpBG : Theme.tourHelpNavBG)
                )
                .overlay {
                    if style == .bottom {
                        Circle().strokeBorder(Theme.tourHelpRing, lineWidth: 1)
                    }
                }
                .shadow(color: style == .bottom ? .black.opacity(0.45) : .clear,
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
            TutorialHelpButton(style: .bottom) {}
            TutorialHelpButton(style: .nav) {}
        }
    }
}
