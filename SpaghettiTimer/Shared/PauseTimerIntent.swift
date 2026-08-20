//
//  PauseTimerIntent.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 6. 5. 2026..
//

import AlarmKit
import AppIntents
import Foundation
import WidgetKit

struct PauseTimerIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Pause Timer"
    nonisolated static let description = IntentDescription("Pauses the running countdown timer.")

    @Parameter(title: "Timer ID")
    var timerID: String

    init() {}

    init(timerID: String) {
        self.timerID = timerID
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: timerID) else { return .result() }

        let repo = RunningTimersRepoImpl()
        var timers = repo.load()
        if let index = timers.firstIndex(where: { $0.id == id }),
           let paused = timers[index].paused(at: Date()) {
            let existing = timers[index]
            timers[index] = paused
            repo.save(timers)
            PendingAnalyticsQueueRepoImpl().log(.timerPause(
                presetID: existing.presetID,
                name: existing.name,
                durationSeconds: Int(existing.duration),
                source: .liveActivity
            ))
        }

        try? AlarmManager.shared.pause(id: id)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
