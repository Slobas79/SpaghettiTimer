//
//  SpokenTimerTests.swift
//  SpaghettiTimerTests
//

import Foundation
import Testing
@testable import SpaghettiTimer

/// What VoiceOver says has to match what the screen shows. The views that speak
/// these strings cannot be asserted on, so the wording is frozen here instead.
@Suite("Spoken timer · VoiceOver wording")
struct SpokenTimerTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// Seconds in an on-screen readout — "05:00" or "1:00:00".
    private func shownSeconds(_ readout: String) -> TimeInterval {
        TimeInterval(readout.split(separator: ":").reduce(0) { $0 * 60 + Int($1)! })
    }

    @Test("VoiceOver says the same second as the digits beside it",
          arguments: [0.2, 0.5, 1, 59.4, 59.6, 299.4, 299.6, 3599.5, 3600.2])
    func spokenMatchesShown(seconds: TimeInterval) {
        let shown = shownSeconds(TimerFormatting.format(seconds))
        #expect(SpokenTimer.duration(seconds) == SpokenTimer.duration(shown))
    }

    @Test("Negative and non-finite durations read as zero instead of trapping")
    func garbageReadsAsZero() {
        let zero = SpokenTimer.duration(0)
        #expect(SpokenTimer.duration(-5) == zero)
        #expect(SpokenTimer.duration(.nan) == zero)
        #expect(SpokenTimer.duration(.infinity) == zero)
    }

    @Test("An unnamed timer is announced as \"Timer\", not by its value alone")
    func unnamedTimerHasALabel() {
        let fallback = String(localized: "Timer")
        #expect(SpokenTimer.label(for: "") == fallback)
        #expect(SpokenTimer.label(for: "  \n") == fallback)
        #expect(SpokenTimer.label(for: "Pasta") == "Pasta")
    }

    // MARK: Running row

    private func timer(startedAgo: TimeInterval, duration: TimeInterval = 300,
                       pausedAgo: TimeInterval? = nil, repeats: Bool = false) -> RunningTimer {
        RunningTimer(
            id: UUID(), presetID: UUID(), name: "Pasta",
            startDate: now.addingTimeInterval(-startedAgo),
            duration: duration,
            pausedAt: pausedAgo.map { now.addingTimeInterval(-$0) },
            autoRestartDelaySeconds: repeats ? 10 : nil
        )
    }

    @Test("A running row says how long is left")
    func runningRowSaysRemaining() {
        let value = SpokenTimer.rowValue(timer(startedAgo: 60), at: now)
        #expect(value == String(localized: "\(SpokenTimer.duration(240)) remaining"))
    }

    @Test("A paused row says so, with the time left when it was paused")
    func pausedRowSaysPaused() {
        // Paused 40 s ago, 100 s into a 300 s timer: 240 s were left, and still are.
        let value = SpokenTimer.rowValue(timer(startedAgo: 100, pausedAgo: 40), at: now)
        #expect(value == String(localized: "Paused, \(SpokenTimer.duration(240)) remaining"))
    }

    @Test("A repeat in its restart gap says when it starts again")
    func restartGapSaysStartsIn() {
        let value = SpokenTimer.rowValue(timer(startedAgo: -10, repeats: true), at: now)
        #expect(value.hasPrefix(String(localized: "Starts in \(SpokenTimer.duration(10))")))
    }

    @Test("A running auto-restart timer says \"Repeats\", as its tile does")
    func repeatingRowSaysRepeats() {
        let oneShot = SpokenTimer.rowValue(timer(startedAgo: 60), at: now)
        let repeating = SpokenTimer.rowValue(timer(startedAgo: 60, repeats: true), at: now)
        #expect(repeating == oneShot + ", " + String(localized: "Repeats"))
        #expect(!oneShot.contains(String(localized: "Repeats")))
    }

    // MARK: Tiles

    @Test("A tile reads its duration, then running and repeating state, in that order")
    func tileValueOrder() {
        let oneShot = TimerPreset(name: "Pasta", duration: 480)
        let repeating = TimerPreset(name: "Rest", duration: 90, autoRestartDelaySeconds: 10)
        #expect(SpokenTimer.tileValue(oneShot) == SpokenTimer.duration(480))
        #expect(SpokenTimer.tileValue(repeating, isRunning: true)
                == [SpokenTimer.duration(90), String(localized: "Running"), String(localized: "Repeats")]
                    .joined(separator: ", "))
    }

    @Test("The To-next-hour tile reads both of its on-screen strings")
    func nextHourValue() {
        #expect(SpokenTimer.nextHourValue(label: "Until 7 PM", minutes: 21)
                == "Until 7 PM, " + SpokenTimer.duration(21 * 60))
    }
}
