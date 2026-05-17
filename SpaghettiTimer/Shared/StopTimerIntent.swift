//
//  StopTimerIntent.swift
//  SpaghettiTimer
//

import AlarmKit
import AppIntents
import Foundation
import WidgetKit

struct StopTimerIntent: LiveActivityIntent {
    nonisolated static let title: LocalizedStringResource = "Stop Timer"
    nonisolated static let description = IntentDescription("Stops the running countdown timer and clears its widget indicator.")

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

        await Self.cancelAlarm(id: id)

        let after = repo.load()
        if after.contains(where: { $0.id == id }) {
            var cleaned = after
            cleaned.removeAll { $0.id == id }
            repo.save(cleaned)
        }

        print("[Stop] removed id=\(id) remaining=\(repo.load().count)")
        WidgetCenter.shared.reloadTimelines(ofKind: "PresetsWidget")
        return .result()
    }

    private static func cancelAlarm(id: UUID) async {
        await Task.detached(priority: .userInitiated) {
            try? AlarmManager.shared.cancel(id: id)
        }.value
    }
}
