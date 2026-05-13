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
        let presetUUID = UUID(uuidString: presetID) ?? UUID()
        let presetsRepo = PresetsRepoImpl()
        let runningRepo = RunningTimersRepoImpl()

        let preset = presetsRepo.allPresets().first(where: { $0.id == presetUUID })
            ?? TimerPreset(id: presetUUID, name: "Timer", duration: 60, isBuiltIn: false)

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

        let manager = AlarmManager.shared
        if manager.authorizationState == .notDetermined {
            _ = try? await manager.requestAuthorization()
        }

        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: preset.name),
            stopButton: .init(text: "Stop", textColor: .white, systemImageName: "stop.fill")
        )
        let attributes = AlarmAttributes<SpaghettiTimerMetadata>(
            presentation: .init(alert: alert),
            metadata: SpaghettiTimerMetadata(presetName: preset.name, alarmID: running.id.uuidString),
            tintColor: .accentColor
        )
        let configuration = AlarmManager.AlarmConfiguration.timer(
            duration: preset.duration,
            attributes: attributes,
            sound: .default
        )
        _ = try? await manager.schedule(id: running.id, configuration: configuration)

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
