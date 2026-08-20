//
//  AlarmConfigurationTests.swift
//  SpaghettiTimerTests
//
//  `AlarmManager.AlarmConfiguration` exposes no readable properties, so the value
//  `makeConfiguration` returns cannot be inspected. These tests assert on the
//  inputs it is composed from instead, which are fully readable.
//

import AlarmKit
import Foundation
import Testing
@testable import SpaghettiTimer

@Suite("Alarm configuration")
struct AlarmConfigurationTests {

    // MARK: Alert shape

    @Test("A repeating timer's alert offers Stop only")
    func repeatingTimerGetsStopOnlyAlert() {
        // Offering Repeat alongside Stop on a repeating timer would route the user
        // into RepeatTimerIntent, which has no cooldown handling.
        let repeating = RunningTimer.fixture(autoRestartDelaySeconds: 5)
        let alert = AlarmConfigurationFactory.makeAttributes(for: repeating).presentation.alert
        #expect(alert.secondaryButton == nil)
        #expect(alert.secondaryButtonBehavior == nil)
    }

    @Test("A one-shot's alert offers a custom Repeat button")
    func oneShotGetsRepeatButton() {
        let oneShot = RunningTimer.fixture(autoRestartDelaySeconds: nil)
        let alert = AlarmConfigurationFactory.makeAttributes(for: oneShot).presentation.alert
        #expect(alert.secondaryButton?.systemImageName == "repeat")
        #expect(alert.secondaryButtonBehavior == .custom)
    }

    @Test("A zero-delay timer counts as repeating for alert purposes")
    func zeroDelayCountsAsRepeating() {
        let repeating = RunningTimer.fixture(autoRestartDelaySeconds: 0)
        let alert = AlarmConfigurationFactory.makeAttributes(for: repeating).presentation.alert
        #expect(alert.secondaryButton == nil)
    }

    // MARK: Metadata carried to the Live Activity

    @Test("Metadata carries the auto-restart delay")
    func metadataCarriesAutoRestartDelay() {
        // The Live Activity and Dynamic Island read this to draw the loop glyph.
        let repeating = RunningTimer.fixture(autoRestartDelaySeconds: 5)
        let metadata = AlarmConfigurationFactory.makeAttributes(for: repeating).metadata
        #expect(metadata?.autoRestartDelaySeconds == 5)
    }

    @Test("Metadata carries the preset and alarm ids and the name")
    func metadataCarriesIdentity() {
        let timer = RunningTimer.fixture(name: "Pasta")
        let metadata = AlarmConfigurationFactory.makeAttributes(for: timer).metadata
        #expect(metadata?.alarmID == timer.id.uuidString)
        #expect(metadata?.presetID == timer.presetID.uuidString)
        #expect(metadata?.presetName == "Pasta")
    }

    @Test("Metadata delay is nil for a one-shot")
    func metadataDelayIsNilForOneShot() {
        let oneShot = RunningTimer.fixture(autoRestartDelaySeconds: nil)
        #expect(AlarmConfigurationFactory.makeAttributes(for: oneShot).metadata?.autoRestartDelaySeconds == nil)
    }

    // MARK: The cooldown mechanic

    @Test("The countdown covers the cooldown plus the duration")
    func countdownDurationAddsLeadIn() {
        // The cooldown is presented as one continuous countdown: the next
        // iteration's startDate is `delay` in the future and the alarm counts
        // `duration + delay`, so it fires exactly at endDate. These two must move
        // together — see RunningTimer.nextIteration.
        let timer = RunningTimer.fixture(duration: 300, autoRestartDelaySeconds: 5)
        #expect(AlarmConfigurationFactory.countdownDuration(for: timer, leadIn: 5) == 305)
    }

    @Test("Without a cooldown the countdown is just the duration")
    func countdownDurationWithoutLeadIn() {
        let timer = RunningTimer.fixture(duration: 300)
        #expect(AlarmConfigurationFactory.countdownDuration(for: timer, leadIn: 0) == 300)
    }

    @Test("The countdown ends exactly when the next iteration ends")
    func countdownMatchesNextIterationEndDate() {
        // The invariant that ties the two halves of the cooldown together.
        let previous = RunningTimer.fixture(duration: 300, autoRestartDelaySeconds: 5)
        let next = previous.nextIteration(id: UUID(), delay: 5, now: .t0)
        let countdown = AlarmConfigurationFactory.countdownDuration(for: next, leadIn: 5)
        #expect(Date.t0.addingTimeInterval(countdown) == next.endDate)
    }

    // MARK: The stop intent baked into the alarm

    @Test("The factory bakes the whole timer into the stop intent")
    func factoryBakesTheFullIntentIntoTheAlarm() {
        // Goes red the moment anyone reverts to StopTimerIntent(timerID:), which is
        // what left Stop with nothing to repeat from.
        let timer = RunningTimer.fixture(name: "Pasta", duration: 300, autoRestartDelaySeconds: 5)
        let intent = AlarmConfigurationFactory.makeStopIntent(for: timer)
        #expect(intent.timerID == timer.id.uuidString)
        #expect(intent.presetID == timer.presetID.uuidString)
        #expect(intent.timerName == "Pasta")
        #expect(intent.duration == 300)
        #expect(intent.autoRestartDelay == 5)
    }

    @Test("Composing a full configuration does not trap")
    func makeConfigurationComposesWithoutTrapping() {
        // AlarmConfiguration is opaque, so this only proves the composition runs.
        // The pieces it composes are asserted above.
        _ = AlarmConfigurationFactory.makeConfiguration(
            for: .fixture(autoRestartDelaySeconds: 5), leadIn: 5
        )
        _ = AlarmConfigurationFactory.makeConfiguration(for: .fixture())
    }
}
