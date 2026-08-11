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
    /// Whether the dynamic "To next hour" tile occupies the first grid cell.
    var isNextHourPinned: Bool { get }
    var onChange: (() -> Void)? { get set }

    func reload()
    func addPreset(name: String, duration: TimeInterval, autoRestartDelaySeconds: TimeInterval?)
    func pinPreset(_ preset: TimerPreset)
    func deletePreset(_ preset: TimerPreset)
    func setNextHourPinned(_ pinned: Bool)
}

@MainActor
final class TimerPresetsUseCaseImpl: TimerPresetsUseCase {
    private(set) var presets: [TimerPreset] = []
    private(set) var isNextHourPinned: Bool = false
    var onChange: (() -> Void)?

    private let repo: PresetsRepo
    private let analytics: AnalyticsRepo

    init(repo: PresetsRepo, analytics: AnalyticsRepo = NoOpAnalyticsRepo()) {
        self.repo = repo
        self.analytics = analytics
        reload()
    }

    func reload() {
        presets = repo.allPresets()
        isNextHourPinned = repo.loadNextHourPinned()
        onChange?()
    }

    func addPreset(name: String, duration: TimeInterval, autoRestartDelaySeconds: TimeInterval? = nil) {
        var user = repo.loadUserPresets()
        user.append(
            TimerPreset(
                name: name,
                duration: duration,
                isBuiltIn: false,
                autoRestartDelaySeconds: autoRestartDelaySeconds
            )
        )
        repo.saveUserPresets(user)
        analytics.log(.presetCreate(durationSeconds: Int(duration), autoRestart: autoRestartDelaySeconds != nil))
        reload()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func pinPreset(_ preset: TimerPreset) {
        var user = repo.loadUserPresets()
        guard !user.contains(where: { $0.id == preset.id }) else { return }
        user.append(
            TimerPreset(id: preset.id, name: preset.name, duration: preset.duration, isBuiltIn: false)
        )
        repo.saveUserPresets(user)
        analytics.log(.presetPin())
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
        analytics.log(.presetDelete(isBuiltIn: preset.isBuiltIn))
        reload()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Shows / hides the dynamic "To next hour" tile. It stores no duration, so
    /// it never lands in `userPresets` and never reaches the widget — the
    /// countdown only makes sense against a live clock.
    func setNextHourPinned(_ pinned: Bool) {
        guard pinned != repo.loadNextHourPinned() else { return }
        repo.saveNextHourPinned(pinned)
        analytics.log(pinned ? .presetPin() : .presetDelete(isBuiltIn: false))
        reload()
    }
}
