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

    // The timer's own details, baked into the alarm when it's scheduled.
    //
    // The stored `RunningTimer` is still preferred, but it lives in shared
    // UserDefaults that other processes rewrite — the widget's timeline, the
    // pause/resume intents, the app's in-memory array — and a record that got
    // dropped or rewritten used to silently kill auto-restart: the alarm rang, Stop
    // found nothing to repeat, and the timer never came back. These parameters
    // travel with the alarm itself, so a repeating timer can always restart itself
    // no matter what happened to shared storage.
    //
    // They are optional and must stay optional. That is not a migration shim: it is
    // what lets the fallback exist at all, and it also means an alarm scheduled by a
    // build that predates these parameters still decodes instead of failing to stop.
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
        if let finished,
           let delay = AutoRestartPolicy.resolvedDelay(
               stored: finished.autoRestartDelaySeconds,
               parameter: autoRestartDelay
           ) {
            await Self.scheduleNextIteration(after: finished, delay: delay)
        }

        print("[Stop] removed id=\(id) remaining=\(repo.load().count)")
        WidgetCenter.shared.reloadTimelines(ofKind: "PresetsWidget")
        return .result()
    }

    private func bakedInTimer(id: UUID) -> RunningTimer? {
        AutoRestartPolicy.bakedTimer(
            id: id,
            presetID: presetID,
            name: timerName,
            duration: duration,
            autoRestartDelay: autoRestartDelay,
            now: Date()
        )
    }

    private static func cancelAlarm(id: UUID) async {
        await Task.detached(priority: .userInitiated) {
            try? AlarmManager.shared.cancel(id: id)
        }.value
    }

    private static func scheduleNextIteration(after previous: RunningTimer, delay: TimeInterval) async {
        let next = previous.nextIteration(id: UUID(), delay: delay, now: Date())

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
