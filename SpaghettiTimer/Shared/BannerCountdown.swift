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

import AlarmKit
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

// MARK: - Progress ring

/// The Live Activity progress ring's geometry, kept apart from the view for the
/// same reason as `BannerCountdown`: the running and paused rings must be
/// checkable against each other.
///
/// Both must measure the same thing — the share of the whole timer still left —
/// or the ring jumps when the state flips. AlarmKit's `startDate` is where the
/// current run segment began, which after a resume is the resume instant, not
/// the timer's start. Depleting across `startDate...fireDate` therefore drew
/// every resumed timer as a full ring.
nonisolated enum CountdownProgress {
    /// The interval a running ring depletes across: the whole timer, ending at
    /// `fireDate`. Anchored on `fireDate` rather than `startDate`, which moves on
    /// every resume, and always a valid range whatever AlarmKit reports.
    static func ringInterval(for countdown: AlarmPresentationState.Mode.Countdown) -> ClosedRange<Date> {
        countdown.fireDate.addingTimeInterval(-max(0, countdown.totalCountdownDuration))...countdown.fireDate
    }

    /// The share of the timer left while paused — what the running ring shows at
    /// the instant it resumes.
    static func pausedFraction(for paused: AlarmPresentationState.Mode.Paused) -> Double {
        guard paused.totalCountdownDuration > 0 else { return 0 }
        let remaining = paused.totalCountdownDuration - paused.previouslyElapsedDuration
        return max(0, min(1, remaining / paused.totalCountdownDuration))
    }
}
