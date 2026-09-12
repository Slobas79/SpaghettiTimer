//
//  AlarmAuthorization.swift
//  SpaghettiTimer
//
//  The permission gate every start path goes through.
//
//  A timer must not reach the repo, Home, or the analytics stream before AlarmKit
//  permission is in hand: without it no alarm is ever scheduled, so a "running"
//  timer would count down to nothing and ring for no one. Asking first — and
//  dropping the start when the answer is no — is what keeps the visible list and
//  AlarmKit's list the same list.
//

import AlarmKit
import Foundation

/// AlarmKit's authorization states, mirrored so callers and tests can reason about
/// permission without touching `AlarmManager` (which prompts the user for real).
nonisolated enum AlarmAuthorization: Sendable, Equatable {
    case notDetermined
    case denied
    case authorized
}

nonisolated protocol AlarmAuthorizing: Sendable {
    /// Where permission stands right now, read without prompting.
    ///
    /// Reconciliation needs this and cannot use `resolve()`: that prompts while the
    /// state is `.notDetermined`, and a system dialog on every foreground is not a
    /// reconciliation.
    var current: AlarmAuthorization { get }

    /// Prompts once when the state is `.notDetermined`, then reports where it settled.
    func resolve() async -> AlarmAuthorization
}

nonisolated struct AlarmKitAuthorizer: AlarmAuthorizing {
    init() {}

    var current: AlarmAuthorization {
        AlarmAuthorization(AlarmManager.shared.authorizationState)
    }

    func resolve() async -> AlarmAuthorization {
        let manager = AlarmManager.shared
        let current = self.current
        guard current == .notDetermined else { return current }
        // A thrown request is not a grant — treat it as a refusal rather than
        // letting the timer through on a shrug.
        guard let settled = try? await manager.requestAuthorization() else { return .denied }
        return AlarmAuthorization(settled)
    }
}

nonisolated extension AlarmAuthorization {
    init(_ state: AlarmManager.AuthorizationState) {
        switch state {
        case .notDetermined: self = .notDetermined
        case .denied: self = .denied
        case .authorized: self = .authorized
        @unknown default: self = .denied
        }
    }
}

nonisolated extension AlarmAuthorization {
    /// Whether a start may be attempted from a process that cannot present the
    /// permission prompt — the widget extension running `StartTimerIntent`.
    ///
    /// `.notDetermined` is not a refusal here. A widget extension has no UI to ask
    /// with, and AlarmKit reports `.notDetermined` from that process even when the
    /// containing app already holds the grant — gating a widget tap on it is what
    /// made the tiles do nothing at all. Only an explicit `.denied` stops the start;
    /// otherwise the attempt goes to AlarmKit, which is the real arbiter, and the
    /// timer reaches shared storage only once the alarm is actually scheduled.
    var allowsUnpromptedStart: Bool { self != .denied }

    /// Whether a reconciliation pass should clear the running list outright.
    ///
    /// Permission can be turned off in Settings while the app is backgrounded, and a
    /// timer scheduled before that stays in `AlarmManager.shared.alarms` with its
    /// Live Activity intact — it simply never alerts. The liveness pass can therefore
    /// never see it as dismissed, so it counts down to nothing on Home, the Lock
    /// Screen and in the Dynamic Island until permission comes back. Only permission
    /// state can tell us, so only it can clear them.
    ///
    /// Only an explicit `.denied` does. `.notDetermined` must not: it is the
    /// pre-prompt state, and AlarmKit also reports it from a process that holds no
    /// grant of its own — the same quirk `allowsUnpromptedStart` exists for — so
    /// treating it as a revocation would delete timers nobody revoked anything for.
    var revokesScheduledTimers: Bool { self == .denied }
}
