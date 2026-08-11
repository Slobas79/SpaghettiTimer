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

    @ObservationIgnored private let presetsUseCase: TimerPresetsUseCase
    @ObservationIgnored private let runningUseCase: RunningTimersUseCase

    init(presetsUseCase: TimerPresetsUseCase, runningUseCase: RunningTimersUseCase) {
        self.presetsUseCase = presetsUseCase
        self.runningUseCase = runningUseCase

        presets = presetsUseCase.presets
        running = runningUseCase.running
        isNextHourPinned = presetsUseCase.isNextHourPinned

        presetsUseCase.onChange = { [weak self] in
            guard let self else { return }
            self.presets = presetsUseCase.presets
            self.isNextHourPinned = presetsUseCase.isNextHourPinned
        }
        runningUseCase.onChange = { [weak self] in
            guard let self else { return }
            self.running = runningUseCase.running
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

    func createTimer(name: String, duration: TimeInterval, pinned: Bool, autoRestartDelaySeconds: TimeInterval? = nil) {
        if pinned {
            presetsUseCase.addPreset(name: name, duration: duration, autoRestartDelaySeconds: autoRestartDelaySeconds)
        } else {
            let ephemeral = TimerPreset(
                name: name,
                duration: duration,
                isBuiltIn: false,
                autoRestartDelaySeconds: autoRestartDelaySeconds
            )
            runningUseCase.start(preset: ephemeral)
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
        runningUseCase.start(preset: NextHour.preset(at: Date()))
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

    /// User-created (pinned) presets, excluding built-ins — this is what the
    /// free pin cap counts against.
    var userPresetCount: Int {
        presets.filter { !$0.isBuiltIn }.count
    }

    func tick(at date: Date) {}
}
