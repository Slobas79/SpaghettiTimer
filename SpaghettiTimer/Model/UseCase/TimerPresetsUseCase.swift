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
    /// User presets pinned over the life of the install — what the free pin cap
    /// counts. Unpinning never lowers it, so deleting a pin doesn't free a slot.
    var lifetimePinCount: Int { get }
    var onChange: (() -> Void)? { get set }

    func reload()
    /// Returns the newly created preset so the caller can start it right away.
    @discardableResult
    func addPreset(name: String, duration: TimeInterval, autoRestartDelaySeconds: TimeInterval?) -> TimerPreset
    func pinPreset(_ preset: TimerPreset)
    func deletePreset(_ preset: TimerPreset)
    func setNextHourPinned(_ pinned: Bool)
    #if DEBUG
    /// QA only, compiled out of Release: hands the free pins back. User presets
    /// still on Home are counted again straight away, so unpin them first.
    func resetLifetimePinCount()
    #endif
}

@MainActor
final class TimerPresetsUseCaseImpl: TimerPresetsUseCase {
    private(set) var presets: [TimerPreset] = []
    private(set) var isNextHourPinned: Bool = false
    private(set) var lifetimePinCount: Int = 0
    var onChange: (() -> Void)?

    private let repo: PresetsEditingRepo
    private let pinAllowance: PinAllowanceRepo
    private let analytics: AnalyticsRepo

    init(repo: PresetsEditingRepo,
         pinAllowance: PinAllowanceRepo = InMemoryPinAllowanceRepo(),
         analytics: AnalyticsRepo = NoOpAnalyticsRepo()) {
        self.repo = repo
        self.pinAllowance = pinAllowance
        self.analytics = analytics
        reload()
    }

    func reload() {
        presets = repo.allPresets()
        isNextHourPinned = repo.loadNextHourPinned()
        lifetimePinCount = seededLifetimePinCount()
        onChange?()
    }

    /// Installs from before the lifetime count already have pins on the grid, and
    /// those were spent too — otherwise unpinning one would hand back a slot that
    /// was never recorded.
    private func seededLifetimePinCount() -> Int {
        let stored = pinAllowance.loadLifetimePinCount()
        let onGrid = presets.filter { !$0.isBuiltIn }.count
        guard onGrid > stored else { return stored }
        pinAllowance.saveLifetimePinCount(onGrid)
        return onGrid
    }

    #if DEBUG
    func resetLifetimePinCount() {
        pinAllowance.saveLifetimePinCount(0)
        reload()
    }
    #endif

    private func recordPin() {
        pinAllowance.saveLifetimePinCount(pinAllowance.loadLifetimePinCount() + 1)
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
        recordPin()
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
        recordPin()
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
        analytics.log(pinned ? .presetPin(kind: .nextHour) : .presetDelete(isBuiltIn: false, kind: .nextHour))
        reload()
    }
}
