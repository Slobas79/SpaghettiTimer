//
//  StopTimerIntentParametersTests.swift
//  SpaghettiTimerTests
//
//  The parameters baked into the alarm are the only copy of the timer that
//  survives another process erasing the shared-storage record.
//

import AppIntents
import Foundation
import Testing
@testable import SpaghettiTimer

@Suite("Stop intent parameters")
struct StopTimerIntentParametersTests {

    @Test("The intent carries every field needed to repeat")
    func intentCarriesEveryFieldNeededToRepeat() {
        let timer = RunningTimer.fixture(name: "Pasta", duration: 300, autoRestartDelaySeconds: 5)
        let intent = StopTimerIntent(timer: timer)
        #expect(intent.timerID == timer.id.uuidString)
        #expect(intent.presetID == timer.presetID.uuidString)
        #expect(intent.timerName == "Pasta")
        #expect(intent.duration == 300)
        #expect(intent.autoRestartDelay == 5)
    }

    @Test("A one-shot bakes in a nil delay, not a zero one")
    func intentCarriesNilDelayForOneShot() {
        let intent = StopTimerIntent(timer: .fixture(autoRestartDelaySeconds: nil))
        #expect(intent.autoRestartDelay == nil)
    }

    @Test("A zero delay is baked in as zero")
    func intentCarriesZeroDelayAsZero() {
        let intent = StopTimerIntent(timer: .fixture(autoRestartDelaySeconds: 0))
        #expect(intent.autoRestartDelay == 0)
    }

    @Test("A baked intent round-trips back into a usable timer")
    func bakedIntentRoundTripsBackToTimer() {
        // The complete recovery loop: schedule → alarm carries the parameters →
        // storage is erased → Stop rebuilds the timer from the alarm alone.
        let original = RunningTimer.fixture(name: "Pasta", duration: 300, autoRestartDelaySeconds: 5)
        let intent = StopTimerIntent(timer: original)

        let rebuilt = AutoRestartPolicy.bakedTimer(
            id: UUID(uuidString: intent.timerID)!,
            presetID: intent.presetID,
            name: intent.timerName,
            duration: intent.duration,
            autoRestartDelay: intent.autoRestartDelay,
            now: .t0
        )

        #expect(rebuilt?.presetID == original.presetID)
        #expect(rebuilt?.name == original.name)
        #expect(rebuilt?.duration == original.duration)
        #expect(rebuilt?.autoRestartDelaySeconds == original.autoRestartDelaySeconds)

        let delay = AutoRestartPolicy.resolvedDelay(
            stored: nil, parameter: rebuilt?.autoRestartDelaySeconds
        )
        #expect(delay == 5)
    }

    @Test("The intent still exposes all five parameters")
    func intentStillExposesFiveParameters() {
        // Catches a deleted @Parameter, which would compile fine but silently drop
        // a field from the alarm payload.
        let mirror = Mirror(reflecting: StopTimerIntent(timer: .fixture()))
        let parameterCount = mirror.children.filter { $0.label?.hasPrefix("_") == true }.count
        #expect(parameterCount == 5)
    }
}
