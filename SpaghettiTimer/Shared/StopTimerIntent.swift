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

    // The timer's own details, baked into the alarm when it's scheduled. The
    // stored `RunningTimer` is still preferred, but it lives in shared
    // UserDefaults that other processes rewrite (the widget's timeline, the
    // pause/resume intents, the app's in-memory array), and a record that got
    // dropped or rewritten used to silently kill auto-restart — the alarm rang,
    // Stop found nothing to repeat, and the timer never came back. These
    // parameters travel with the alarm, so a repeating timer can always restart
    // itself. Optional so alarms scheduled by an older build still decode.
    @Parameter(title: "Preset ID")
    var presetID: String?

    @Parameter(title: "Timer Name")
    var timerName: String?

    @Parameter(title: "Duration")
    var duration: Double?

    @Parameter(title: "Auto Restart Delay")
    var autoRestartDelay: Double?

    init() {}

    init(timer: RunningTimer) {
        self.timerID = timer.id.uuidString
        self.presetID = timer.presetID.uuidString
        self.timerName = timer.name
        self.duration = timer.duration
        self.autoRestartDelay = timer.autoRestartDelaySeconds
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: timerID) else { return .result() }

        UserCancelledTimers.mark(id)

        let repo = RunningTimersRepoImpl()
        var timers = repo.load()
        let stored = timers.first(where: { $0.id == id })
        timers.removeAll { $0.id == id }
        repo.save(timers)

        // Whatever survived: the stored record, or the alarm's own copy of it.
        let finished = stored ?? bakedInTimer(id: id)

        if let finished {
            PendingAnalyticsQueueRepoImpl().log(.timerComplete(
                presetID: finished.presetID,
                name: finished.name,
                durationSeconds: Int(finished.duration),
                acknowledged: true,
                source: .alarmAlert
            ))
        }

        await Self.cancelAlarm(id: id)

        let after = repo.load()
        if after.contains(where: { $0.id == id }) {
            var cleaned = after
            cleaned.removeAll { $0.id == id }
            repo.save(cleaned)
        }

        // The stored record can have lost its delay to a rewrite even when the
        // record itself survived, so the baked-in value backstops it too.
        if let finished, let delay = finished.autoRestartDelaySeconds ?? autoRestartDelay, delay >= 0 {
            await Self.scheduleNextIteration(after: finished, delay: delay)
        }

        print("[Stop] removed id=\(id) remaining=\(repo.load().count)")
        WidgetCenter.shared.reloadTimelines(ofKind: "PresetsWidget")
        return .result()
    }

    /// Reconstructs the finished timer from the parameters carried by the alarm,
    /// for when its shared-storage record is gone. Only the fields the next
    /// iteration needs are meaningful — `startDate` is in the past by definition.
    private func bakedInTimer(id: UUID) -> RunningTimer? {
        guard let duration, let presetID, let presetUUID = UUID(uuidString: presetID) else { return nil }
        return RunningTimer(
            id: id,
            presetID: presetUUID,
            name: timerName ?? "",
            startDate: Date().addingTimeInterval(-duration),
            duration: duration,
            autoRestartDelaySeconds: autoRestartDelay
        )
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
            autoRestartDelaySeconds: delay
        )

        let repo = RunningTimersRepoImpl()
        var timers = repo.load()
        timers.append(next)
        repo.save(timers)

        PendingAnalyticsQueueRepoImpl().log(.timerStart(
            presetID: next.presetID,
            name: next.name,
            durationSeconds: Int(next.duration),
            isEphemeral: false,
            autoRestart: next.autoRestartDelaySeconds != nil,
            source: .alarmAlert,
            autoRestartIteration: true
        ))

        let manager = AlarmManager.shared
        if manager.authorizationState == .notDetermined {
            _ = try? await manager.requestAuthorization()
        }

        let configuration = AlarmConfigurationFactory.makeConfiguration(for: next, leadIn: delay)
        _ = try? await manager.schedule(id: next.id, configuration: configuration)
        print("[Stop] auto-restart scheduled next id=\(next.id) startDate=\(next.startDate)")
    }
}
