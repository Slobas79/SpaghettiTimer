//
//  RunningTimersUseCase.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 23. 4. 2026..
//

import AlarmKit
import Foundation
import WidgetKit

@MainActor
protocol RunningTimersUseCase: AnyObject {
    var running: [RunningTimer] { get }
    var onChange: (() -> Void)? { get set }

    func reload()
    func start(preset: TimerPreset)
    func stop(_ timer: RunningTimer)
    func pause(_ timer: RunningTimer)
    func resume(_ timer: RunningTimer)
    func pruneFinished()
    func reconcileOnForeground()
}

@MainActor
final class RunningTimersUseCaseImpl: RunningTimersUseCase {
    private(set) var running: [RunningTimer] = []
    var onChange: (() -> Void)?

    private let repo: RunningTimersRepo
    private let presetsRepo: PresetsRepo
    private let analytics: AnalyticsRepo

    private var alarmObservationTask: Task<Void, Never>?
    private var seenAlarmIDs: Set<UUID> = []

    init(repo: RunningTimersRepo, presetsRepo: PresetsRepo, analytics: AnalyticsRepo = NoOpAnalyticsRepo()) {
        self.repo = repo
        self.presetsRepo = presetsRepo
        self.analytics = analytics
        reload()
        reconcileOnStartup()
        observeAlarmDismissals()
    }

    private func reconcileOnStartup() {
        guard !running.isEmpty else { return }
        let liveIDs: Set<UUID>
        if let alarms = try? AlarmManager.shared.alarms {
            liveIDs = Set(alarms.map(\.id))
        } else {
            return
        }
        // A timer absent from AlarmKit's live list has been stopped/cancelled, including a
        // fired-then-stopped one. An alarm still alerting is present in the list (so kept here);
        // at cold start nothing has been freshly scheduled yet, so there's no race to guard.
        let dismissed = running.filter { !liveIDs.contains($0.id) }
        guard !dismissed.isEmpty else { return }
        logCompletions(for: dismissed)
        let dismissedSet = Set(dismissed.map(\.id))
        running.removeAll { dismissedSet.contains($0.id) }
        repo.save(running)
        onChange?()
        WidgetCenter.shared.reloadAllTimelines()
    }

    deinit {
        alarmObservationTask?.cancel()
    }

    private func observeAlarmDismissals() {
        alarmObservationTask = Task { [weak self] in
            for await alarms in AlarmManager.shared.alarmUpdates {
                guard let self else { return }
                let activeIDs = Set(alarms.map(\.id))
                self.seenAlarmIDs.formUnion(activeIDs)
                self.removeTimers(notIn: activeIDs)
                self.adoptTimersStartedElsewhere(liveIDs: activeIDs)
                self.syncPauseState(from: alarms)
            }
        }
    }

    func reconcileOnForeground() {
        // AppIntents (Stop / Repeat / Start) run in other processes and write directly to the
        // shared repo while the app is backgrounded. Re-load it on foreground so out-of-process
        // additions (auto-restart's next iteration) and removals are reflected — the in-memory
        // `running` array is otherwise never told about them.
        let previousIDs = Set(running.map(\.id))
        running = repo.load()

        // AlarmKit is the source of truth for which alarms are still alive: countdown, paused
        // and alerting alarms are all present in `AlarmManager.shared.alarms` and disappear only
        // once stopped or cancelled. So a timer that's gone from this list has been dismissed —
        // including a fired-then-stopped one (`isFinished`). We can't depend on the custom
        // StopTimerIntent for this: it doesn't run in every context (e.g. the Simulator) and can
        // fail on device. Keying off the alarm list self-heals regardless.
        guard let alarms = try? AlarmManager.shared.alarms else {
            // Couldn't verify liveness — just publish the repo reload.
            if Set(running.map(\.id)) != previousIDs {
                onChange?()
                WidgetCenter.shared.reloadAllTimelines()
            }
            return
        }
        let liveIDs = Set(alarms.map(\.id))

        // Prune a timer when its alarm is gone from AlarmKit AND either we've already observed it
        // live or it has finished. The `isFinished` arm catches the case the `seenAlarmIDs` guard
        // alone misses: a timer started and then fired while the app was suspended is never
        // recorded in `seenAlarmIDs` (the alarmUpdates observer didn't run), yet it's clearly
        // done. A *freshly* started timer whose alarm is still scheduling is neither finished nor
        // seen, so it's preserved; an actively ringing alarm is still in `liveIDs`, so it's kept.
        // (Mirrors `removeTimers(notIn:)`.)
        let now = Date()
        let dismissed = running.filter { !liveIDs.contains($0.id) && (seenAlarmIDs.contains($0.id) || $0.isFinished(at: now)) }
        if !dismissed.isEmpty {
            logCompletions(for: dismissed)
            let dismissedSet = Set(dismissed.map(\.id))
            running.removeAll { dismissedSet.contains($0.id) }
            seenAlarmIDs.subtract(dismissedSet)
            repo.save(running)
        }

        if Set(running.map(\.id)) != previousIDs {
            onChange?()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func syncPauseState(from alarms: [Alarm]) {
        var changed = false
        let now = Date()
        for alarm in alarms {
            guard let index = running.firstIndex(where: { $0.id == alarm.id }) else { continue }
            let existing = running[index]
            switch alarm.state {
            case .paused:
                guard !existing.isPaused else { continue }
                running[index] = RunningTimer(
                    id: existing.id,
                    presetID: existing.presetID,
                    name: existing.name,
                    startDate: existing.startDate,
                    duration: existing.duration,
                    pausedAt: now,
                    autoRestartDelaySeconds: existing.autoRestartDelaySeconds
                )
                changed = true
            case .countdown:
                guard let pausedAt = existing.pausedAt else { continue }
                let delta = now.timeIntervalSince(pausedAt)
                running[index] = RunningTimer(
                    id: existing.id,
                    presetID: existing.presetID,
                    name: existing.name,
                    startDate: existing.startDate.addingTimeInterval(delta),
                    duration: existing.duration,
                    pausedAt: nil,
                    autoRestartDelaySeconds: existing.autoRestartDelaySeconds
                )
                changed = true
            default:
                continue
            }
        }
        if changed {
            repo.save(running)
            onChange?()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func removeTimers(notIn activeIDs: Set<UUID>) {
        let now = Date()
        let dismissed = running
            .filter { !activeIDs.contains($0.id) &&
                      (seenAlarmIDs.contains($0.id) || $0.isFinished(at: now)) }
        guard !dismissed.isEmpty else { return }

        // Auto-restart is handled by StopTimerIntent so it works even when this
        // process isn't running (e.g. timer started from the widget). Consuming
        // the user-cancelled flag clears it from shared storage and tells us
        // whether the timer completed vs. was cancelled (for analytics).
        logCompletions(for: dismissed)

        let dismissedSet = Set(dismissed.map(\.id))
        seenAlarmIDs.subtract(dismissedSet)
        // Start from disk, not from the in-memory array, so a next-iteration timer
        // written by StopTimerIntent (which bypasses this use case) survives — and
        // so the dismissed ones are cleared from shared storage too, instead of
        // being read straight back in.
        var stored = repo.load()
        stored.removeAll { dismissedSet.contains($0.id) }
        repo.save(stored)
        running = stored
        onChange?()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Pulls in timers that were started outside this use case — the auto-restart
    /// iteration `StopTimerIntent` writes when a repeating timer is stopped, or a
    /// timer launched from the widget. They only ever reach shared storage, so
    /// without this the in-memory array (and the home screen) misses them until
    /// the next foregrounding, and the next `repo.save(running)` erases them.
    private func adoptTimersStartedElsewhere(liveIDs: Set<UUID>) {
        let known = Set(running.map(\.id))
        let unknown = repo.load().filter { liveIDs.contains($0.id) && !known.contains($0.id) }
        guard !unknown.isEmpty else { return }
        running.append(contentsOf: unknown)
        onChange?()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// A timer gone from AlarmKit that was never explicitly cancelled ran to
    /// completion. `UserCancelledTimers.consume` returns true for timers already
    /// accounted for by `stop()` / CancelTimerIntent / StopTimerIntent (all of
    /// which mark the flag), so those are skipped here to avoid double-counting a
    /// `timer_cancel`/acknowledged `timer_complete` that was already logged.
    private func logCompletions(for dismissed: [RunningTimer]) {
        for timer in dismissed {
            let wasCancelled = UserCancelledTimers.consume(timer.id)
            guard !wasCancelled else { continue }
            analytics.log(.timerComplete(
                presetID: timer.presetID,
                name: timer.name,
                durationSeconds: Int(timer.duration),
                acknowledged: false,
                source: .app
            ))
        }
    }

    func reload() {
        running = repo.load()
        onChange?()
    }

    func start(preset: TimerPreset) {
        let timer = RunningTimer(
            id: UUID(),
            presetID: preset.id,
            name: preset.name,
            startDate: Date(),
            duration: preset.duration,
            autoRestartDelaySeconds: preset.autoRestartDelaySeconds
        )
        // Repo first: another process may have added a timer (auto-restart's next
        // iteration, or a widget start) that this array doesn't know about yet,
        // and saving the stale array would drop it.
        let knownIDs = Set(running.map(\.id))
        running += repo.load().filter { !knownIDs.contains($0.id) }
        running.append(timer)
        repo.save(running)
        let isEphemeral = !presetsRepo.allPresets().contains { $0.id == preset.id }
        analytics.log(.timerStart(
            presetID: preset.id,
            name: preset.name,
            durationSeconds: Int(preset.duration),
            isEphemeral: isEphemeral,
            autoRestart: preset.autoRestartDelaySeconds != nil,
            source: .app
        ))
        Task {
            await ensureAuthorized()
            await schedule(timer)
        }
        onChange?()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func stop(_ timer: RunningTimer) {
        UserCancelledTimers.mark(timer.id)
        running.removeAll { $0.id == timer.id }
        repo.save(running)
        analytics.log(.timerCancel(presetID: timer.presetID, name: timer.name, durationSeconds: Int(timer.duration), source: .app))
        let timerID = timer.id
        Task { try? AlarmManager.shared.cancel(id: timerID) }
        onChange?()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func pause(_ timer: RunningTimer) {
        guard let index = running.firstIndex(where: { $0.id == timer.id }), !running[index].isPaused else { return }
        let existing = running[index]
        running[index] = RunningTimer(
            id: existing.id,
            presetID: existing.presetID,
            name: existing.name,
            startDate: existing.startDate,
            duration: existing.duration,
            pausedAt: Date(),
            autoRestartDelaySeconds: existing.autoRestartDelaySeconds
        )
        repo.save(running)
        analytics.log(.timerPause(presetID: existing.presetID, name: existing.name, durationSeconds: Int(existing.duration), source: .app))
        let timerID = timer.id
        Task { try? AlarmManager.shared.pause(id: timerID) }
        onChange?()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func resume(_ timer: RunningTimer) {
        guard let index = running.firstIndex(where: { $0.id == timer.id }),
              let pausedAt = running[index].pausedAt else { return }
        let existing = running[index]
        let delta = Date().timeIntervalSince(pausedAt)
        running[index] = RunningTimer(
            id: existing.id,
            presetID: existing.presetID,
            name: existing.name,
            startDate: existing.startDate.addingTimeInterval(delta),
            duration: existing.duration,
            pausedAt: nil,
            autoRestartDelaySeconds: existing.autoRestartDelaySeconds
        )
        repo.save(running)
        analytics.log(.timerResume(presetID: existing.presetID, name: existing.name, durationSeconds: Int(existing.duration), source: .app))
        let timerID = timer.id
        Task { try? AlarmManager.shared.resume(id: timerID) }
        onChange?()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func pruneFinished() {
        let now = Date()
        let finished = running.filter { $0.isFinished(at: now) }
        guard !finished.isEmpty else { return }
        for timer in finished {
            UserCancelledTimers.mark(timer.id)
        }
        running.removeAll { $0.isFinished(at: now) }
        repo.save(running)
        for timer in finished {
            let timerID = timer.id
            Task { try? AlarmManager.shared.cancel(id: timerID) }
        }
        onChange?()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func ensureAuthorized() async {
        let manager = AlarmManager.shared
        print("[AlarmKit] authorizationState=\(manager.authorizationState)")
        switch manager.authorizationState {
        case .notDetermined:
            do {
                let result = try await manager.requestAuthorization()
                print("[AlarmKit] requestAuthorization result=\(result)")
            } catch {
                print("[AlarmKit] requestAuthorization error=\(error)")
            }
        default:
            return
        }
    }

    private func schedule(_ timer: RunningTimer) async {
        let configuration = AlarmConfigurationFactory.makeConfiguration(for: timer)
        do {
            let scheduled = try await AlarmManager.shared.schedule(id: timer.id, configuration: configuration)
            print("[AlarmKit] scheduled id=\(timer.id) state=\(scheduled.state)")
        } catch {
            print("[AlarmKit] schedule error=\(error)")
        }
    }
}
