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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        presetID = try container.decode(UUID.self, forKey: .presetID)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        startDate = try container.decode(Date.self, forKey: .startDate)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        pausedAt = try container.decodeIfPresent(Date.self, forKey: .pausedAt)
        autoRestartDelaySeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .autoRestartDelaySeconds)
    }
}
