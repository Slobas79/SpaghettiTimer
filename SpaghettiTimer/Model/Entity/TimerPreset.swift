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
    static let builtIns: [TimerPreset] = [
        TimerPreset(id: UUID(uuidString: "11111111-1111-1111-1111-000000000001")!, name: "1 min",  duration: 60,   isBuiltIn: true),
        TimerPreset(id: UUID(uuidString: "11111111-1111-1111-1111-000000000002")!, name: "5 min",  duration: 300,  isBuiltIn: true),
        TimerPreset(id: UUID(uuidString: "11111111-1111-1111-1111-000000000003")!, name: "10 min", duration: 600,  isBuiltIn: true),
        TimerPreset(id: UUID(uuidString: "11111111-1111-1111-1111-000000000004")!, name: "25 min", duration: 1500, isBuiltIn: true)
    ]
}
