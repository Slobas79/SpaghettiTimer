//
//  TimerPresetsUseCase.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 23. 4. 2026..
//

import Foundation
import WidgetKit

@MainActor
protocol TimerPresetsUseCase: AnyObject {
    var presets: [TimerPreset] { get }
    var onChange: (() -> Void)? { get set }

    func reload()
    func addPreset(name: String, duration: TimeInterval)
    func updatePreset(_ preset: TimerPreset, name: String, duration: TimeInterval)
    func pinPreset(_ preset: TimerPreset)
    func deletePreset(_ preset: TimerPreset)
}

@MainActor
final class TimerPresetsUseCaseImpl: TimerPresetsUseCase {
    private(set) var presets: [TimerPreset] = []
    var onChange: (() -> Void)?

    private let repo: PresetsRepo

    init(repo: PresetsRepo) {
        self.repo = repo
        reload()
    }

    func reload() {
        presets = repo.allPresets()
        onChange?()
    }

    func addPreset(name: String, duration: TimeInterval) {
        var user = repo.loadUserPresets()
        user.insert(TimerPreset(name: name, duration: duration, isBuiltIn: false), at: 0)
        repo.saveUserPresets(user)
        reload()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func updatePreset(_ preset: TimerPreset, name: String, duration: TimeInterval) {
        var user = repo.loadUserPresets()
        if let idx = user.firstIndex(where: { $0.id == preset.id }) {
            user[idx].name = name
            user[idx].duration = duration
        } else {
            // Built-in: hide the original, insert an edited user copy keeping the same id.
            var hidden = repo.loadHiddenBuiltInIDs()
            hidden.insert(preset.id)
            repo.saveHiddenBuiltInIDs(hidden)
            user.insert(TimerPreset(id: preset.id, name: name, duration: duration, isBuiltIn: false), at: 0)
        }
        repo.saveUserPresets(user)
        reload()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func pinPreset(_ preset: TimerPreset) {
        var user = repo.loadUserPresets()
        guard !user.contains(where: { $0.id == preset.id }) else { return }
        user.insert(
            TimerPreset(id: preset.id, name: preset.name, duration: preset.duration, isBuiltIn: false),
            at: 0
        )
        repo.saveUserPresets(user)
        reload()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func deletePreset(_ preset: TimerPreset) {
        if preset.isBuiltIn {
            var hidden = repo.loadHiddenBuiltInIDs()
            hidden.insert(preset.id)
            repo.saveHiddenBuiltInIDs(hidden)
        } else {
            var user = repo.loadUserPresets()
            user.removeAll { $0.id == preset.id }
            repo.saveUserPresets(user)
        }
        reload()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
