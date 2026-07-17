//
//  Theme.swift
//  SpaghettiTimer
//
//  Design tokens for the "Classic" timer home screen.
//  Values mirror the high-fidelity design handoff exactly.
//

import SwiftUI

enum Theme {
    // Colors
    static let accent = Color(red: 10 / 255, green: 132 / 255, blue: 255 / 255)      // #0A84FF
    static let screenBG = Color.black                                                 // #000000
    static let bannerFill = Color(red: 2 / 255, green: 21 / 255, blue: 41 / 255)      // #021529
    static let cardFill = Color.white.opacity(0.02)
    static let cardBorder = Color(red: 45 / 255, green: 150 / 255, blue: 255 / 255).opacity(0.30) // #2D96FF @ 30%
    static let mutedTime = Color(red: 138 / 255, green: 138 / 255, blue: 142 / 255)   // #8A8A8E
    static let addDash = Color.white.opacity(0.28)
    static let addPlus = Color.white.opacity(0.45)

    // New Timer sheet — precomputed color-mix(in srgb, …) blends over black
    static let surfaceFill = Color.white.opacity(0.02)                                // rgba(255,255,255,.02)
    static let surfaceBorder = Color(red: 0.230, green: 0.614, blue: 1.0).opacity(0.275)   // mix(accent 22%, white .07)
    static let nameFieldBorder = Color(red: 0.217, green: 0.607, blue: 1.0).opacity(0.319) // mix(accent 26%, white .08)
    static let bandFill = accent.opacity(0.22)                                        // mix(accent 22%, transparent)
    static let bandBorder = accent.opacity(0.30)                                      // mix(accent 30%, transparent)
    static let unitTint = Color(red: 0.327, green: 0.662, blue: 1.0)                  // mix(accent 70%, #fff)
    static let cooldownReadout = Color(red: 0.251, green: 0.624, blue: 1.0)           // mix(accent 78%, #fff)
    static let disabledText = Color(red: 0.420, green: 0.420, blue: 0.439)            // #6B6B70
    static let lightText = Color(red: 0.847, green: 0.847, blue: 0.863)               // #D8D8DC
    static let subtleFill = Color.white.opacity(0.07)                                 // rgba(255,255,255,.07)
    static let disabledFill = Color(red: 0.165, green: 0.165, blue: 0.176)            // #2A2A2D
    static let hairline = Color.white.opacity(0.09)                                   // rgba(255,255,255,.09)

    // New Timer sheet — "End time" mode (segmented control + readout)
    static let segTrackFill = Color.white.opacity(0.03)                               // rgba(255,255,255,.03)
    static let segTrackBorder = Color(red: 0.827, green: 0.913, blue: 1.0).opacity(0.237) // mix(accent 18%, white .07)
    static let segSelectedFill = Color(red: 72 / 255, green: 72 / 255, blue: 74 / 255)    // #48484A
    static let dayTodayBG = accent.opacity(0.20)                                      // mix(accent 20%, transparent)
    static let dayTodayText = Color(red: 0.308, green: 0.653, blue: 1.0)              // mix(accent 72%, #fff)
    static let dayTomorrowBG = Color.white.opacity(0.08)                              // rgba(255,255,255,.08)
    static let durMutedText = Color(red: 0.78, green: 0.78, blue: 0.80)               // #C7C7CC

    // First-run tutorial (coach marks)
    static let tourScrim = Color.black.opacity(0.72)                                  // rgba(0,0,0,.72)
    static let tourCardBG = Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)     // #1C1C1E
    static let tourCardBorder = Color(red: 0.142, green: 0.569, blue: 1.0).opacity(0.448) // mix(accent 40%, white .08)
    static let tourBody = Color(red: 185 / 255, green: 185 / 255, blue: 192 / 255)    // #B9B9C0
    static let tourEyebrow = Color(red: 0.279, green: 0.638, blue: 1.0)               // mix(accent 75%, #fff)
    static let tourBackFill = Color.white.opacity(0.10)                               // rgba(255,255,255,.10)
    static let tourLightText = Color(red: 233 / 255, green: 233 / 255, blue: 238 / 255) // #E9E9EE
    static let tourDot = Color.white.opacity(0.22)                                    // rgba(255,255,255,.22)
    static let toastBG = Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255).opacity(0.92) // rgba(28,28,30,.92)
    static let toastBorder = Color.white.opacity(0.12)                                // rgba(255,255,255,.12)
    static let success = Color(red: 48 / 255, green: 209 / 255, blue: 88 / 255)       // #30D158

    // First-launch splash (seven-segment 3·2·1 countdown, styled like the icon)
    static let splashCaption = Color(red: 154 / 255, green: 154 / 255, blue: 163 / 255) // #9A9AA3
    static let segUnlit = Color(red: 0.00884, green: 0.09946, blue: 0.19392)          // mix(accent 14%, #010810)

    // Metrics
    static let cornerRadius: CGFloat = 22
    static let gridGap: CGFloat = 16
    static let screenPadding: CGFloat = 20
    static let stackGap: CGFloat = 18
    static let cardAspectRatio: CGFloat = 1.16
}
