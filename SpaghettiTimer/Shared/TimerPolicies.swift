//
//  TimerPolicies.swift
//  SpaghettiTimer
//
//  Pure decision logic for the auto-restart chain and for reconciling the
//  running-timers list across processes.
//
//  These are free functions over explicit inputs — no repo, no AlarmKit, no clock.
//  That is what makes them testable, and in one case (`visible`) the absence of a
//  repo parameter is itself the guarantee: the widget process used to write its
//  filtered list back to shared storage, deleting the record of the timer that was
//  alerting at that moment, which is what silently killed auto-restart.
//

import Foundation

nonisolated enum AutoRestartPolicy {
    /// The cooldown for the next iteration, or `nil` if this timer does not repeat.
    ///
    /// `stored` is the delay on the finished `RunningTimer`; `parameter` is the copy
    /// baked into the alarm's Stop intent. The stored record lives in App Group
    /// `UserDefaults` that four processes rewrite, and it can lose the field — or
    /// vanish entirely — before Stop reads it, so the baked-in value backstops it.
    ///
    /// `0` is a valid delay meaning "restart immediately" and must not be confused
    /// with `nil`, which means "one-shot". Negative delays do not repeat.
    static func resolvedDelay(stored: TimeInterval?, parameter: TimeInterval?) -> TimeInterval? {
        guard let delay = stored ?? parameter, delay >= 0 else { return nil }
        return delay
    }

    /// Reconstructs the finished timer from the parameters the alarm carried, for
    /// when its shared-storage record is gone. Only the fields the next iteration
    /// needs are meaningful — `startDate` is in the past by definition.
    ///
    /// Returns `nil` when the alarm predates these parameters (scheduled by an older
    /// build), in which case there is nothing to restart from.
    static func bakedTimer(
        id: UUID,
        presetID: String?,
        name: String?,
        duration: Double?,
        autoRestartDelay: Double?,
        now: Date
    ) -> RunningTimer? {
        guard let duration,
              let presetID,
              let presetUUID = UUID(uuidString: presetID) else { return nil }
        return RunningTimer(
            id: id,
            presetID: presetUUID,
            name: name ?? "",
            startDate: now.addingTimeInterval(-duration),
            duration: duration,
            autoRestartDelaySeconds: autoRestartDelay
        )
    }
}

/// Where the app's countdown clock is pinned relative to AlarmKit's.
nonisolated enum CountdownAnchor {
    /// The instant AlarmKit's countdown began, estimated from the window around the
    /// `schedule` call.
    ///
    /// The exact instant is never reported back: `Alarm` carries a bare `State` with
    /// no timing, and the only values that do have it — `AlarmPresentationState.Mode`
    /// — exist in the widget process. So it is bracketed instead. The midpoint of the
    /// call window halves the worst-case error rather than leaving all of it on one
    /// side, which is what stamping `startDate` before the call did.
    /// Below this, a correction cannot change anything the user sees.
    ///
    /// Both surfaces render whole seconds, so only an error of half a second or more
    /// rounds to a different digit. The app path has to pay a second save and a
    /// second publish to apply a correction — it has already persisted and drawn the
    /// timer by the time the latency is known — and spending those on a shift nobody
    /// can perceive is churn. The widget path pays nothing (it saves only after
    /// scheduling, so it anchors the record it was going to write anyway) and applies
    /// the correction unconditionally.
    static let perceptibleCorrection: TimeInterval = 0.5

    static func estimated(callBegan: Date, callReturned: Date) -> Date {
        let latency = callReturned.timeIntervalSince(callBegan)
        // A clock that went backwards, or a scheduler that returned before it was
        // called, is not information — keep the original stamp.
        guard latency > 0 else { return callBegan }
        return callBegan.addingTimeInterval(latency / 2)
    }
}

nonisolated enum RunningTimersMerge {
    /// The timers a display surface should treat as running, right now.
    ///
    /// Read-only by construction: it takes a snapshot and returns a subset, so it
    /// cannot persist its own filtering. Stale records are cleaned up by the app on
    /// launch/foreground and by the intents; here they are only hidden.
    ///
    /// `liveAlarmIDs` is `nil` when AlarmKit could not be queried, in which case the
    /// time-based checks stand alone.
    static func visible(
        in stored: [RunningTimer],
        liveAlarmIDs: Set<UUID>?,
        now: Date
    ) -> [RunningTimer] {
        stored.filter { timer in
            if let liveAlarmIDs, !liveAlarmIDs.contains(timer.id) { return false }
            if !timer.isPaused && timer.isFinished(at: now) { return false }
            if timer.endDate.addingTimeInterval(1) < now { return false }
            return true
        }
    }

    /// Timers whose alarm is gone from AlarmKit and that are therefore finished or
    /// cancelled.
    ///
    /// AlarmKit is the source of truth for liveness: counting down, paused and
    /// alerting alarms are all present in the live list and leave it only once
    /// stopped or cancelled. The `seen`-or-`finished` requirement is what protects a
    /// freshly started timer whose alarm has not been scheduled yet — it is neither,
    /// so it survives.
    static func dismissed(
        in timers: [RunningTimer],
        liveAlarmIDs: Set<UUID>,
        seenIDs: Set<UUID>,
        now: Date
    ) -> [RunningTimer] {
        timers.filter { timer in
            !liveAlarmIDs.contains(timer.id)
                && (seenIDs.contains(timer.id) || timer.isFinished(at: now))
        }
    }

    /// Timers that exist on disk with a live alarm but are unknown in memory — the
    /// auto-restart iteration `StopTimerIntent` writes from another process, or a
    /// timer started from the widget. Without adopting these the home screen misses
    /// them until the next foregrounding, and the next save erases them.
    static func adoptable(
        inMemory: [RunningTimer],
        disk: [RunningTimer],
        liveAlarmIDs: Set<UUID>
    ) -> [RunningTimer] {
        let known = Set(inMemory.map(\.id))
        return disk.filter { liveAlarmIDs.contains($0.id) && !known.contains($0.id) }
    }

    /// `inMemory` with each timer's pause state reconciled against AlarmKit's.
    ///
    /// `disk` is authoritative for *when* a transition happened. `PauseTimerIntent`
    /// and `ResumeTimerIntent` run in another process — they are what the Lock
    /// Screen buttons invoke — and stamp the real instant there. This process hears
    /// about it only when `alarmUpdates` next gets to run, which, if the app was
    /// suspended at the tap, is seconds later. Stamping `now` at that point moved
    /// `pausedAt` forward by the entire suspension and saved it over the intent's
    /// correct value, so Home showed several seconds less than the Live Activity for
    /// the rest of the timer's life. On resume the same stale `pausedAt` made the
    /// `startDate` shift too small, and the error compounded per pause cycle.
    ///
    /// `now` is therefore a last resort: it is used only for a transition that no
    /// one recorded, which is a state AlarmKit reached without going through either
    /// intent.
    static func reconcilingPauseState(
        inMemory: [RunningTimer],
        disk: [RunningTimer],
        pausedAlarmIDs: Set<UUID>,
        countingAlarmIDs: Set<UUID>,
        now: Date
    ) -> [RunningTimer] {
        let recorded = Dictionary(disk.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return inMemory.map { timer in
            if pausedAlarmIDs.contains(timer.id) {
                guard !timer.isPaused else { return timer }
                if let stored = recorded[timer.id], stored.isPaused { return stored }
                return timer.paused(at: now) ?? timer
            }
            if countingAlarmIDs.contains(timer.id) {
                guard timer.isPaused else { return timer }
                if let stored = recorded[timer.id], !stored.isPaused { return stored }
                return timer.resumed(at: now) ?? timer
            }
            return timer
        }
    }

    /// Union by id, in-memory order first. Used before persisting: another process
    /// may have added a timer this array does not know about, and saving the stale
    /// array would drop it.
    static func merging(inMemory: [RunningTimer], disk: [RunningTimer]) -> [RunningTimer] {
        let known = Set(inMemory.map(\.id))
        return inMemory + disk.filter { !known.contains($0.id) }
    }

    /// Removal applied to the *disk* snapshot rather than to the in-memory array, so
    /// a timer written by another process between the last load and now survives,
    /// and so the dismissed records are actually cleared from shared storage instead
    /// of being read straight back in.
    static func removingDismissed(disk: [RunningTimer], dismissedIDs: Set<UUID>) -> [RunningTimer] {
        disk.filter { !dismissedIDs.contains($0.id) }
    }
}
