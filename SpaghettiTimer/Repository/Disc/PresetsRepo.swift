//
//  PresetsRepo.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 23. 4. 2026..
//

import Foundation

nonisolated protocol PresetsRepo: Sendable {
    /// Presets in the storage format used before unpinning deleted them: user
    /// presets only, with built-ins shown unless their id was hidden.
    /// `allPresets()` still reads it until the first `savePresets(_:)`.
    func loadUserPresets() -> [TimerPreset]
    func saveUserPresets(_ presets: [TimerPreset])
    func loadHiddenBuiltInIDs() -> Set<UUID>
    func saveHiddenBuiltInIDs(_ ids: Set<UUID>)
    /// Whether the dynamic "To next hour" tile is pinned to the home grid.
    /// It carries no stored duration, so it lives outside `userPresets`.
    func loadNextHourPinned() -> Bool
    func saveNextHourPinned(_ pinned: Bool)
    /// The home grid's presets in order, built-ins included. Before anything has
    /// been saved, a fresh install gets the built-in roster.
    func allPresets() -> [TimerPreset]
}

/// Adds the write the presets use case needs. Kept apart from `PresetsRepo` so
/// read-only stand-ins don't have to implement it.
nonisolated protocol PresetsEditingRepo: PresetsRepo {
    /// Replaces the whole list. A preset left out is deleted, built-in or not.
    func savePresets(_ presets: [TimerPreset])
}

nonisolated final class PresetsRepoImpl: PresetsEditingRepo {
    nonisolated(unsafe) private let defaults: UserDefaults

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
    }

    func loadUserPresets() -> [TimerPreset] {
        guard let data = defaults.data(forKey: AppGroupKey.userPresets) else { return [] }
        return (try? JSONDecoder().decode([TimerPreset].self, from: data)) ?? []
    }

    func saveUserPresets(_ presets: [TimerPreset]) {
        let user = presets.filter { !$0.isBuiltIn }
        if let data = try? JSONEncoder().encode(user) {
            defaults.set(data, forKey: AppGroupKey.userPresets)
        }
    }

    func loadHiddenBuiltInIDs() -> Set<UUID> {
        guard let data = defaults.data(forKey: AppGroupKey.hiddenBuiltInPresets) else { return [] }
        return (try? JSONDecoder().decode(Set<UUID>.self, from: data)) ?? []
    }

    func saveHiddenBuiltInIDs(_ ids: Set<UUID>) {
        if let data = try? JSONEncoder().encode(ids) {
            defaults.set(data, forKey: AppGroupKey.hiddenBuiltInPresets)
        }
    }

    func loadNextHourPinned() -> Bool {
        defaults.bool(forKey: AppGroupKey.nextHourPinned)
    }

    func saveNextHourPinned(_ pinned: Bool) {
        defaults.set(pinned, forKey: AppGroupKey.nextHourPinned)
    }

    func allPresets() -> [TimerPreset] {
        if let data = defaults.data(forKey: AppGroupKey.presets),
           let presets = try? JSONDecoder().decode([TimerPreset].self, from: data) {
            return presets
        }
        // Nothing saved in the current format yet: a fresh install, or an install
        // from before unpinning deleted presets. Nothing is written here, because
        // the widget and the intents call this too and must only read.
        let hidden = loadHiddenBuiltInIDs()
        let visibleBuiltIns = TimerPreset.builtIns.filter { !hidden.contains($0.id) }
        return visibleBuiltIns + loadUserPresets()
    }

    func savePresets(_ presets: [TimerPreset]) {
        if let data = try? JSONEncoder().encode(presets) {
            defaults.set(data, forKey: AppGroupKey.presets)
        }
    }
}
