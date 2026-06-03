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
        var oldAutoRestartDelay: TimeInterval? = nil
        if let oldID = UUID(uuidString: timerID) {
            UserCancelledTimers.mark(oldID)
            var timers = runningRepo.load()
            if let existing = timers.first(where: { $0.id == oldID }) {
                oldDuration = existing.duration
                oldAutoRestartDelay = existing.autoRestartDelaySeconds
            }
            timers.removeAll { $0.id == oldID }
            runningRepo.save(timers)
            try? manager.cancel(id: oldID)
        }

        let presetUUID = UUID(uuidString: presetID) ?? UUID()
        let preset = presetsRepo.allPresets().first(where: { $0.id == presetUUID })
            ?? TimerPreset(id: presetUUID, name: "Timer", duration: oldDuration, isBuiltIn: false, autoRestartDelaySeconds: oldAutoRestartDelay)

        let running = RunningTimer(
            id: UUID(),
            presetID: preset.id,
            name: preset.name,
            startDate: Date(),
            duration: preset.duration,
            autoRestartDelaySeconds: preset.autoRestartDelaySeconds ?? oldAutoRestartDelay
        )

        var timers = runningRepo.load()
        timers.append(running)
        runningRepo.save(timers)

        if manager.authorizationState == .notDetermined {
            _ = try? await manager.requestAuthorization()
        }

        let configuration = AlarmConfigurationFactory.makeConfiguration(for: running)
        _ = try? await manager.schedule(id: running.id, configuration: configuration)

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
