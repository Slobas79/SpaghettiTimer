//
//  AppGroup.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 23. 4. 2026..
//

import Foundation

nonisolated enum AppGroup {
    static let id = "group.sloba.SpaghettiTimer"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: id) ?? .standard
    }
}

nonisolated enum AppGroupKey {
    static let userPresets = "presets.user"
    static let hiddenBuiltInPresets = "presets.hiddenBuiltIns"
    static let nextHourPinned = "presets.nextHourPinned"
    static let runningTimers = "runningTimers"
    static let userCancelledTimers = "runningTimers.userCancelled"
}

nonisolated enum UserCancelledTimers {
    static func mark(_ id: UUID) {
        let defaults = AppGroup.defaults
        var ids = load(from: defaults)
        ids.insert(id)
        save(ids, to: defaults)
    }

    static func consume(_ id: UUID) -> Bool {
        let defaults = AppGroup.defaults
        var ids = load(from: defaults)
        let was = ids.remove(id) != nil
        save(ids, to: defaults)
        return was
    }

    static func contains(_ id: UUID) -> Bool {
        load(from: AppGroup.defaults).contains(id)
    }

    private static func load(from defaults: UserDefaults) -> Set<UUID> {
        guard let data = defaults.data(forKey: AppGroupKey.userCancelledTimers) else { return [] }
        return (try? JSONDecoder().decode(Set<UUID>.self, from: data)) ?? []
    }

    private static func save(_ ids: Set<UUID>, to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(ids) {
            defaults.set(data, forKey: AppGroupKey.userCancelledTimers)
        }
    }
}
