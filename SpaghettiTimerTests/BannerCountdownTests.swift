//
//  BannerCountdownTests.swift
//  SpaghettiTimerTests
//

import Foundation
import Testing
@testable import SpaghettiTimer

/// The banner countdown must never be clipped — the name is the element that
/// gives way. The layout that delivers that cannot be asserted on, but it rests
/// entirely on `BannerCountdown.sample` reserving enough width, so that promise
/// is what these freeze.
@Suite("Banner countdown · width promise")
struct BannerCountdownWidthTests {
    /// Digits are monospaced and every glyph in these strings is a digit or a
    /// colon, so "fits" is exactly: at least as many of each.
    private func fits(_ value: String, in sample: String) -> Bool {
        func digits(_ s: String) -> Int { s.count { $0.isNumber } }
        func colons(_ s: String) -> Int { s.count { $0 == ":" } }
        return digits(value) <= digits(sample) && colons(value) <= colons(sample)
    }

    /// Every duration a timer can plausibly hold, plus both format boundaries
    /// from either side.
    nonisolated private static let durations: [TimeInterval] = [
        0, 1, 30, 59, 60, 61, 299, 300, 599, 600, 3540, 3599,
        3600, 3601, 5400, 3900, 35999, 36000, 36001, 86_399, 86_400, 359_999
    ]

    @Test("The sample is never narrower than the value rendered inside it",
          arguments: durations)
    func sampleFitsItsOwnValue(seconds: TimeInterval) {
        let sample = BannerCountdown.sample(remaining: seconds)
        #expect(fits(BannerCountdown.text(remaining: seconds), in: sample),
                "\(BannerCountdown.text(remaining: seconds)) does not fit \(sample)")
    }

    /// The sample is chosen once when the view is built, but the countdown keeps
    /// ticking inside it until the next update. Remaining time only shrinks, so
    /// the reservation has to cover every smaller value too.
    @Test("A sample still fits every later second of the same render",
          arguments: durations)
    func sampleFitsEverySmallerValue(seconds: TimeInterval) {
        let sample = BannerCountdown.sample(remaining: seconds)
        for later in [seconds, seconds * 0.75, seconds / 2, 3599, 60, 1, 0] where later <= seconds {
            #expect(fits(BannerCountdown.text(remaining: later), in: sample),
                    "\(BannerCountdown.text(remaining: later)) does not fit \(sample) chosen at \(seconds)s")
        }
    }

    @Test("The format boundaries are where the reservation widens")
    func boundariesAreFrozen() {
        #expect(BannerCountdown.sample(remaining: 3599) == "59:59")
        #expect(BannerCountdown.sample(remaining: 3600) == "9:59:59")
        #expect(BannerCountdown.sample(remaining: 35999) == "9:59:59")
        #expect(BannerCountdown.sample(remaining: 36000) == "99:59:59")
    }

    /// The alerting and idle states show "Done" and "--:--", both shorter than
    /// the minute-format sample, so they reserve it and nothing wider.
    @Test("The stateless case reserves the minute format")
    func noRemainingTimeReservesMinuteFormat() {
        #expect(BannerCountdown.sample(remaining: nil) == "59:59")
    }

    /// A sample must be reserved even for a value that cannot be rendered,
    /// rather than the guard collapsing to an empty width.
    @Test("Degenerate remaining times still reserve a width")
    func degenerateValuesStillReserve() {
        #expect(BannerCountdown.sample(remaining: -1) == "59:59")
        #expect(BannerCountdown.sample(remaining: .nan) == "59:59")
        #expect(BannerCountdown.sample(remaining: .infinity) == "99:59:59")
    }
}

@Suite("Banner countdown · paused text")
struct BannerCountdownTextTests {
    @Test("Minutes drop the hour field, hours pad the minutes")
    func formatIsFrozen() {
        #expect(BannerCountdown.text(remaining: 0) == "0:00")
        #expect(BannerCountdown.text(remaining: 59) == "0:59")
        #expect(BannerCountdown.text(remaining: 300) == "5:00")
        #expect(BannerCountdown.text(remaining: 3599) == "59:59")
        #expect(BannerCountdown.text(remaining: 3600) == "1:00:00")
        #expect(BannerCountdown.text(remaining: 3900) == "1:05:00")
        #expect(BannerCountdown.text(remaining: 36000) == "10:00:00")
    }

    /// The view hands this raw arithmetic on AlarmKit's durations, which can go
    /// negative or non-finite; it must round-trip to a drawable string rather
    /// than trapping the widget process.
    @Test("Out-of-range values render as zero instead of trapping")
    func outOfRangeValuesAreClamped() {
        #expect(BannerCountdown.text(remaining: -30) == "0:00")
        #expect(BannerCountdown.text(remaining: .nan) == "0:00")
        #expect(BannerCountdown.text(remaining: .infinity) == "0:00")
        #expect(BannerCountdown.text(remaining: 1e30) == "2400000:00:00")
    }
}

/// The live countdown is formatted by the system in `clockLocale`. Some
/// languages' own separator is a dot (sr, fi, da give "2.05"), so the pinned
/// locale must produce a colon — the same M:SS the paused text draws.
@Suite("Banner countdown · clock locale")
struct BannerCountdownLocaleTests {
    @Test("The pinned locale separates minutes and seconds with a colon")
    func pinnedLocaleUsesColon() {
        let format = Duration.TimeFormatStyle(pattern: .minuteSecond).locale(BannerCountdown.clockLocale)
        #expect(Duration.seconds(125).formatted(format) == "2:05")
        #expect(Duration.seconds(125).formatted(format) == BannerCountdown.text(remaining: 125))
    }
}
