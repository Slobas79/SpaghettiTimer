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
    static let widgetStartRefusedForPermission = "runningTimers.widgetStartRefusedForPermission"
}

/// A widget start that AlarmKit permission turned away, left for the app to explain.
///
/// The widget has no UI to explain it with. `StartTimerIntent` sets the flag and
/// hands off to the app, and the app clears it on becoming active and shows its
/// "Alarms are turned off" alert. It lives in shared storage rather than being
/// passed along because the app may not be running yet when the hand-off happens.
nonisolated enum WidgetStartRefusal {
    static func record(in defaults: UserDefaults = AppGroup.defaults) {
        defaults.set(true, forKey: AppGroupKey.widgetStartRefusedForPermission)
    }

    /// Whether a refusal was waiting. Clears it, so each refusal is explained once.
    static func consume(in defaults: UserDefaults = AppGroup.defaults) -> Bool {
        let was = defaults.bool(forKey: AppGroupKey.widgetStartRefusedForPermission)
        if was { defaults.removeObject(forKey: AppGroupKey.widgetStartRefusedForPermission) }
        return was
    }
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
