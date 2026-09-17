//
//  PauseClockSyncTests.swift
//  SpaghettiTimerTests
//
//  Guards the one number the user can check against the system: the countdown.
//  Home and the Lock Screen render it from two different clocks — ours, from
//  `RunningTimer`, and AlarmKit's, from `AlarmPresentationState` — and they must
//  agree. Every test here pins one of the ways they used to drift apart.
//

import Foundation
import Testing
@testable import SpaghettiTimer

@Suite("Pause clock sync")
struct PauseClockSyncTests {

    // MARK: Reconciling against AlarmKit's pause state

    @Test("A Lock Screen pause keeps the instant the intent recorded, not the instant we heard about it")
    func adoptsThePauseRecordedByTheIntent() {
        // The user taps Pause on the Lock Screen at t0+60. `PauseTimerIntent` stamps
        // that instant straight into shared storage, bypassing the use case, so the
        // in-memory array still shows the timer counting. The `alarmUpdates` emission
        // that tells the use case is handled later — here at t0+63 — and those three
        // seconds used to be written straight over the intent's value.
        let stale = RunningTimer.fixture(startDate: .t0, duration: 300)
        let recorded = stale.paused(at: Date.t0.addingTimeInterval(60))!

        let reconciled = RunningTimersMerge.reconcilingPauseState(
            inMemory: [stale],
            disk: [recorded],
            pausedAlarmIDs: [stale.id],
            countingAlarmIDs: [],
            now: Date.t0.addingTimeInterval(63)
        )

        #expect(reconciled.first?.pausedAt == Date.t0.addingTimeInterval(60))
        #expect(reconciled.first?.remaining() == 240)
    }

    @Test("A Lock Screen resume keeps the shift the intent computed")
    func adoptsTheResumeRecordedByTheIntent() {
        // Paused at t0+60 with 240 left, resumed at t0+90: `startDate` moves forward
        // by the 30 seconds of pause so `remaining` survives it untouched. Re-deriving
        // that shift at t0+93 would have lost three more seconds.
        let paused = RunningTimer.fixture(startDate: .t0, duration: 300, pausedAt: Date.t0.addingTimeInterval(60))
        let recorded = paused.resumed(at: Date.t0.addingTimeInterval(90))!

        let reconciled = RunningTimersMerge.reconcilingPauseState(
            inMemory: [paused],
            disk: [recorded],
            pausedAlarmIDs: [],
            countingAlarmIDs: [paused.id],
            now: Date.t0.addingTimeInterval(93)
        )

        #expect(reconciled.first?.startDate == Date.t0.addingTimeInterval(30))
        #expect(reconciled.first?.isPaused == false)
        #expect(reconciled.first?.remaining(at: Date.t0.addingTimeInterval(90)) == 240)
    }

    @Test("A pause nobody recorded still gets stamped")
    func stampsATransitionNoIntentRecorded() {
        // AlarmKit reached `.paused` without either intent running. There is nothing
        // better than the current instant here, and doing nothing would leave Home
        // counting down against a frozen alarm.
        let running = RunningTimer.fixture(startDate: .t0, duration: 300)

        let reconciled = RunningTimersMerge.reconcilingPauseState(
            inMemory: [running],
            disk: [running],
            pausedAlarmIDs: [running.id],
            countingAlarmIDs: [],
            now: Date.t0.addingTimeInterval(63)
        )

        #expect(reconciled.first?.pausedAt == Date.t0.addingTimeInterval(63))
    }

    @Test("A state both sides already agree on is left alone")
    func leavesAgreeingStateUntouched() {
        // Re-stamping here is what made the error compound across pause cycles: every
        // `alarmUpdates` emission during a pause would push `pausedAt` forward again.
        let paused = RunningTimer.fixture(startDate: .t0, duration: 300, pausedAt: Date.t0.addingTimeInterval(60))

        let reconciled = RunningTimersMerge.reconcilingPauseState(
            inMemory: [paused],
            disk: [paused],
            pausedAlarmIDs: [paused.id],
            countingAlarmIDs: [],
            now: Date.t0.addingTimeInterval(200)
        )

        #expect(reconciled == [paused])
    }

    @Test("A timer with no alarm in the snapshot is not touched")
    func ignoresTimersAbsentFromTheSnapshot() {
        // Liveness is `applyLiveAlarms`'s job. An alarm that is alerting — or one
        // AlarmKit simply did not report this time — must not have its pause state
        // invented here.
        let running = RunningTimer.fixture(startDate: .t0, duration: 300)

        let reconciled = RunningTimersMerge.reconcilingPauseState(
            inMemory: [running],
            disk: [running],
            pausedAlarmIDs: [],
            countingAlarmIDs: [],
            now: Date.t0.addingTimeInterval(400)
        )

        #expect(reconciled == [running])
    }

    @Test("A timer missing from disk falls back to the current instant")
    func stampsWhenDiskHasNoRecord() {
        // A cancel or stop intent can delete the record between the emission and our load.
        // The in-memory timer is still the one on screen, so it still has to move.
        let running = RunningTimer.fixture(startDate: .t0, duration: 300)

        let reconciled = RunningTimersMerge.reconcilingPauseState(
            inMemory: [running],
            disk: [],
            pausedAlarmIDs: [running.id],
            countingAlarmIDs: [],
            now: Date.t0.addingTimeInterval(63)
        )

        #expect(reconciled.first?.pausedAt == Date.t0.addingTimeInterval(63))
    }

    // MARK: Where the countdown is anchored

    @Test("The countdown is anchored to the middle of the scheduling window")
    func anchorsToTheMiddleOfTheScheduleCall() {
        // AlarmKit began counting somewhere inside the call and never says where, so
        // the midpoint is the estimate that halves the worst case. Stamping the start
        // of the window — what we used to do — left the app's clock behind AlarmKit's
        // by the whole latency.
        let anchor = CountdownAnchor.estimated(
            callBegan: .t0,
            callReturned: Date.t0.addingTimeInterval(0.8)
        )

        #expect(anchor == Date.t0.addingTimeInterval(0.4))
    }

    @Test("A non-positive scheduling window keeps the original stamp")
    func anchorIgnoresANonPositiveWindow() {
        #expect(CountdownAnchor.estimated(callBegan: .t0, callReturned: .t0) == .t0)
        #expect(CountdownAnchor.estimated(callBegan: .t0, callReturned: Date.t0.addingTimeInterval(-5)) == .t0)
    }

    @Test("A correction too small to change a digit is not worth republishing for")
    func subPerceptibleCorrectionsAreSkipped() {
        // The app path has already saved and drawn the timer by the time the latency
        // is known, so applying a correction costs a second save and publish. Both
        // surfaces render whole seconds — under half a second there is no digit to
        // change and nothing to buy with them.
        let prompt = CountdownAnchor.estimated(callBegan: .t0, callReturned: Date.t0.addingTimeInterval(0.06))
        #expect(prompt.timeIntervalSince(.t0) < CountdownAnchor.perceptibleCorrection)

        // A start that waited behind the permission prompt is the case this exists for.
        let slow = CountdownAnchor.estimated(callBegan: .t0, callReturned: Date.t0.addingTimeInterval(4))
        #expect(slow.timeIntervalSince(.t0) >= CountdownAnchor.perceptibleCorrection)
    }

    @Test("Anchoring moves the end date without changing the duration")
    func anchoringShiftsTheEndDate() {
        let timer = RunningTimer.fixture(startDate: .t0, duration: 300)
        let anchored = timer.anchoringStart(to: Date.t0.addingTimeInterval(0.4))

        #expect(anchored.duration == 300)
        #expect(anchored.endDate == Date.t0.addingTimeInterval(300.4))
        #expect(anchored.id == timer.id)
    }

    @Test("Anchoring carries every other field forward")
    func anchoringPreservesEveryField() {
        // The reason this transition lives beside `paused`/`resumed` rather than at
        // the call site: a forgotten `autoRestartDelaySeconds` silently turns a
        // repeating timer into a one-shot.
        let timer = RunningTimer.fixture(
            startDate: .t0, duration: 300,
            pausedAt: Date.t0.addingTimeInterval(60),
            autoRestartDelaySeconds: 5
        )
        let anchored = timer.anchoringStart(to: Date.t0.addingTimeInterval(1))

        #expect(anchored.presetID == timer.presetID)
        #expect(anchored.name == timer.name)
        #expect(anchored.pausedAt == timer.pausedAt)
        #expect(anchored.autoRestartDelaySeconds == 5)
    }
}
