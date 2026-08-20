//
//  AppGroup.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 23. 4. 2026..
//

import Foundation

nonisolated enum AppGroup {
    static let id = "group.sloba.SpaghettiTimer"

    /// One shared instance for the whole process. It must be stored, not
    /// computed: `UserDefaults(suiteName:)` mints a new object per call, and
    /// KVO — which `@AppStorage` relies on — only fires for observers
    /// registered on the very instance the write went through.
    nonisolated(unsafe) static let defaults = UserDefaults(suiteName: id) ?? .standard
}

nonisolated enum AppGroupKey {
    static let userPresets = "presets.user"
    static let hiddenBuiltInPresets = "presets.hiddenBuiltIns"
    static let nextHourPinned = "presets.nextHourPinned"
    static let runningTimers = "runningTimers"
    static let userCancelledTimers = "runningTimers.userCancelled"
}

nonisolated enum UserCancelledTimers {
    // `defaults` is injectable so tests can use a scratch suite. Tests run inside the
    // host app's process, where the app's own use case is concurrently
    // read-modify-writing this same key.
    static func mark(_ id: UUID, in defaults: UserDefaults = AppGroup.defaults) {
        var ids = load(from: defaults)
        ids.insert(id)
        save(ids, to: defaults)
    }

    static func consume(_ id: UUID, in defaults: UserDefaults = AppGroup.defaults) -> Bool {
        var ids = load(from: defaults)
        let was = ids.remove(id) != nil
        save(ids, to: defaults)
        return was
    }

    static func contains(_ id: UUID, in defaults: UserDefaults = AppGroup.defaults) -> Bool {
        load(from: defaults).contains(id)
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
