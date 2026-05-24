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

    @ObservationIgnored private let presetsUseCase: TimerPresetsUseCase
    @ObservationIgnored private let runningUseCase: RunningTimersUseCase

    init(presetsUseCase: TimerPresetsUseCase, runningUseCase: RunningTimersUseCase) {
        self.presetsUseCase = presetsUseCase
        self.runningUseCase = runningUseCase

        presets = presetsUseCase.presets
        running = runningUseCase.running

        presetsUseCase.onChange = { [weak self] in
            guard let self else { return }
            self.presets = presetsUseCase.presets
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

    func addPreset(name: String, duration: TimeInterval) {
        presetsUseCase.addPreset(name: name, duration: duration)
    }

    func createTimer(name: String, duration: TimeInterval, pinned: Bool) {
        if pinned {
            presetsUseCase.addPreset(name: name, duration: duration)
        } else {
            let ephemeral = TimerPreset(name: name, duration: duration, isBuiltIn: false)
            runningUseCase.start(preset: ephemeral)
        }
    }

    func updateTimer(_ preset: TimerPreset, name: String, duration: TimeInterval) {
        presetsUseCase.updatePreset(preset, name: name, duration: duration)
    }

    func deletePreset(_ preset: TimerPreset) {
        presetsUseCase.deletePreset(preset)
    }

    func pin(_ preset: TimerPreset) {
        presetsUseCase.pinPreset(preset)
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
