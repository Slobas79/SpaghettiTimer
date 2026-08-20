//
//  RunningTimerLifecycleTests.swift
//  SpaghettiTimerTests
//
//  Guards the pause/resume copy helpers. Before commit 91cfd9d these transitions
//  were open-coded through the memberwise initializer at six call sites, and two
//  of them forgot `autoRestartDelaySeconds` — so pausing a repeating timer from
//  the Live Activity silently turned it into a one-shot.
//

import Foundation
import Testing
@testable import SpaghettiTimer

@Suite("RunningTimer lifecycle")
struct RunningTimerLifecycleTests {

    @Test("Pausing preserves the auto-restart delay")
    func pausePreservesAutoRestartDelay() {
        let timer = RunningTimer.fixture(autoRestartDelaySeconds: 5)
        #expect(timer.paused(at: .t0)?.autoRestartDelaySeconds == 5)
    }

    @Test("Resuming preserves the auto-restart delay")
    func resumePreservesAutoRestartDelay() {
        let paused = RunningTimer.fixture(pausedAt: .t0, autoRestartDelaySeconds: 5)
        let resumed = paused.resumed(at: Date.t0.addingTimeInterval(30))
        #expect(resumed?.autoRestartDelaySeconds == 5)
    }

    @Test("Pausing records the instant and changes nothing else")
    func pauseRecordsTheInstant() {
        let timer = RunningTimer.fixture(startDate: .t0, duration: 300)
        let paused = timer.paused(at: Date.t0.addingTimeInterval(60))
        #expect(paused?.pausedAt == Date.t0.addingTimeInterval(60))
        #expect(paused?.isPaused == true)
        #expect(paused?.startDate == timer.startDate)
        #expect(paused?.duration == timer.duration)
    }

    @Test("Resuming shifts startDate by the pause duration so remaining is unchanged")
    func resumeShiftsStartDateByPauseDuration() {
        // Paused 60s in with 240s left; resumed 90s later. The remaining time must
        // still be 240s, which means startDate moved forward by exactly 90s.
        let timer = RunningTimer.fixture(startDate: .t0, duration: 300)
        let pauseInstant = Date.t0.addingTimeInterval(60)
        let resumeInstant = pauseInstant.addingTimeInterval(90)

        let paused = try! #require(timer.paused(at: pauseInstant))
        #expect(paused.remaining(at: resumeInstant) == 240)

        let resumed = try! #require(paused.resumed(at: resumeInstant))
        #expect(resumed.startDate == Date.t0.addingTimeInterval(90))
        #expect(resumed.remaining(at: resumeInstant) == 240)
        #expect(resumed.isPaused == false)
    }

    @Test("Pausing an already-paused timer is refused")
    func pauseIsRefusedWhenAlreadyPaused() {
        let paused = RunningTimer.fixture(pausedAt: .t0)
        #expect(paused.paused(at: Date.t0.addingTimeInterval(10)) == nil)
    }

    @Test("Resuming a running timer is refused")
    func resumeIsRefusedWhenNotPaused() {
        #expect(RunningTimer.fixture().resumed(at: .t0) == nil)
    }

    @Test("A pause/resume round trip preserves every field except startDate")
    func roundTripPreservesEveryOtherField() {
        // The structural guard: any field added to RunningTimer in future that the
        // copy helpers forget to carry forward fails here, not in production.
        let original = RunningTimer.fixture(
            startDate: .t0, duration: 300, autoRestartDelaySeconds: 5
        )
        let pauseInstant = Date.t0.addingTimeInterval(60)
        let resumeInstant = pauseInstant.addingTimeInterval(90)

        let restored = try! #require(
            original.paused(at: pauseInstant)?.resumed(at: resumeInstant)
        )

        #expect(restored.id == original.id)
        #expect(restored.presetID == original.presetID)
        #expect(restored.name == original.name)
        #expect(restored.duration == original.duration)
        #expect(restored.autoRestartDelaySeconds == original.autoRestartDelaySeconds)
        #expect(restored.pausedAt == nil)
        #expect(restored.startDate == original.startDate.addingTimeInterval(90))
    }

    @Test("A repeating timer is still repeating after a pause/resume round trip")
    func repeatingTimerSurvivesPauseResumeRoundTrip() {
        let repeating = RunningTimer.fixture(autoRestartDelaySeconds: 0)
        let restored = repeating.paused(at: .t0)?.resumed(at: Date.t0.addingTimeInterval(10))
        // 0 is a real delay; it must survive as 0 and not collapse to nil.
        #expect(restored?.autoRestartDelaySeconds == 0)
        #expect(AutoRestartPolicy.resolvedDelay(
            stored: restored?.autoRestartDelaySeconds, parameter: nil) == 0)
    }
}
