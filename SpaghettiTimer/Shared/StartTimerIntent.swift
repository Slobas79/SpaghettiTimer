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

    /// Background by default, with the option to bring the app forward. A tap
    /// refused for want of permission used to do nothing at all: the widget has no
    /// way to offer the path into Settings, and the app does. Allowing a foreground
    /// continuation also means the system performs this intent in the app's process,
    /// not the widget extension's, so the permission state read below is the app's
    /// own.
    nonisolated static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    @Parameter(title: "Preset ID")
    var presetID: String

    init() {}

    init(presetID: String) {
        self.presetID = presetID
    }

    func perform() async throws -> some IntentResult {
        let manager = AlarmManager.shared
        let started = await Self.run(
            presetID: presetID,
            authorization: AlarmAuthorization(manager.authorizationState),
            presetsRepo: PresetsRepoImpl(),
            runningRepo: RunningTimersRepoImpl(),
            analytics: PendingAnalyticsQueueRepoImpl()
        ) { running in
            let configuration = AlarmConfigurationFactory.makeConfiguration(for: running)
            return (try? await AlarmManager.shared.schedule(id: running.id, configuration: configuration)) != nil
        }

        if started != nil {
            WidgetCenter.shared.reloadAllTimelines()
            return .result()
        }

        // Nothing started. When permission is why, open the app to say so: the tile
        // otherwise just sits there. Read again after the attempt rather than
        // reusing the value above, because scheduling is what settles an
        // undecided state.
        if Self.needsPermissionHandOff(afterAttempt: AlarmAuthorization(manager.authorizationState)) {
            // Record before handing off. The app reads the flag once it becomes
            // active, which can happen before this call returns.
            WidgetStartRefusal.record()
            if systemContext.currentMode.canContinueInForeground {
                try? await continueInForeground(alwaysConfirm: false)
            }
        }
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
    /// 1. Only an explicit `.denied` refuses. This used to run in the widget
    ///    extension, which AlarmKit reports `.notDetermined` to even when the
    ///    containing app holds the grant — demanding `.authorized` there is what
    ///    made every tile tap do nothing at all. An undecided state still goes to
    ///    AlarmKit, and a start it drops is handed to the app.
    /// 2. Nothing is written until AlarmKit has taken the alarm. *That*, not the
    ///    permission flag, is what keeps a phantom timer off Home: a countdown the
    ///    app draws and ticks down to a ring that never comes.
    ///
    /// Returns the started timer, or `nil` when the start was refused or dropped.
    /// A `nil` caused by permission is passed to the app; see
    /// `needsPermissionHandOff(afterAttempt:)`.
    static func run(
        presetID: String,
        authorization: AlarmAuthorization,
        presetsRepo: PresetsRepo,
        runningRepo: RunningTimersRepo,
        analytics: AnalyticsRepo,
        now: Date = Date(),
        newID: () -> UUID = UUID.init,
        scheduleReturned: () -> Date = Date.init,
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

        // Pin the countdown to when AlarmKit actually took the alarm, not to when we
        // asked. AlarmKit is given a duration and starts counting on acceptance, so
        // `now` — stamped before the await — is early by the scheduling latency, and
        // the app's clock would run that far behind the Live Activity's forever
        // after. See `CountdownAnchor`.
        let started = running.anchoringStart(
            to: CountdownAnchor.estimated(callBegan: now, callReturned: scheduleReturned())
        )

        // Append to a fresh read: three other processes write this list, and saving
        // an array read before the alarm was scheduled would drop what they added.
        var timers = runningRepo.load()
        timers.append(started)
        runningRepo.save(timers)

        analytics.log(.timerStart(
            presetID: preset.id,
            name: preset.name,
            durationSeconds: Int(preset.duration),
            isEphemeral: false,
            autoRestart: preset.autoRestartDelaySeconds != nil,
            source: .widget
        ))

        return started
    }

    /// Whether a dropped start should open the app, given the permission state read
    /// after the attempt.
    ///
    /// Anything short of a grant does. `.denied` gets the app's "Alarms are turned
    /// off" alert and its Open Settings button. `.notDetermined` means the question
    /// was never asked, and only the app can ask it. A dropped start under a grant
    /// was not about permission, and opening the app would explain nothing.
    static func needsPermissionHandOff(afterAttempt authorization: AlarmAuthorization) -> Bool {
        authorization != .authorized
    }
}
