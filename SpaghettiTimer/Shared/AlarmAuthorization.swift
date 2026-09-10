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
    /// Prompts once when the state is `.notDetermined`, then reports where it settled.
    func resolve() async -> AlarmAuthorization
}

nonisolated struct AlarmKitAuthorizer: AlarmAuthorizing {
    init() {}

    func resolve() async -> AlarmAuthorization {
        let manager = AlarmManager.shared
        let current = AlarmAuthorization(manager.authorizationState)
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
