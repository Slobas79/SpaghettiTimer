//
//  TimersViewModel.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 23. 4. 2026..
//

import Foundation
import Observation

@MainActor
@Observable
final class TimersViewModel {
    private(set) var presets: [TimerPreset] = []
    private(set) var running: [RunningTimer] = []
    /// Drives the dynamic "To next hour" tile in the first grid cell.
    private(set) var isNextHourPinned: Bool = false
    /// User presets ever pinned — what the free pin cap counts against.
    private(set) var lifetimePinCount: Int = 0
    /// Raised when a start was dropped for want of AlarmKit permission. Settable so
    /// the alert's binding can clear it on dismiss.
    var isAlarmPermissionDenied: Bool = false

    @ObservationIgnored private let presetsUseCase: TimerPresetsUseCase
    @ObservationIgnored private let runningUseCase: RunningTimersUseCase

    init(presetsUseCase: TimerPresetsUseCase, runningUseCase: RunningTimersUseCase) {
        self.presetsUseCase = presetsUseCase
        self.runningUseCase = runningUseCase

        presets = presetsUseCase.presets
        running = runningUseCase.running
        isNextHourPinned = presetsUseCase.isNextHourPinned
        lifetimePinCount = presetsUseCase.lifetimePinCount

        presetsUseCase.onChange = { [weak self] in
            guard let self else { return }
            self.presets = presetsUseCase.presets
            self.isNextHourPinned = presetsUseCase.isNextHourPinned
            self.lifetimePinCount = presetsUseCase.lifetimePinCount
        }
        runningUseCase.onChange = { [weak self] in
            guard let self else { return }
            self.running = runningUseCase.running
        }
        runningUseCase.onAuthorizationDenied = { [weak self] in
            self?.isAlarmPermissionDenied = true
        }
    }

    func refresh() {
        presetsUseCase.reload()
        runningUseCase.reload()
    }

    func start(_ preset: TimerPreset) {
        runningUseCase.start(preset: preset)
    }

    func stop(_ timer: RunningTimer) {
        runningUseCase.stop(timer)
    }

    func pause(_ timer: RunningTimer) {
        runningUseCase.pause(timer)
    }

    func resume(_ timer: RunningTimer) {
        runningUseCase.resume(timer)
    }

    func addPreset(name: String, duration: TimeInterval, autoRestartDelaySeconds: TimeInterval? = nil) {
        presetsUseCase.addPreset(name: name, duration: duration, autoRestartDelaySeconds: autoRestartDelaySeconds)
    }

    /// The sheet's action button says "Start", so the timer runs either way —
    /// pinning only decides whether it also sticks around as a home tile.
    /// `mode` only tags the `timer_start` analytics event.
    ///
    /// The returned task answers whether the timer really started — false when
    /// the start was dropped for want of AlarmKit permission — so a free try is
    /// only spent on a timer that ran.
    @discardableResult
    func createTimer(
        name: String,
        duration: TimeInterval,
        pinned: Bool,
        autoRestartDelaySeconds: TimeInterval? = nil,
        mode: AnalyticsTimerMode = .duration
    ) -> Task<Bool, Never> {
        let preset: TimerPreset
        if pinned {
            preset = presetsUseCase.addPreset(name: name, duration: duration, autoRestartDelaySeconds: autoRestartDelaySeconds)
        } else {
            preset = TimerPreset(
                name: name,
                duration: duration,
                isBuiltIn: false,
                autoRestartDelaySeconds: autoRestartDelaySeconds
            )
        }
        let start = runningUseCase.start(preset: preset, mode: mode)
        return Task { [runningUseCase] in
            await start.value
            return runningUseCase.running.contains { $0.presetID == preset.id }
        }
    }

    func deletePreset(_ preset: TimerPreset) {
        presetsUseCase.deletePreset(preset)
    }

    func pin(_ preset: TimerPreset) {
        presetsUseCase.pinPreset(preset)
    }

    // MARK: - "To next hour" tile

    func setNextHourPinned(_ pinned: Bool) {
        presetsUseCase.setNextHourPinned(pinned)
    }

    /// Starts a one-shot timer ending at the next full hour, recomputed now —
    /// the tile stores no duration of its own.
    func startNextHour() {
        runningUseCase.start(preset: NextHour.preset(at: Date()), mode: .nextHour)
    }

    struct TileItem: Identifiable {
        let preset: TimerPreset
        var id: UUID { preset.id }
    }

    var runningRows: [RunningTimer] {
        running.sorted { $0.startDate < $1.startDate }
    }

    var presetTiles: [TileItem] {
        presets.map { TileItem(preset: $0) }
    }

    func tick(at date: Date) {}
}
