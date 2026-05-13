//
//  RepeatTimerIntent.swift
//  SpaghettiTimer
//

import ActivityKit
import AlarmKit
import AppIntents
import Foundation
import SwiftUI
import WidgetKit

struct RepeatTimerIntent: LiveActivityIntent {
    nonisolated static let title: LocalizedStringResource = "Repeat Timer"
    nonisolated static let description = IntentDescription("Restarts the same timer from the beginning.")

    @Parameter(title: "Timer ID")
    var timerID: String

    @Parameter(title: "Preset ID")
    var presetID: String

    init() {}

    init(timerID: String, presetID: String) {
        self.timerID = timerID
        self.presetID = presetID
    }

    func perform() async throws -> some IntentResult {
        let presetsRepo = PresetsRepoImpl()
        let runningRepo = RunningTimersRepoImpl()
        let manager = AlarmManager.shared

        var oldDuration: TimeInterval = 60
        if let oldID = UUID(uuidString: timerID) {
            var timers = runningRepo.load()
            oldDuration = timers.first(where: { $0.id == oldID })?.duration ?? 60
            timers.removeAll { $0.id == oldID }
            runningRepo.save(timers)
            try? manager.cancel(id: oldID)
        }

        let presetUUID = UUID(uuidString: presetID) ?? UUID()
        let preset = presetsRepo.allPresets().first(where: { $0.id == presetUUID })
            ?? TimerPreset(id: presetUUID, name: "Timer", duration: oldDuration, isBuiltIn: false)

        let running = RunningTimer(
            id: UUID(),
            presetID: preset.id,
            name: preset.name,
            startDate: Date(),
            duration: preset.duration
        )

        var timers = runningRepo.load()
        timers.append(running)
        runningRepo.save(timers)

        if manager.authorizationState == .notDetermined {
            _ = try? await manager.requestAuthorization()
        }

        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: preset.name),
            stopButton: .init(text: "Stop", textColor: .white, systemImageName: "stop.fill"),
            secondaryButton: .init(text: "Repeat", textColor: .white, systemImageName: "repeat"),
            secondaryButtonBehavior: .custom
        )
        let attributes = AlarmAttributes<SpaghettiTimerMetadata>(
            presentation: .init(alert: alert),
            metadata: SpaghettiTimerMetadata(presetName: preset.name, alarmID: running.id.uuidString, presetID: preset.id.uuidString),
            tintColor: .accentColor
        )
        let configuration = AlarmManager.AlarmConfiguration.timer(
            duration: preset.duration,
            attributes: attributes,
            secondaryIntent: RepeatTimerIntent(timerID: running.id.uuidString, presetID: preset.id.uuidString),
            sound: .default
        )
        _ = try? await manager.schedule(id: running.id, configuration: configuration)

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
