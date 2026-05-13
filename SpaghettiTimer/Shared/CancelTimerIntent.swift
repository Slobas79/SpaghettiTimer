//
//  CancelTimerIntent.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 6. 5. 2026..
//

import AlarmKit
import AppIntents
import Foundation
import WidgetKit

struct CancelTimerIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Cancel Timer"
    nonisolated static let description = IntentDescription("Cancels the running countdown timer.")

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
        timers.removeAll { $0.id == id }
        repo.save(timers)

        try? AlarmManager.shared.cancel(id: id)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
