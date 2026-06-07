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

        UserCancelledTimers.mark(id)

        let repo = RunningTimersRepoImpl()
        var timers = repo.load()
        let finished = timers.first(where: { $0.id == id })
        timers.removeAll { $0.id == id }
        repo.save(timers)

        await Self.cancelAlarm(id: id)

        let after = repo.load()
        if after.contains(where: { $0.id == id }) {
            var cleaned = after
            cleaned.removeAll { $0.id == id }
            repo.save(cleaned)
        }

        if let finished, let delay = finished.autoRestartDelaySeconds, delay >= 0 {
            await Self.scheduleNextIteration(after: finished, delay: delay)
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

    private static func scheduleNextIteration(after previous: RunningTimer, delay: TimeInterval) async {
        let next = RunningTimer(
            id: UUID(),
            presetID: previous.presetID,
            name: previous.name,
            startDate: Date().addingTimeInterval(delay),
            duration: previous.duration,
            autoRestartDelaySeconds: previous.autoRestartDelaySeconds
        )

        let repo = RunningTimersRepoImpl()
        var timers = repo.load()
        timers.append(next)
        repo.save(timers)

        let manager = AlarmManager.shared
        if manager.authorizationState == .notDetermined {
            _ = try? await manager.requestAuthorization()
        }

        let configuration = AlarmConfigurationFactory.makeConfiguration(for: next, leadIn: delay)
        _ = try? await manager.schedule(id: next.id, configuration: configuration)
        print("[Stop] auto-restart scheduled next id=\(next.id) startDate=\(next.startDate)")
    }
}
