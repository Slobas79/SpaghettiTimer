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
    /// Builds the AlarmKit configuration for a `RunningTimer`. `leadIn` is added to the
    /// AlarmKit countdown duration to delay the actual alert by that many seconds while
    /// still presenting a single countdown — used to implement the auto-restart cooldown.
    static func makeConfiguration(
        for timer: RunningTimer,
        leadIn: TimeInterval = 0
    ) -> AlarmManager.AlarmConfiguration<SpaghettiTimerMetadata> {
        let alert: AlarmPresentation.Alert
        if timer.autoRestartDelaySeconds != nil {
            alert = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: timer.name),
                stopButton: .init(text: "Stop", textColor: .white, systemImageName: "stop.fill")
            )
        } else {
            alert = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: timer.name),
                stopButton: .init(text: "Stop", textColor: .white, systemImageName: "stop.fill"),
                secondaryButton: .init(text: "Repeat", textColor: .white, systemImageName: "repeat"),
                secondaryButtonBehavior: .custom
            )
        }
        let countdown = AlarmPresentation.Countdown(
            title: LocalizedStringResource(stringLiteral: timer.name),
            pauseButton: .init(text: "Pause", textColor: .white, systemImageName: "pause.fill")
        )
        let paused = AlarmPresentation.Paused(
            title: LocalizedStringResource(stringLiteral: timer.name),
            resumeButton: .init(text: "Resume", textColor: .white, systemImageName: "play.fill")
        )
        let attributes = AlarmAttributes<SpaghettiTimerMetadata>(
            presentation: .init(alert: alert, countdown: countdown, paused: paused),
            metadata: SpaghettiTimerMetadata(
                presetName: timer.name,
                alarmID: timer.id.uuidString,
                presetID: timer.presetID.uuidString,
                autoRestartDelaySeconds: timer.autoRestartDelaySeconds
            ),
            tintColor: .accentColor
        )
        return AlarmManager.AlarmConfiguration.timer(
            duration: timer.duration + leadIn,
            attributes: attributes,
            stopIntent: StopTimerIntent(timerID: timer.id.uuidString),
            secondaryIntent: RepeatTimerIntent(timerID: timer.id.uuidString, presetID: timer.presetID.uuidString),
            sound: .default
        )
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        presetName = try container.decode(String.self, forKey: .presetName)
        alarmID = try container.decode(String.self, forKey: .alarmID)
        presetID = try container.decode(String.self, forKey: .presetID)
        autoRestartDelaySeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .autoRestartDelaySeconds)
    }
}
