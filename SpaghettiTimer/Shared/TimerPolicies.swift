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
