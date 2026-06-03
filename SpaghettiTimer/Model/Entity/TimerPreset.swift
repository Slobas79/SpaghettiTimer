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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        isBuiltIn = try container.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
        autoRestartDelaySeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .autoRestartDelaySeconds)
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
