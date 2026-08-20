//
//  TimerActivityAttributes.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 23. 4. 2026..
//

import ActivityKit
import AlarmKit
import Foundation
import SwiftUI

nonisolated enum AlarmConfigurationFactory {
    /// Builds the AlarmKit configuration for a `RunningTimer`.
    ///
    /// Kept to pure pass-through: `AlarmManager.AlarmConfiguration` exposes no
    /// readable properties, so nothing about the value this returns can be asserted
    /// in a test. The pieces below are testable, this composition is not — so it
    /// must stay trivial enough to verify by eye.
    static func makeConfiguration(
        for timer: RunningTimer,
        leadIn: TimeInterval = 0
    ) -> AlarmManager.AlarmConfiguration<SpaghettiTimerMetadata> {
        AlarmManager.AlarmConfiguration.timer(
            duration: countdownDuration(for: timer, leadIn: leadIn),
            attributes: makeAttributes(for: timer),
            stopIntent: makeStopIntent(for: timer),
            secondaryIntent: RepeatTimerIntent(
                timerID: timer.id.uuidString,
                presetID: timer.presetID.uuidString
            ),
            sound: .default
        )
    }

    /// The AlarmKit countdown length. `leadIn` implements the auto-restart cooldown:
    /// the next iteration's `startDate` is set `leadIn` seconds in the future, and
    /// adding the same amount here means the alert fires exactly at its `endDate`
    /// while the user still sees a single continuous countdown.
    ///
    /// These two must move together — `leadIn` here and the `startDate` offset in
    /// `RunningTimer.nextIteration(id:delay:now:)`.
    static func countdownDuration(for timer: RunningTimer, leadIn: TimeInterval) -> TimeInterval {
        timer.duration + leadIn
    }

    /// A repeating timer gets a Stop button only. Offering "Repeat" as well would be
    /// redundant, and `RepeatTimerIntent` has no cooldown handling — so the secondary
    /// button is withheld and `RepeatTimerIntent` is reachable for one-shots only.
    static func makeAlert(for timer: RunningTimer) -> AlarmPresentation.Alert {
        if timer.autoRestartDelaySeconds != nil {
            return AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: timer.name),
                stopButton: .init(text: "Stop", textColor: .white, systemImageName: "stop.fill")
            )
        }
        return AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: timer.name),
            stopButton: .init(text: "Stop", textColor: .white, systemImageName: "stop.fill"),
            secondaryButton: .init(text: "Repeat", textColor: .white, systemImageName: "repeat"),
            secondaryButtonBehavior: .custom
        )
    }

    static func makeAttributes(for timer: RunningTimer) -> AlarmAttributes<SpaghettiTimerMetadata> {
        let countdown = AlarmPresentation.Countdown(
            title: LocalizedStringResource(stringLiteral: timer.name),
            pauseButton: .init(text: "Pause", textColor: .white, systemImageName: "pause.fill")
        )
        let paused = AlarmPresentation.Paused(
            title: LocalizedStringResource(stringLiteral: timer.name),
            resumeButton: .init(text: "Resume", textColor: .white, systemImageName: "play.fill")
        )
        return AlarmAttributes<SpaghettiTimerMetadata>(
            presentation: .init(alert: makeAlert(for: timer), countdown: countdown, paused: paused),
            metadata: SpaghettiTimerMetadata(
                presetName: timer.name,
                alarmID: timer.id.uuidString,
                presetID: timer.presetID.uuidString,
                autoRestartDelaySeconds: timer.autoRestartDelaySeconds
            ),
            tintColor: .accentColor
        )
    }

    /// The Stop intent baked into the alarm. It must be built with `init(timer:)`,
    /// not from the id alone: the parameters it carries are the only copy of the
    /// timer that survives another process erasing the shared-storage record, and
    /// they are what lets a repeating timer restart itself.
    static func makeStopIntent(for timer: RunningTimer) -> StopTimerIntent {
        StopTimerIntent(timer: timer)
    }
}

nonisolated struct SpaghettiTimerMetadata: AlarmMetadata {
    let presetName: String
    let alarmID: String
    let presetID: String
    let autoRestartDelaySeconds: TimeInterval?

    init(presetName: String, alarmID: String, presetID: String, autoRestartDelaySeconds: TimeInterval? = nil) {
        self.presetName = presetName
        self.alarmID = alarmID
        self.presetID = presetID
        self.autoRestartDelaySeconds = autoRestartDelaySeconds
    }
}
