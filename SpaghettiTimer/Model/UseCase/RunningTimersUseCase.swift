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
    func reconcileOnForeground()
}

@MainActor
final class RunningTimersUseCaseImpl: RunningTimersUseCase {
    private(set) var running: [RunningTimer] = []
    var onChange: (() -> Void)?

    private let repo: RunningTimersRepo
    private let presetsRepo: PresetsRepo
    private let analytics: AnalyticsRepo
    private let cancelledTimers: UserDefaults
    private let observesAlarmKit: Bool

    private var alarmObservationTask: Task<Void, Never>?
    private var seenAlarmIDs: Set<UUID> = []

    /// - Parameters:
    ///   - cancelledTimers: the suite backing `UserCancelledTimers`. Injectable so a
    ///     test can use a scratch suite instead of the shared App Group.
    ///   - observesAlarmKit: when `false`, skips startup reconciliation, the
    ///     `alarmUpdates` observation task, and alarm scheduling in `start(preset:)`.
    ///     Tests set this: scheduling would call `requestAuthorization()` and pop a
    ///     system permission alert inside the test host process. Reconciliation is
    ///     still exercisable through `applyLiveAlarms(ids:)`.
    init(repo: RunningTimersRepo,
         presetsRepo: PresetsRepo,
         analytics: AnalyticsRepo = NoOpAnalyticsRepo(),
         cancelledTimers: UserDefaults = AppGroup.defaults,
         observesAlarmKit: Bool = true) {
        self.repo = repo
        self.presetsRepo = presetsRepo
        self.analytics = analytics
        self.cancelledTimers = cancelledTimers
        self.observesAlarmKit = observesAlarmKit
        reload()
        guard observesAlarmKit else { return }
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
                self.applyLiveAlarms(ids: Set(alarms.map(\.id)))
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
        let dismissed = RunningTimersMerge.dismissed(
            in: running, liveAlarmIDs: liveIDs, seenIDs: seenAlarmIDs, now: Date()
        )
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
                guard let paused = existing.paused(at: now) else { continue }
                running[index] = paused
                changed = true
            case .countdown:
                guard let resumed = existing.resumed(at: now) else { continue }
                running[index] = resumed
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

    /// Reconciles against a snapshot of the alarms AlarmKit currently considers live.
    ///
    /// Split out of the `alarmUpdates` loop so cross-process reconciliation can be
    /// driven from a test — `AlarmKit.Alarm` has no public memberwise initializer, so
    /// a test cannot fabricate `[Alarm]`, but a set of ids is all this needs.
    func applyLiveAlarms(ids activeIDs: Set<UUID>) {
        seenAlarmIDs.formUnion(activeIDs)
        removeTimers(notIn: activeIDs)
        adoptTimersStartedElsewhere(liveIDs: activeIDs)
    }

    private func removeTimers(notIn activeIDs: Set<UUID>) {
        let dismissed = RunningTimersMerge.dismissed(
            in: running, liveAlarmIDs: activeIDs, seenIDs: seenAlarmIDs, now: Date()
        )
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
        let stored = RunningTimersMerge.removingDismissed(disk: repo.load(), dismissedIDs: dismissedSet)
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
        let unknown = RunningTimersMerge.adoptable(
            inMemory: running, disk: repo.load(), liveAlarmIDs: liveIDs
        )
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
            let wasCancelled = UserCancelledTimers.consume(timer.id, in: cancelledTimers)
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
        running = RunningTimersMerge.merging(inMemory: running, disk: repo.load())
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
        if observesAlarmKit {
            Task {
                await ensureAuthorized()
                await schedule(timer)
            }
        }
        onChange?()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func stop(_ timer: RunningTimer) {
        UserCancelledTimers.mark(timer.id, in: cancelledTimers)
        running.removeAll { $0.id == timer.id }
        repo.save(running)
        analytics.log(.timerCancel(presetID: timer.presetID, name: timer.name, durationSeconds: Int(timer.duration), source: .app))
        let timerID = timer.id
        Task { try? AlarmManager.shared.cancel(id: timerID) }
        onChange?()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func pause(_ timer: RunningTimer) {
        guard let index = running.firstIndex(where: { $0.id == timer.id }),
              let paused = running[index].paused(at: Date()) else { return }
        let existing = running[index]
        running[index] = paused
        repo.save(running)
        analytics.log(.timerPause(presetID: existing.presetID, name: existing.name, durationSeconds: Int(existing.duration), source: .app))
        let timerID = timer.id
        Task { try? AlarmManager.shared.pause(id: timerID) }
        onChange?()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func resume(_ timer: RunningTimer) {
        guard let index = running.firstIndex(where: { $0.id == timer.id }),
              let resumed = running[index].resumed(at: Date()) else { return }
        let existing = running[index]
        running[index] = resumed
        repo.save(running)
        analytics.log(.timerResume(presetID: existing.presetID, name: existing.name, durationSeconds: Int(existing.duration), source: .app))
        let timerID = timer.id
        Task { try? AlarmManager.shared.resume(id: timerID) }
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
