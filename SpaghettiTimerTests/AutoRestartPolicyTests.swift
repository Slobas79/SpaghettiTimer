//
//  AutoRestartPolicyTests.swift
//  SpaghettiTimerTests
//
//  Guards the auto-restart chain: the decision to repeat, and the shape of the
//  next iteration. See commit 91cfd9d — these are the invariants whose loss made
//  repeating timers silently stop repeating.
//

import Foundation
import Testing
@testable import SpaghettiTimer

@Suite("Auto-restart policy")
struct AutoRestartPolicyTests {

    // MARK: Deciding whether to repeat

    @Test("A timer with no delay anywhere is a one-shot")
    func oneShotHasNoDelay() {
        #expect(AutoRestartPolicy.resolvedDelay(stored: nil, parameter: nil) == nil)
    }

    @Test("A stored delay of 0 means repeat immediately, not one-shot")
    func zeroStoredDelayStillRepeats() {
        // `0` is a real cooldown ("Immediately" in the UI). Treating it as falsy —
        // e.g. `delay > 0` instead of `>= 0` — silently ends the chain. QA 5.2.
        #expect(AutoRestartPolicy.resolvedDelay(stored: 0, parameter: nil) == 0)
    }

    @Test("A baked-in delay of 0 also means repeat immediately")
    func zeroBakedDelayStillRepeats() {
        #expect(AutoRestartPolicy.resolvedDelay(stored: nil, parameter: 0) == 0)
    }

    @Test("The alarm's baked-in delay restarts the chain when the stored record lost it")
    func bakedDelaySurvivesErasedRecord() {
        // This is the backstop for every way shared storage can lose the field:
        // the widget rewriting the list, a pause/resume rebuild, a stale in-memory
        // array being saved over it.
        #expect(AutoRestartPolicy.resolvedDelay(stored: nil, parameter: 5) == 5)
    }

    @Test("The stored delay wins when both are present")
    func storedDelayWinsOverBaked() {
        #expect(AutoRestartPolicy.resolvedDelay(stored: 3, parameter: 7) == 3)
    }

    @Test("A negative delay does not repeat", arguments: [-1.0, -0.5, -3600.0])
    func negativeDelayIsRejected(delay: TimeInterval) {
        #expect(AutoRestartPolicy.resolvedDelay(stored: delay, parameter: nil) == nil)
        #expect(AutoRestartPolicy.resolvedDelay(stored: nil, parameter: delay) == nil)
    }

    // MARK: Shape of the next iteration

    @Test("The next iteration always carries the delay forward, even from a timer that lost its own")
    func nextIterationAlwaysCarriesTheDelay() {
        // The previous timer was recovered from the alarm's baked-in parameters and
        // has no delay of its own. Copying `previous.autoRestartDelaySeconds` here
        // would end the chain after one more iteration.
        let recovered = RunningTimer.fixture(autoRestartDelaySeconds: nil)
        let next = recovered.nextIteration(id: UUID(), delay: 5, now: .t0)
        #expect(next.autoRestartDelaySeconds == 5)
    }

    @Test("The next iteration starts after the cooldown and ends a full duration later")
    func nextIterationStartsAfterCooldown() {
        let previous = RunningTimer.fixture(duration: 300, autoRestartDelaySeconds: 5)
        let next = previous.nextIteration(id: UUID(), delay: 5, now: .t0)
        #expect(next.startDate == Date.t0.addingTimeInterval(5))
        #expect(next.endDate == Date.t0.addingTimeInterval(305))
    }

    @Test("The next iteration keeps preset identity but takes a fresh id")
    func nextIterationKeepsIdentityButNewID() {
        let previous = RunningTimer.fixture(name: "Pasta", duration: 300, autoRestartDelaySeconds: 5)
        let newID = UUID()
        let next = previous.nextIteration(id: newID, delay: 5, now: .t0)
        #expect(next.id == newID)
        #expect(next.id != previous.id)
        #expect(next.presetID == previous.presetID)
        #expect(next.name == previous.name)
        #expect(next.duration == previous.duration)
    }

    @Test("The next iteration is not paused")
    func nextIterationIsNotPaused() {
        let paused = RunningTimer.fixture(pausedAt: .t0, autoRestartDelaySeconds: 5)
        #expect(paused.nextIteration(id: UUID(), delay: 5, now: .t0).isPaused == false)
    }

    // MARK: Rebuilding a timer whose record is gone

    @Test("A timer is reconstructable from the parameters the alarm carried")
    func bakedTimerReconstructsRepeatingTimer() {
        let presetID = UUID()
        let id = UUID()
        let rebuilt = AutoRestartPolicy.bakedTimer(
            id: id,
            presetID: presetID.uuidString,
            name: "Pasta",
            duration: 300,
            autoRestartDelay: 5,
            now: .t0
        )
        #expect(rebuilt?.id == id)
        #expect(rebuilt?.presetID == presetID)
        #expect(rebuilt?.name == "Pasta")
        #expect(rebuilt?.duration == 300)
        #expect(rebuilt?.autoRestartDelaySeconds == 5)
    }

    @Test("A reconstructed timer is already finished — it is the alarm that just rang")
    func bakedTimerIsAlreadyFinishedAtNow() {
        let rebuilt = AutoRestartPolicy.bakedTimer(
            id: UUID(), presetID: UUID().uuidString, name: "Pasta",
            duration: 300, autoRestartDelay: 5, now: .t0
        )
        #expect(rebuilt?.isFinished(at: .t0) == true)
    }

    @Test("A missing name reconstructs as empty rather than failing")
    func bakedTimerNameDefaultsToEmpty() {
        let rebuilt = AutoRestartPolicy.bakedTimer(
            id: UUID(), presetID: UUID().uuidString, name: nil,
            duration: 300, autoRestartDelay: 5, now: .t0
        )
        #expect(rebuilt?.name == "")
    }

    @Test("Reconstruction fails when the alarm predates the baked-in parameters")
    func bakedTimerIsNilWithoutDurationOrPresetID() {
        // Alarms scheduled by a build before these parameters existed carry only the
        // timer id. There is nothing to restart from, and that must not crash.
        #expect(AutoRestartPolicy.bakedTimer(
            id: UUID(), presetID: nil, name: "Pasta",
            duration: 300, autoRestartDelay: 5, now: .t0) == nil)
        #expect(AutoRestartPolicy.bakedTimer(
            id: UUID(), presetID: UUID().uuidString, name: "Pasta",
            duration: nil, autoRestartDelay: 5, now: .t0) == nil)
        #expect(AutoRestartPolicy.bakedTimer(
            id: UUID(), presetID: "not-a-uuid", name: "Pasta",
            duration: 300, autoRestartDelay: 5, now: .t0) == nil)
    }
}
