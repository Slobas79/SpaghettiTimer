//
//  RunningTimersRepo.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 23. 4. 2026..
//

import Foundation

nonisolated protocol RunningTimersRepo: Sendable {
    func load() -> [RunningTimer]
    func save(_ timers: [RunningTimer])
}

nonisolated final class RunningTimersRepoImpl: RunningTimersRepo {
    nonisolated(unsafe) private let defaults: UserDefaults

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
    }

    func load() -> [RunningTimer] {
        guard let data = defaults.data(forKey: AppGroupKey.runningTimers) else { return [] }
        return (try? JSONDecoder().decode([RunningTimer].self, from: data)) ?? []
    }

    func save(_ timers: [RunningTimer]) {
        if let data = try? JSONEncoder().encode(timers) {
            defaults.set(data, forKey: AppGroupKey.runningTimers)
        }
    }
}
