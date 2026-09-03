//
//  CornerChromeGlyph.swift
//  SpaghettiTimer
//
//  The 38pt circular puck shared by Home's two floating corner controls — the
//  one-shot Help (?) button bottom-left and the permanent ••• menu opposite
//  it. Factored out so the pair stays pixel-identical while both are on
//  screen during the first run, and so the tour's colour tokens live in one
//  place.
//

import SwiftUI

struct CornerChromeGlyph: View {
    let systemName: String
    /// Point size of the SF Symbol inside the puck.
    var pointSize: CGFloat = 15

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: pointSize, weight: .semibold))
            .foregroundStyle(Theme.tourHelpGlyph)
            .frame(width: 38, height: 38)
            .background(Circle().fill(Theme.tourHelpBG))
            .overlay {
                Circle().strokeBorder(Theme.tourHelpRing, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.45), radius: 12, y: 8)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        HStack(spacing: 30) {
            CornerChromeGlyph(systemName: "questionmark")
            CornerChromeGlyph(systemName: "ellipsis")
        }
    }
}
