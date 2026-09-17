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
    /// Fired when a start was dropped because AlarmKit permission was refused —
    /// the UI's only cue that the tap did nothing on purpose.
    var onAuthorizationDenied: (() -> Void)? { get set }

    func reload()
    /// Starts `preset` once AlarmKit permission is in hand, and not before.
    ///
    /// The returned task completes when the attempt has settled either way. The UI
    /// discards it — the result arrives through `onChange` / `onAuthorizationDenied`
    /// — but a test can await it instead of racing the permission hop.
    @discardableResult
    func start(preset: TimerPreset) -> Task<Void, Never>
    func stop(_ timer: RunningTimer)
    func pause(_ timer: RunningTimer)
    func resume(_ timer: RunningTimer)
    func reconcileOnForeground()
    /// Shows the permission alert for a widget start that was refused while the app
    /// was elsewhere, if one is waiting. Returns a task for the same reason as
    /// `start(preset:)`.
    @discardableResult
    func explainRefusedWidgetStart() -> Task<Void, Never>
}

@MainActor
final class RunningTimersUseCaseImpl: RunningTimersUseCase {
    private(set) var running: [RunningTimer] = []
    var onChange: (() -> Void)?
    var onAuthorizationDenied: (() -> Void)?

    private let repo: RunningTimersRepo
    private let presetsRepo: PresetsRepo
    private let analytics: AnalyticsRepo
    private let cancelledTimers: UserDefaults
    private let widgetRefusals: UserDefaults
    private let authorizer: AlarmAuthorizing
    private let scheduler: AlarmScheduling
    private let widgets: WidgetRefreshing
    private let observesAlarmKit: Bool

    private var alarmObservationTask: Task<Void, Never>?
    private var seenAlarmIDs: Set<UUID> = []

    /// - Parameters:
    ///   - cancelledTimers: the suite backing `UserCancelledTimers`. Injectable so a
    ///     test can use a scratch suite instead of the shared App Group.
    ///   - widgetRefusals: the suite backing `WidgetStartRefusal`, injectable for the
    ///     same reason.
    ///   - authorizer: the AlarmKit permission gate. Injectable so a test can drive
    ///     the granted and refused paths without the system prompt.
    ///   - scheduler: who hands the alarm to AlarmKit. Defaults to the real one
    ///     unless `observesAlarmKit` is `false`, in which case nothing is scheduled
    ///     — so a test gets a safe default and can still pass a spy to assert the
    ///     start ordering.
    ///   - widgets: the widget refresh. Injectable because `WidgetCenter` is a
    ///     process-wide singleton a test cannot observe.
    ///   - observesAlarmKit: when `false`, skips startup reconciliation, the
    ///     `alarmUpdates` observation task, and real alarm scheduling in
    ///     `start(preset:)`. Tests set this: scheduling would pop a system alert
    ///     inside the test host process. Reconciliation is still exercisable
    ///     through `applyLiveAlarms(ids:)`.
    init(repo: RunningTimersRepo,
         presetsRepo: PresetsRepo,
         analytics: AnalyticsRepo = NoOpAnalyticsRepo(),
         cancelledTimers: UserDefaults = AppGroup.defaults,
         widgetRefusals: UserDefaults = AppGroup.defaults,
         authorizer: AlarmAuthorizing = AlarmKitAuthorizer(),
         scheduler: AlarmScheduling? = nil,
         widgets: WidgetRefreshing = WidgetCenterRefresher(),
         observesAlarmKit: Bool = true) {
        self.repo = repo
        self.presetsRepo = presetsRepo
        self.analytics = analytics
        self.cancelledTimers = cancelledTimers
        self.widgetRefusals = widgetRefusals
        self.authorizer = authorizer
        self.scheduler = scheduler ?? (observesAlarmKit ? AlarmKitScheduler() : NoAlarmScheduler())
        self.widgets = widgets
        self.observesAlarmKit = observesAlarmKit
        reload()
        guard observesAlarmKit else { return }
        reconcileOnStartup()
        observeAlarmDismissals()
    }



    private func reconcileOnStartup() {
        if purgeIfAlarmsRevoked() { return }
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
        widgets.reloadTimelines()
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
        let liveIDs = (try? AlarmManager.shared.alarms).map { Set($0.map(\.id)) }
        reconcileOnForeground(liveAlarmIDs: liveIDs, now: Date())
    }

    /// The foreground pass against a snapshot of AlarmKit's live alarm ids, or `nil`
    /// when AlarmKit could not be queried. Split out for the same reason as
    /// `applyLiveAlarms(ids:)`: a test cannot fabricate `[Alarm]`.
    func reconcileOnForeground(liveAlarmIDs: Set<UUID>?, now: Date) {
        // Alarms can be turned off in Settings while the app is backgrounded, which
        // silently breaks every timer already scheduled without removing any of them.
        // Foregrounding is the only moment we can notice — AlarmKit publishes no
        // authorization-change sequence, only `alarmUpdates`, which fires on alarm
        // changes and not on permission changes — and it is also the exact moment the
        // user walks back from Settings. This runs ahead of the liveness pass below
        // because that pass structurally cannot catch a revocation: see
        // `AlarmAuthorization.revokesScheduledTimers`.
        if purgeIfAlarmsRevoked() { return }

        // Always, not only when this pass changes something. The Home Screen widget can
        // be stale while this array is not: a timer started from the widget and cancelled
        // from the Dynamic Island never passed through here, so the id sets below match
        // and nothing looked worth refreshing — yet the cancel's own reload came from the
        // background, where WidgetKit may refuse it. A reload from the foreground is not
        // charged to the widget's budget, so this is the free moment to repair it.
        defer { widgets.reloadTimelines() }

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
        guard let liveIDs = liveAlarmIDs else {
            // Couldn't verify liveness — just publish the repo reload.
            if Set(running.map(\.id)) != previousIDs {
                onChange?()
            }
            return
        }

        // Prune a timer when its alarm is gone from AlarmKit AND either we've already observed it
        // live or it has finished. The `isFinished` arm catches the case the `seenAlarmIDs` guard
        // alone misses: a timer started and then fired while the app was suspended is never
        // recorded in `seenAlarmIDs` (the alarmUpdates observer didn't run), yet it's clearly
        // done. A *freshly* started timer whose alarm is still scheduling is neither finished nor
        // seen, so it's preserved; an actively ringing alarm is still in `liveIDs`, so it's kept.
        // (Mirrors `removeTimers(notIn:)`.)
        let dismissed = RunningTimersMerge.dismissed(
            in: running, liveAlarmIDs: liveIDs, seenIDs: seenAlarmIDs, now: now
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
        }
    }

    @discardableResult
    func explainRefusedWidgetStart() -> Task<Void, Never> {
        // `StartTimerIntent` records the refusal and opens the app, but the widget
        // cannot show the alert, so the app shows it here. The permission check is
        // repeated because the user may have turned alarms back on before returning,
        // and in that case there is nothing to explain. `resolve()` rather than
        // `current`: an undecided state is the question the widget could not ask.
        Task { [weak self] in
            guard let self, WidgetStartRefusal.consume(in: self.widgetRefusals) else { return }
            guard await self.authorizer.resolve() != .authorized else { return }
            self.onAuthorizationDenied?()
        }
    }

    /// Clears every running timer once AlarmKit permission has been revoked, and
    /// reports whether it had anything to clear.
    ///
    /// A timer that cannot ring must not exist — the same rule the start paths enforce
    /// with the permission gate, applied to timers that were legitimately started and
    /// then had the ground taken out from under them. Cancelling each alarm is the part
    /// that matters beyond Home: clearing shared storage fixes the running row and the
    /// widget dot, but the Lock Screen and Dynamic Island presentations belong to
    /// AlarmKit and come down only when the alarm itself does.
    ///
    /// `false` when nothing was purged, so the caller falls through to its normal
    /// reconciliation and so a second foreground under the same denial re-alerts
    /// nobody.
    @discardableResult
    func purgeIfAlarmsRevoked() -> Bool {
        guard authorizer.current.revokesScheduledTimers else { return false }
        // Disk as well as memory: the auto-restart iteration `StopTimerIntent` wrote
        // from another process is exactly the kind of timer that gets stranded here,
        // and this array has never been told about it.
        let stranded = RunningTimersMerge.merging(inMemory: running, disk: repo.load())
        guard !stranded.isEmpty else { return false }

        for timer in stranded {
            // Mark before cancelling. The cancels land as an `alarmUpdates` emission,
            // and without the flag `logCompletions` would bill each revoked timer as a
            // `timer_complete` that nobody ever heard.
            UserCancelledTimers.mark(timer.id, in: cancelledTimers)
            // A revocation is not a user cancellation, but it is a forced one, and it
            // is the closest terminal event in the taxonomy — logging nothing would
            // leave every one of these starts without an end.
            analytics.log(.timerCancel(
                presetID: timer.presetID,
                name: timer.name,
                durationSeconds: Int(timer.duration),
                source: .app
            ))
        }

        running = []
        repo.save([])
        seenAlarmIDs.removeAll()
        if observesAlarmKit {
            let ids = stranded.map(\.id)
            Task {
                for id in ids { try? AlarmManager.shared.cancel(id: id) }
            }
        }
        // Timers vanishing on their own needs explaining, and the refusal alert
        // already says what happened and offers the way back into Settings.
        onAuthorizationDenied?()
        onChange?()
        widgets.reloadTimelines()
        return true
    }

    private func syncPauseState(from alarms: [Alarm]) {
        applyPauseState(
            pausedIDs: Set(alarms.filter { $0.state == .paused }.map(\.id)),
            countingIDs: Set(alarms.filter { $0.state == .countdown }.map(\.id)),
            now: Date()
        )
    }

    /// Reconciles pause state against a snapshot of what AlarmKit currently reports.
    ///
    /// Split out of `syncPauseState(from:)` for the same reason as
    /// `applyLiveAlarms(ids:)`: `AlarmKit.Alarm` has no public memberwise
    /// initializer, so a test cannot fabricate `[Alarm]` — but the ids and their
    /// states are all this needs.
    func applyPauseState(pausedIDs: Set<UUID>, countingIDs: Set<UUID>, now: Date) {
        // Read disk first. The Lock Screen's Pause/Resume buttons are AppIntents that
        // bypass this use case and have already stamped the true transition instant
        // there; this array has never been told. See `reconcilingPauseState`.
        let stored = repo.load()
        let reconciled = RunningTimersMerge.reconcilingPauseState(
            inMemory: running,
            disk: stored,
            pausedAlarmIDs: pausedIDs,
            countingAlarmIDs: countingIDs,
            now: now
        )
        guard reconciled != running else { return }
        running = reconciled
        // Merge on the way back out so a record another process added between that
        // load and now is not erased by this save.
        repo.save(RunningTimersMerge.merging(inMemory: reconciled, disk: stored))
        onChange?()
        widgets.reloadTimelines()
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
        widgets.reloadTimelines()
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
        widgets.reloadTimelines()
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

    @discardableResult
    func start(preset: TimerPreset) -> Task<Void, Never> {
        // Permission first, and nothing before it. An unauthorized timer would be
        // persisted, drawn on Home and counted in analytics while AlarmKit stays
        // empty — a countdown that can never ring. The prompt on a first start is
        // therefore a gate, not a formality: a refusal drops the start entirely.
        Task { [weak self] in
            guard let self else { return }
            guard await self.authorizer.resolve() == .authorized else {
                self.onAuthorizationDenied?()
                return
            }
            await self.commitStart(preset: preset)
        }
    }

    private func commitStart(preset: TimerPreset) async {
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
        // Publish to the app before scheduling: Home owns its own state and must
        // show the countdown on the same runloop turn as the tap.
        onChange?()

        // The widget must wait. It has no state of its own — it decides which tile
        // is "running" by intersecting shared storage with AlarmKit's live alarm
        // list (`RunningTimersMerge.visible`), so a refresh fired before the alarm
        // is scheduled snapshots a timer AlarmKit has never heard of, drops it, and
        // draws the tile idle for the whole run: nothing reloads the timeline again
        // until the timer is stopped. The widget's own start path already orders it
        // this way — `StartTimerIntent.run` schedules before it writes anything.
        let callBegan = Date()
        await scheduler.schedule(timer)
        anchorCountdown(of: timer.id, callBegan: callBegan, callReturned: Date())
        widgets.reloadTimelines()
    }

    /// Re-pins a just-started timer's `startDate` to when AlarmKit actually began
    /// counting, so Home and the Live Activity show the same number.
    ///
    /// Only a correction big enough to change a rendered digit is applied. This runs
    /// after the timer has already been saved and published — that ordering is the
    /// point of `commitStart` and is pinned by `StartSideEffectOrderTests` — so
    /// applying one costs a second save and a second publish. A schedule that
    /// returned promptly has nothing worth that; the slow ones this exists for (a
    /// loaded device, or the first start of all, where the call waits behind the
    /// permission prompt) are exactly the ones that clear the bar.
    private func anchorCountdown(of id: UUID, callBegan: Date, callReturned: Date) {
        let anchor = CountdownAnchor.estimated(callBegan: callBegan, callReturned: callReturned)
        guard anchor.timeIntervalSince(callBegan) >= CountdownAnchor.perceptibleCorrection else { return }
        running = RunningTimersMerge.merging(inMemory: running, disk: repo.load())
        guard let index = running.firstIndex(where: { $0.id == id }) else { return }
        running[index] = running[index].anchoringStart(to: anchor)
        repo.save(running)
        onChange?()
    }

    func stop(_ timer: RunningTimer) {
        UserCancelledTimers.mark(timer.id, in: cancelledTimers)
        running.removeAll { $0.id == timer.id }
        repo.save(running)
        analytics.log(.timerCancel(presetID: timer.presetID, name: timer.name, durationSeconds: Int(timer.duration), source: .app))
        let timerID = timer.id
        Task { try? AlarmManager.shared.cancel(id: timerID) }
        onChange?()
        widgets.reloadTimelines()
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
        widgets.reloadTimelines()
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
        widgets.reloadTimelines()
    }
}
