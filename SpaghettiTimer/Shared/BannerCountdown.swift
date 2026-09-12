//
//  BannerCountdown.swift
//  SpaghettiTimer
//
//  Sizing and formatting for the Live Activity banner's countdown.
//
//  This lives here, apart from the view, because the sizing rule is the load-
//  bearing part of that layout and the view itself cannot be asserted on.
//
//  The banner shows the countdown next to the timer's name, and the countdown is
//  the element that must always be fully visible. It is a `Text(timerInterval:)`,
//  which has no content-derived width: offered space it takes all of it, starving
//  the name, and asked for its ideal width it reports one that overflows the
//  banner. Neither is a size to lay out against. So the view sizes a hidden,
//  static `Text(sample(remaining:))` instead — a string the layout system can
//  measure — and overlays the live countdown on it.
//
//  That makes `sample` a width promise, and this is the invariant it owes:
//  the sample is never narrower than the value being rendered inside it.
//

import Foundation

nonisolated enum BannerCountdown {
    /// The rendered countdown for a paused timer, which shows a frozen value
    /// rather than a live one.
    static func text(remaining seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "0:00" }
        // Cap well below Int range (~273 years) so the Int() conversion can never trap.
        let total = Int(min(max(0, seconds.rounded()), 8.64e9))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }

    /// The widest string the countdown can show while `remaining` seconds are
    /// left — the hidden sample that reserves the banner's countdown width.
    ///
    /// Digits are monospaced, so a sample with as many digits as the value is
    /// exactly as wide as it. Remaining time only ever shrinks, so a sample
    /// chosen when the view is built still fits every second the system draws
    /// before the next update — a timer crossing the hour boundary keeps the
    /// wider reservation until then, which shows as a gap, never a clipped digit.
    ///
    /// `nil` is the idle state, whose "--:--" placeholder is shorter than the
    /// minute-format sample.
    static func sample(remaining: TimeInterval?) -> String {
        guard let remaining, remaining >= 3600 else { return "59:59" }
        return remaining < 36000 ? "9:59:59" : "99:59:59"
    }
}
