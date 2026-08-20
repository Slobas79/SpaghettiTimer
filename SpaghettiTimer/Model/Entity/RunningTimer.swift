//
//  RunningTimer.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 23. 4. 2026..
//

import Foundation

nonisolated struct RunningTimer: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let presetID: UUID
    let name: String
    let startDate: Date
    let duration: TimeInterval
    let pausedAt: Date?
    let autoRestartDelaySeconds: TimeInterval?

    var endDate: Date { startDate.addingTimeInterval(duration) }

    var isPaused: Bool { pausedAt != nil }

    func remaining(at date: Date = Date()) -> TimeInterval {
        max(0, endDate.timeIntervalSince(pausedAt ?? date))
    }

    func isFinished(at date: Date = Date()) -> Bool {
        date >= endDate
    }

    init(id: UUID, presetID: UUID, name: String, startDate: Date, duration: TimeInterval, pausedAt: Date? = nil, autoRestartDelaySeconds: TimeInterval? = nil) {
        self.id = id
        self.presetID = presetID
        self.name = name
        self.startDate = startDate
        self.duration = duration
        self.pausedAt = pausedAt
        self.autoRestartDelaySeconds = autoRestartDelaySeconds
    }
}

// MARK: - Lifecycle transitions
//
// Every state change goes through one of these. They exist because this struct is
// immutable and was previously rebuilt through the memberwise initializer at six
// separate call sites — and `autoRestartDelaySeconds` defaults to `nil`, so any
// caller that forgot to forward it silently turned a repeating timer into a
// one-shot. That is exactly how auto-restart broke (see the pause/resume intents
// before commit 91cfd9d). Carrying every field forward in one place makes the
// omission unrepresentable rather than merely tested.
//
// Add new fields here, not at the call sites.

nonisolated extension RunningTimer {
    /// A paused copy, or `nil` if this timer is already paused.
    func paused(at now: Date) -> RunningTimer? {
        guard !isPaused else { return nil }
        return RunningTimer(
            id: id,
            presetID: presetID,
            name: name,
            startDate: startDate,
            duration: duration,
            pausedAt: now,
            autoRestartDelaySeconds: autoRestartDelaySeconds
        )
    }

    /// A resumed copy, or `nil` if this timer is not paused. `startDate` is shifted
    /// forward by the elapsed pause duration so `remaining` is unchanged across the
    /// pause — which is what keeps `endDate` (and therefore the alarm) accurate.
    func resumed(at now: Date) -> RunningTimer? {
        guard let pausedAt else { return nil }
        let pauseDuration = now.timeIntervalSince(pausedAt)
        return RunningTimer(
            id: id,
            presetID: presetID,
            name: name,
            startDate: startDate.addingTimeInterval(pauseDuration),
            duration: duration,
            pausedAt: nil,
            autoRestartDelaySeconds: autoRestartDelaySeconds
        )
    }

    /// The next iteration of an auto-restarting timer.
    ///
    /// `startDate` is `delay` seconds in the future: the cooldown is presented as a
    /// single AlarmKit countdown of `duration + delay`, so `endDate` lands exactly
    /// when the alarm fires.
    ///
    /// `autoRestartDelaySeconds` is set to `delay` rather than copied from `self`.
    /// That is deliberate: when the previous record was recovered from the alarm's
    /// baked-in parameters its own delay may be `nil`, and copying it would end the
    /// chain after one more iteration.
    func nextIteration(id newID: UUID, delay: TimeInterval, now: Date) -> RunningTimer {
        RunningTimer(
            id: newID,
            presetID: presetID,
            name: name,
            startDate: now.addingTimeInterval(delay),
            duration: duration,
            autoRestartDelaySeconds: delay
        )
    }
}
