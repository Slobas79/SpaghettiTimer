//
//  RunningTimersUseCase.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 23. 4. 2026..
//

import ActivityKit
import AlarmKit
import Foundation
import WidgetKit

@MainActor
protocol RunningTimersUseCase: AnyObject {
    var running: [RunningTimer] { get }
    var onChange: (() -> Void)? { get set }

    func reload()
    func start(preset: TimerPreset)
    func stop(_ timer: RunningTimer)
    func pause(_ timer: RunningTimer)
    func resume(_ timer: RunningTimer)
    func pruneFinished()
    func reconcileWithLiveActivities()
}

@MainActor
final class RunningTimersUseCaseImpl: RunningTimersUseCase {
    private(set) var running: [RunningTimer] = []
    var onChange: (() -> Void)?

    private let repo: RunningTimersRepo

    private var alarmObservationTask: Task<Void, Never>?
    private var seenAlarmIDs: Set<UUID> = []

    init(repo: RunningTimersRepo) {
        self.repo = repo
        reload()
        observeAlarmDismissals()
    }

    deinit {
        alarmObservationTask?.cancel()
    }

    private func observeAlarmDismissals() {
        alarmObservationTask = Task { [weak self] in
            for await alarms in AlarmManager.shared.alarmUpdates {
                guard let self else { return }
                let activeIDs = Set(alarms.map(\.id))
                self.seenAlarmIDs.formUnion(activeIDs)
                self.removeTimers(notIn: activeIDs)
                self.syncPauseState(from: alarms)
            }
        }
    }

    func reconcileWithLiveActivities() {
        let liveIDs = Set(
            Activity<AlarmAttributes<SpaghettiTimerMetadata>>.activities.compactMap { activity -> UUID? in
                guard let idString = activity.attributes.metadata?.alarmID else { return nil }
                return UUID(uuidString: idString)
            }
        )
        let now = Date()
        let dismissedIDs = running
            .filter { !liveIDs.contains($0.id) && !$0.isFinished(at: now) && seenAlarmIDs.contains($0.id) }
            .map(\.id)
        guard !dismissedIDs.isEmpty else { return }
        for id in dismissedIDs {
            Task { try? AlarmManager.shared.cancel(id: id) }
        }
        let dismissedSet = Set(dismissedIDs)
        running.removeAll { dismissedSet.contains($0.id) }
        seenAlarmIDs.subtract(dismissedSet)
        repo.save(running)
        onChange?()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func syncPauseState(from alarms: [Alarm]) {
        var changed = false
        let now = Date()
        for alarm in alarms {
            guard let index = running.firstIndex(where: { $0.id == alarm.id }) else { continue }
            let existing = running[index]
            switch alarm.state {
            case .paused:
                guard !existing.isPaused else { continue }
                running[index] = RunningTimer(
                    id: existing.id,
                    presetID: existing.presetID,
                    name: existing.name,
                    startDate: existing.startDate,
                    duration: existing.duration,
                    pausedAt: now
                )
                changed = true
            case .countdown:
                guard let pausedAt = existing.pausedAt else { continue }
                let delta = now.timeIntervalSince(pausedAt)
                running[index] = RunningTimer(
                    id: existing.id,
                    presetID: existing.presetID,
                    name: existing.name,
                    startDate: existing.startDate.addingTimeInterval(delta),
                    duration: existing.duration,
                    pausedAt: nil
                )
                changed = true
            default:
                continue
            }
        }
        if changed {
            repo.save(running)
            onChange?()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func removeTimers(notIn activeIDs: Set<UUID>) {
        let now = Date()
        let dismissedIDs = running
            .filter { !activeIDs.contains($0.id) &&
                      (seenAlarmIDs.contains($0.id) || $0.isFinished(at: now)) }
            .map(\.id)
        guard !dismissedIDs.isEmpty else { return }
        let dismissedSet = Set(dismissedIDs)
        running.removeAll { dismissedSet.contains($0.id) }
        seenAlarmIDs.subtract(dismissedSet)
        repo.save(running)
        onChange?()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func reload() {
        running = repo.load()
        onChange?()
    }

    func start(preset: TimerPreset) {
        let timer = RunningTimer(
            id: UUID(),
            presetID: preset.id,
            name: preset.name,
            startDate: Date(),
            duration: preset.duration
        )
        running.append(timer)
        repo.save(running)
        Task {
            await ensureAuthorized()
            await schedule(timer, presetName: preset.name)
        }
        onChange?()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func stop(_ timer: RunningTimer) {
        running.removeAll { $0.id == timer.id }
        repo.save(running)
        let timerID = timer.id
        Task { try? AlarmManager.shared.cancel(id: timerID) }
        onChange?()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func pause(_ timer: RunningTimer) {
        guard let index = running.firstIndex(where: { $0.id == timer.id }), !running[index].isPaused else { return }
        let existing = running[index]
        running[index] = RunningTimer(
            id: existing.id,
            presetID: existing.presetID,
            name: existing.name,
            startDate: existing.startDate,
            duration: existing.duration,
            pausedAt: Date()
        )
        repo.save(running)
        let timerID = timer.id
        Task { try? AlarmManager.shared.pause(id: timerID) }
        onChange?()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func resume(_ timer: RunningTimer) {
        guard let index = running.firstIndex(where: { $0.id == timer.id }),
              let pausedAt = running[index].pausedAt else { return }
        let existing = running[index]
        let delta = Date().timeIntervalSince(pausedAt)
        running[index] = RunningTimer(
            id: existing.id,
            presetID: existing.presetID,
            name: existing.name,
            startDate: existing.startDate.addingTimeInterval(delta),
            duration: existing.duration,
            pausedAt: nil
        )
        repo.save(running)
        let timerID = timer.id
        Task { try? AlarmManager.shared.resume(id: timerID) }
        onChange?()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func pruneFinished() {
        let now = Date()
        let finished = running.filter { $0.isFinished(at: now) }
        guard !finished.isEmpty else { return }
        running.removeAll { $0.isFinished(at: now) }
        repo.save(running)
        for timer in finished {
            let timerID = timer.id
            Task { try? AlarmManager.shared.cancel(id: timerID) }
        }
        onChange?()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func ensureAuthorized() async {
        let manager = AlarmManager.shared
        print("[AlarmKit] authorizationState=\(manager.authorizationState)")
        switch manager.authorizationState {
        case .notDetermined:
            do {
                let result = try await manager.requestAuthorization()
                print("[AlarmKit] requestAuthorization result=\(result)")
            } catch {
                print("[AlarmKit] requestAuthorization error=\(error)")
            }
        default:
            return
        }
    }

    private func schedule(_ timer: RunningTimer, presetName: String) async {
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: presetName),
            stopButton: .init(text: "Stop", textColor: .white, systemImageName: "stop.fill"),
            secondaryButton: .init(text: "Repeat", textColor: .white, systemImageName: "repeat"),
            secondaryButtonBehavior: .custom
        )
        let countdown = AlarmPresentation.Countdown(
            title: LocalizedStringResource(stringLiteral: presetName),
            pauseButton: .init(text: "Pause", textColor: .white, systemImageName: "pause.fill")
        )
        let paused = AlarmPresentation.Paused(
            title: LocalizedStringResource(stringLiteral: presetName),
            resumeButton: .init(text: "Resume", textColor: .white, systemImageName: "play.fill")
        )
        let attributes = AlarmAttributes<SpaghettiTimerMetadata>(
            presentation: .init(alert: alert, countdown: countdown, paused: paused),
            metadata: SpaghettiTimerMetadata(presetName: presetName, alarmID: timer.id.uuidString, presetID: timer.presetID.uuidString),
            tintColor: .accentColor
        )
        let configuration = AlarmManager.AlarmConfiguration.timer(
            duration: timer.duration,
            attributes: attributes,
            secondaryIntent: RepeatTimerIntent(timerID: timer.id.uuidString, presetID: timer.presetID.uuidString),
            sound: .default
        )
        do {
            let scheduled = try await AlarmManager.shared.schedule(id: timer.id, configuration: configuration)
            print("[AlarmKit] scheduled id=\(timer.id) state=\(scheduled.state)")
        } catch {
            print("[AlarmKit] schedule error=\(error)")
        }
    }
}
