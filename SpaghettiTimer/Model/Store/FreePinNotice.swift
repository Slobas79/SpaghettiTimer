//
//  FreePinNotice.swift
//  SpaghettiTimer
//
//  What a free user is told about the free pin allowance. A pin is spent when
//  a timer is pinned, and unpinning never hands it back — so the New Timer
//  sheet says what pinning costs, and Home confirms before an unpin.
//

import Foundation

nonisolated enum FreePinNotice: Equatable {
    /// Pinning spends a free pin and leaves `leftAfter` of them.
    case spends(leftAfter: Int)
    /// Pinning spends the last free pin.
    case spendsLast
    /// No free pins left, so pinning needs Pro.
    case usedUp

    /// `nil` for Pro: there is no allowance to talk about, and unpinning costs
    /// nothing, so Home unpins without asking.
    /// - Parameter lifetimePinCount: user presets ever pinned, not the tiles on
    ///   the grid — unpinning doesn't lower it.
    static func current(isPro: Bool, lifetimePinCount: Int) -> FreePinNotice? {
        guard !isPro else { return nil }
        let left = ProConfig.freePinLimit - lifetimePinCount
        switch left {
        case ...0: return .usedUp
        case 1: return .spendsLast
        default: return .spends(leftAfter: left - 1)
        }
    }
}
