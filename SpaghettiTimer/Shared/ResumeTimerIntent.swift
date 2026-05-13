//
//  ResumeTimerIntent.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 6. 5. 2026..
//

import AlarmKit
import AppIntents
import Foundation
import WidgetKit

struct ResumeTimerIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Resume Timer"
    nonisolated static let description = IntentDescription("Resumes the paused countdown timer.")

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
           let pausedAt = timers[index].pausedAt {
            let existing = timers[index]
            let delta = Date().timeIntervalSince(pausedAt)
            timers[index] = RunningTimer(
                id: existing.id,
                presetID: existing.presetID,
                name: existing.name,
                startDate: existing.startDate.addingTimeInterval(delta),
                duration: existing.duration,
                pausedAt: nil
            )
            repo.save(timers)
        }

        try? AlarmManager.shared.resume(id: id)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
