//
//  StartTimerIntent.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 23. 4. 2026..
//

import ActivityKit
import AlarmKit
import AppIntents
import Foundation
import SwiftUI
import WidgetKit

struct StartTimerIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Start Timer"
    nonisolated static let description = IntentDescription("Starts a countdown timer for the selected preset.")

    @Parameter(title: "Preset ID")
    var presetID: String

    init() {}

    init(presetID: String) {
        self.presetID = presetID
    }

    func perform() async throws -> some IntentResult {
        let started = await Self.run(
            presetID: presetID,
            authorization: AlarmAuthorization(AlarmManager.shared.authorizationState),
            presetsRepo: PresetsRepoImpl(),
            runningRepo: RunningTimersRepoImpl(),
            analytics: PendingAnalyticsQueueRepoImpl()
        ) { running in
            let configuration = AlarmConfigurationFactory.makeConfiguration(for: running)
            return (try? await AlarmManager.shared.schedule(id: running.id, configuration: configuration)) != nil
        }

        if started != nil { WidgetCenter.shared.reloadAllTimelines() }
        return .result()
    }
}

extension StartTimerIntent {
    /// The widget's start sequence, with every collaborator explicit so the ordering
    /// can be tested — `perform()` above is only the wiring. `schedule` reports
    /// whether AlarmKit took the alarm.
    ///
    /// Two rules, in this order, and both are load-bearing:
    ///
    /// 1. Only an explicit `.denied` refuses. This runs in the widget extension,
    ///    which has no UI to prompt with and which AlarmKit reports `.notDetermined`
    ///    to even when the containing app holds the grant — demanding `.authorized`
    ///    here is what made every tile tap do nothing at all.
    /// 2. Nothing is written until AlarmKit has taken the alarm. *That*, not the
    ///    permission flag, is what keeps a phantom timer off Home: a countdown the
    ///    app draws and ticks down to a ring that never comes.
    ///
    /// Returns the started timer, or `nil` when the start was refused or dropped.
    static func run(
        presetID: String,
        authorization: AlarmAuthorization,
        presetsRepo: PresetsRepo,
        runningRepo: RunningTimersRepo,
        analytics: AnalyticsRepo,
        now: Date = Date(),
        newID: () -> UUID = UUID.init,
        schedule: (RunningTimer) async -> Bool
    ) async -> RunningTimer? {
        guard authorization.allowsUnpromptedStart else { return nil }

        let presetUUID = UUID(uuidString: presetID) ?? UUID()
        let preset = presetsRepo.allPresets().first(where: { $0.id == presetUUID })
            ?? TimerPreset(id: presetUUID, name: "Timer", duration: 60, isBuiltIn: false)

        let running = RunningTimer(
            id: newID(),
            presetID: preset.id,
            name: preset.name,
            startDate: now,
            duration: preset.duration,
            autoRestartDelaySeconds: preset.autoRestartDelaySeconds
        )

        guard await schedule(running) else { return nil }

        // Append to a fresh read: three other processes write this list, and saving
        // an array read before the alarm was scheduled would drop what they added.
        var timers = runningRepo.load()
        timers.append(running)
        runningRepo.save(timers)

        analytics.log(.timerStart(
            presetID: preset.id,
            name: preset.name,
            durationSeconds: Int(preset.duration),
            isEphemeral: false,
            autoRestart: preset.autoRestartDelaySeconds != nil,
            source: .widget
        ))

        return running
    }
}
