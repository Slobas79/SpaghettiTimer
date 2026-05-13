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

    func stopOldest(for preset: TimerPreset) {
        let matches = running.filter { $0.presetID == preset.id }
        let oldest = matches.min(by: { $0.startDate < $1.startDate })
        if let oldest {
            runningUseCase.stop(oldest)
        }
    }

    func pauseOldest(for preset: TimerPreset) {
        let matches = running.filter { $0.presetID == preset.id }
        let oldest = matches.min(by: { $0.startDate < $1.startDate })
        if let oldest {
            runningUseCase.pause(oldest)
        }
    }

    func resumeOldest(for preset: TimerPreset) {
        let matches = running.filter { $0.presetID == preset.id }
        let oldest = matches.min(by: { $0.startDate < $1.startDate })
        if let oldest {
            runningUseCase.resume(oldest)
        }
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

    func deletePreset(_ preset: TimerPreset) {
        presetsUseCase.deletePreset(preset)
    }

    func pin(_ preset: TimerPreset) {
        presetsUseCase.pinPreset(preset)
    }

    func runningTimers(for preset: TimerPreset) -> [RunningTimer] {
        running.filter { $0.presetID == preset.id }
    }

    struct TileItem: Identifiable {
        let preset: TimerPreset
        let isPinned: Bool
        var id: UUID { preset.id }
    }

    var tiles: [TileItem] {
        let pinnedByID = Dictionary(uniqueKeysWithValues: presets.map { ($0.id, $0) })
        var seen = Set<UUID>()
        var result: [TileItem] = []

        for timer in running where seen.insert(timer.presetID).inserted {
            if let pinned = pinnedByID[timer.presetID] {
                result.append(TileItem(preset: pinned, isPinned: true))
            } else {
                result.append(TileItem(
                    preset: TimerPreset(
                        id: timer.presetID,
                        name: timer.name,
                        duration: timer.duration,
                        isBuiltIn: false
                    ),
                    isPinned: false
                ))
            }
        }
        for preset in presets where seen.insert(preset.id).inserted {
            result.append(TileItem(preset: preset, isPinned: true))
        }
        return result
    }

    func tick(at date: Date) {}
}
