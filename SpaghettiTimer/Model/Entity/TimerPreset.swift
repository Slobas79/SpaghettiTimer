//
//  TimerPreset.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 23. 4. 2026..
//

import Foundation

nonisolated struct TimerPreset: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var duration: TimeInterval
    let isBuiltIn: Bool
    var autoRestartDelaySeconds: TimeInterval?

    init(
        id: UUID = UUID(),
        name: String,
        duration: TimeInterval,
        isBuiltIn: Bool = false,
        autoRestartDelaySeconds: TimeInterval? = nil
    ) {
        self.id = id
        self.name = name
        self.duration = duration
        self.isBuiltIn = isBuiltIn
        self.autoRestartDelaySeconds = autoRestartDelaySeconds
    }
}

nonisolated extension TimerPreset {
    /// A user-owned copy of this preset, for pinning a built-in or ephemeral preset
    /// to the home grid. Keeps the same `id` so a running timer started from the
    /// original still matches its tile.
    ///
    /// Carries `autoRestartDelaySeconds` forward — pinning must not quietly turn a
    /// repeating timer into a one-shot, which is what it used to do.
    func pinnedCopy() -> TimerPreset {
        TimerPreset(
            id: id,
            name: name,
            duration: duration,
            isBuiltIn: false,
            autoRestartDelaySeconds: autoRestartDelaySeconds
        )
    }
}

nonisolated extension TimerPreset {
    /// One flagship example per target group — cooking, gym, focus, self-care — so a
    /// fresh install's grid shows what the app is *for*, rather than four arbitrary
    /// durations named after themselves.
    ///
    /// The ids are load-bearing and must not change: `presets.hiddenBuiltIns` stores
    /// them, and `Analytics.safePresetName` uses membership here as its allowlist for
    /// reporting a preset name off-device.
    static let builtIns: [TimerPreset] = [
        TimerPreset(id: UUID(uuidString: "11111111-1111-1111-1111-000000000001")!, name: "Al Dente",  duration: 480,  isBuiltIn: true),
        TimerPreset(id: UUID(uuidString: "11111111-1111-1111-1111-000000000002")!, name: "Rest Set",  duration: 90,   isBuiltIn: true),
        TimerPreset(id: UUID(uuidString: "11111111-1111-1111-1111-000000000003")!, name: "Pomodoro",  duration: 1500, isBuiltIn: true),
        TimerPreset(id: UUID(uuidString: "11111111-1111-1111-1111-000000000004")!, name: "Power Nap", duration: 1200, isBuiltIn: true)
    ]
}
