//
//  PresetsRepo.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 23. 4. 2026..
//

import Foundation

nonisolated protocol PresetsRepo: Sendable {
    func loadUserPresets() -> [TimerPreset]
    func saveUserPresets(_ presets: [TimerPreset])
    func loadHiddenBuiltInIDs() -> Set<UUID>
    func saveHiddenBuiltInIDs(_ ids: Set<UUID>)
    func allPresets() -> [TimerPreset]
}

nonisolated final class PresetsRepoImpl: PresetsRepo {
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

    func allPresets() -> [TimerPreset] {
        let hidden = loadHiddenBuiltInIDs()
        let visibleBuiltIns = TimerPreset.builtIns.filter { !hidden.contains($0.id) }
        return visibleBuiltIns + loadUserPresets()
    }
}
