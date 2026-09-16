//
//  CountdownProgressTests.swift
//  SpaghettiTimerTests
//
//  The Dynamic Island ring used to refill on every resume: AlarmKit moves
//  `startDate` to the resume instant, and the ring depleted across
//  `startDate...fireDate`. These pin the running ring to the paused one.
//

import AlarmKit
import Foundation
import Testing
@testable import SpaghettiTimer

@Suite("Countdown progress ring")
struct CountdownProgressTests {
    /// What `ProgressView(timerInterval:countsDown: true)` draws at `date`.
    private func drawnFraction(_ interval: ClosedRange<Date>, at date: Date) -> Double {
        let span = interval.upperBound.timeIntervalSince(interval.lowerBound)
        guard span > 0 else { return 0 }
        return max(0, min(1, interval.upperBound.timeIntervalSince(date) / span))
    }

    /// The state AlarmKit reports for a timer resumed at `resumedAt` after
    /// `elapsed` seconds had already run.
    private func resumed(total: TimeInterval, elapsed: TimeInterval, at resumedAt: Date)
        -> AlarmPresentationState.Mode.Countdown {
        .init(totalCountdownDuration: total,
              previouslyElapsedDuration: elapsed,
              startDate: resumedAt,
              fireDate: resumedAt.addingTimeInterval(total - elapsed))
    }

    @Test("A fresh timer depletes across its own start and end")
    func freshTimerSpansItsRun() {
        let countdown = resumed(total: 300, elapsed: 0, at: .t0)

        let interval = CountdownProgress.ringInterval(for: countdown)

        #expect(interval == Date.t0...Date.t0.addingTimeInterval(300))
        #expect(drawnFraction(interval, at: .t0) == 1)
    }

    @Test("Resuming continues from the paused ring instead of refilling it",
          arguments: [0.0, 1, 60, 150, 299])
    func resumeMatchesPausedRing(elapsed: TimeInterval) {
        let paused = AlarmPresentationState.Mode.Paused(totalCountdownDuration: 300,
                                                        previouslyElapsedDuration: elapsed)
        let resumeAt = Date.t0.addingTimeInterval(1_000)
        let countdown = resumed(total: 300, elapsed: elapsed, at: resumeAt)

        let atResume = drawnFraction(CountdownProgress.ringInterval(for: countdown), at: resumeAt)

        #expect(abs(atResume - CountdownProgress.pausedFraction(for: paused)) < 1e-9)
    }

    @Test("Repeated pause and resume keep draining the same ring")
    func repeatedResumesKeepDraining() {
        // 300 s timer: runs 60, paused, runs 90, paused, resumed — 150 s left.
        let resumeAt = Date.t0.addingTimeInterval(500)
        let countdown = resumed(total: 300, elapsed: 150, at: resumeAt)
        let interval = CountdownProgress.ringInterval(for: countdown)

        #expect(abs(drawnFraction(interval, at: resumeAt) - 0.5) < 1e-9)
        #expect(abs(drawnFraction(interval, at: resumeAt.addingTimeInterval(75)) - 0.25) < 1e-9)
        #expect(drawnFraction(interval, at: countdown.fireDate) == 0)
    }

    @Test("A degenerate duration still yields a valid, empty ring")
    func degenerateDurations() {
        let zero = resumed(total: 0, elapsed: 0, at: .t0)
        #expect(CountdownProgress.ringInterval(for: zero) == Date.t0...Date.t0)

        let negative = AlarmPresentationState.Mode.Countdown(totalCountdownDuration: -5,
                                                             previouslyElapsedDuration: 0,
                                                             startDate: .t0,
                                                             fireDate: .t0)
        #expect(CountdownProgress.ringInterval(for: negative) == Date.t0...Date.t0)

        #expect(CountdownProgress.pausedFraction(for: .init(totalCountdownDuration: 0,
                                                            previouslyElapsedDuration: 0)) == 0)
        #expect(CountdownProgress.pausedFraction(for: .init(totalCountdownDuration: 300,
                                                            previouslyElapsedDuration: 400)) == 0)
    }
}
