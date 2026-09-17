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
    /// Returns the newly created preset so the caller can start it right away.
    @discardableResult
    func addPreset(name: String, duration: TimeInterval, autoRestartDelaySeconds: TimeInterval?) -> TimerPreset
    func pinPreset(_ preset: TimerPreset)
    func deletePreset(_ preset: TimerPreset)
    func setNextHourPinned(_ pinned: Bool)
}

@MainActor
final class TimerPresetsUseCaseImpl: TimerPresetsUseCase {
    private(set) var presets: [TimerPreset] = []
    private(set) var isNextHourPinned: Bool = false
    var onChange: (() -> Void)?

    private let repo: PresetsEditingRepo
    private let analytics: AnalyticsRepo

    init(repo: PresetsEditingRepo, analytics: AnalyticsRepo = NoOpAnalyticsRepo()) {
        self.repo = repo
        self.analytics = analytics
        reload()
    }

    func reload() {
        presets = repo.allPresets()
        isNextHourPinned = repo.loadNextHourPinned()
        onChange?()
    }

    @discardableResult
    func addPreset(name: String, duration: TimeInterval, autoRestartDelaySeconds: TimeInterval? = nil) -> TimerPreset {
        let preset = TimerPreset(
            name: name,
            duration: duration,
            isBuiltIn: false,
            autoRestartDelaySeconds: autoRestartDelaySeconds
        )
        var all = repo.allPresets()
        all.append(preset)
        repo.savePresets(all)
        analytics.log(.presetCreate(durationSeconds: Int(duration), autoRestart: autoRestartDelaySeconds != nil))
        reload()
        WidgetCenter.shared.reloadAllTimelines()
        return preset
    }

    func pinPreset(_ preset: TimerPreset) {
        var all = repo.allPresets()
        guard !all.contains(where: { $0.id == preset.id }) else { return }
        // `pinnedCopy()` carries every field forward — pinning must not quietly
        // turn a repeating timer into a one-shot.
        all.append(preset.pinnedCopy())
        repo.savePresets(all)
        analytics.log(.presetPin())
        reload()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Deletes the preset from storage. Built-ins are deleted too, not hidden.
    func deletePreset(_ preset: TimerPreset) {
        var all = repo.allPresets()
        all.removeAll { $0.id == preset.id }
        repo.savePresets(all)
        analytics.log(.presetDelete(isBuiltIn: preset.isBuiltIn))
        reload()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Shows / hides the dynamic "To next hour" tile. It stores no duration, so
    /// it never lands in the stored preset list and never reaches the widget — the
    /// countdown only makes sense against a live clock.
    func setNextHourPinned(_ pinned: Bool) {
        guard pinned != repo.loadNextHourPinned() else { return }
        repo.saveNextHourPinned(pinned)
        analytics.log(pinned ? .presetPin() : .presetDelete(isBuiltIn: false))
        reload()
    }
}
