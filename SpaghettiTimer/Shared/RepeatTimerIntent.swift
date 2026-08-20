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

// TODO: This intent never received the hardening from commit 91cfd9d. It reads the
// previous timer's duration and delay only from `runningRepo.load()`, so if the
// stored record was erased by another process it silently produces a 60-second,
// non-repeating timer named "Timer" — the same failure mode `StopTimerIntent`'s
// baked-in `@Parameter`s were added to fix.
//
// Not currently reachable for repeating timers: `AlarmConfigurationFactory.makeAlert`
// withholds the secondary "Repeat" button whenever `autoRestartDelaySeconds != nil`,
// so this only ever fires on one-shots and the auto-restart chain is unaffected.
// It becomes a live bug the moment a Repeat button is offered on a repeating alert.
//
// Fix is ~15 lines (an `init(timer:)` plus baked-in parameters, reusing
// `AutoRestartPolicy.bakedTimer`) but it changes the alarm payload shape a second
// time in one release, so it is deliberately deferred to its own change.
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

        PendingAnalyticsQueueRepoImpl().log(.timerRepeat(
            presetID: running.presetID,
            name: running.name,
            durationSeconds: Int(running.duration),
            source: .alarmAlert
        ))

        if manager.authorizationState == .notDetermined {
            _ = try? await manager.requestAuthorization()
        }

        let configuration = AlarmConfigurationFactory.makeConfiguration(for: running)
        _ = try? await manager.schedule(id: running.id, configuration: configuration)

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
