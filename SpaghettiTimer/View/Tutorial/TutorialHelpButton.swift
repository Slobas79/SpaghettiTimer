//
//  TutorialHelpButton.swift
//  SpaghettiTimer
//
//  The Help (?) trigger from the tutorial design handoff: a round button
//  that starts a screen's coach-mark tour on demand. Two styles — the 38pt
//  accent-tinted puck in the Home screen's bottom-left corner (shared with
//  the ••• menu opposite it via `CornerChromeGlyph`), and the 34pt nav-bar
//  button next to Start on the New Timer sheet.
//

import SwiftUI

struct TutorialHelpButton: View {
    enum Style {
        /// Home bottom-left corner: the shared 38pt `CornerChromeGlyph` puck.
        /// Sits clear of the running banner (top) and the centre + FAB
        /// (bottom-centre), mirroring the ••• menu in the opposite corner.
        case corner
        /// New Timer nav bar: 34pt, plain white 8% fill.
        case nav
    }

    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            switch style {
            case .corner:
                CornerChromeGlyph(systemName: "questionmark")
            case .nav:
                Image(systemName: "questionmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.tourHelpGlyph)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.tourHelpNavBG))
            }
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
