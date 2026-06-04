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

    // Metrics
    static let cornerRadius: CGFloat = 22
    static let gridGap: CGFloat = 16
    static let screenPadding: CGFloat = 20
    static let stackGap: CGFloat = 18
    static let cardAspectRatio: CGFloat = 1.16
}
