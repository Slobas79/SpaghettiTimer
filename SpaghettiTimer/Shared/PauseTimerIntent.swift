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

/// A `LiveActivityIntent` for the same reason as `CancelTimerIntent`: performed in
/// the widget extension, its `reloadAllTimelines()` was ignored, and the Home Screen
/// widget kept a timeline that turned the tile idle at the original end time while
/// the timer sat paused. The widget no longer reloads on its own, so nothing would
/// have brought the tile back.
///
/// `nonisolated` for the same reason as `CancelTimerIntent`'s conformance.
struct PauseTimerIntent: nonisolated LiveActivityIntent {
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
