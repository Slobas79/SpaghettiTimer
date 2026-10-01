//
//  AnalyticsTimerModeTests.swift
//  SpaghettiTimerTests
//
//  End time timers and the "To next hour" tile were invisible in analytics: both
//  start ephemeral presets that `safePresetName` reports as "custom", so their
//  `timer_start` looked exactly like a Duration-tab one-shot, and pinning or
//  unpinning the tile looked like any other preset pin / delete.
//
//  These tests pin the tags that tell them apart: `mode` on `timer_start` and
//  `kind` on `preset_pin` / `preset_delete`.
//

import Foundation
import Testing
@testable import SpaghettiTimer

@MainActor
@Suite("Analytics · timer mode and pin kind")
struct AnalyticsTimerModeTests {

    private func makeUseCase(analytics: SpyAnalyticsRepo, scratch: ScratchDefaults) -> RunningTimersUseCaseImpl {
        RunningTimersUseCaseImpl(
            repo: RecordingRunningTimersRepo(),
            presetsRepo: PresetsRepoImpl(defaults: scratch.defaults),
            analytics: analytics,
            cancelledTimers: scratch.defaults,
            authorizer: StubAlarmAuthorizer(.authorized),
            scheduler: SpyAlarmScheduler(),
            widgets: SpyWidgetRefresher(),
            observesAlarmKit: false
        )
    }

    private func mode(of event: AnalyticsEvent?) -> AnalyticsValue? {
        event?.params["mode"]
    }

    // MARK: - timer_start · mode

    @Test("A plain start is tagged as a duration timer")
    func plainStartIsDuration() async {
        let scratch = ScratchDefaults()
        let analytics = SpyAnalyticsRepo()
        let useCase = makeUseCase(analytics: analytics, scratch: scratch)

        await useCase.start(preset: .fixture()).value

        #expect(mode(of: analytics.first(named: "timer_start")) == .string("duration"))
    }

    @Test("The start mode reaches timer_start", arguments: [
        (AnalyticsTimerMode.duration, "duration"),
        (.endTime, "end_time"),
        (.nextHour, "next_hour")
    ])
    func modeReachesTimerStart(mode startMode: AnalyticsTimerMode, expected: String) async {
        let scratch = ScratchDefaults()
        let analytics = SpyAnalyticsRepo()
        let useCase = makeUseCase(analytics: analytics, scratch: scratch)

        await useCase.start(preset: .fixture(), mode: startMode).value

        #expect(mode(of: analytics.first(named: "timer_start")) == .string(expected))
    }

    @Test("A widget start is tagged as a duration timer")
    func widgetStartIsDuration() async {
        let preset = TimerPreset.fixture()
        let analytics = SpyAnalyticsRepo()

        _ = await StartTimerIntent.run(
            presetID: preset.id.uuidString,
            authorization: .authorized,
            presetsRepo: StubPresetsRepo([preset]),
            runningRepo: RecordingRunningTimersRepo(),
            analytics: analytics
        ) { _ in true }

        #expect(mode(of: analytics.first(named: "timer_start")) == .string("duration"))
    }

    // MARK: - View model wiring

    private func makeViewModel(spy: SpyRunningTimersUseCase, scratch: ScratchDefaults) -> TimersViewModel {
        TimersViewModel(
            presetsUseCase: TimerPresetsUseCaseImpl(repo: PresetsRepoImpl(defaults: scratch.defaults)),
            runningUseCase: spy
        )
    }

    @Test("A Duration-tab timer starts in duration mode")
    func durationTabStartsInDurationMode() {
        let scratch = ScratchDefaults()
        let spy = SpyRunningTimersUseCase()
        let viewModel = makeViewModel(spy: spy, scratch: scratch)

        viewModel.createTimer(name: "Eggs", duration: 360, pinned: false)

        #expect(spy.starts.map(\.mode) == [.duration])
    }

    @Test("An End time timer starts in end-time mode")
    func endTimeStartsInEndTimeMode() {
        let scratch = ScratchDefaults()
        let spy = SpyRunningTimersUseCase()
        let viewModel = makeViewModel(spy: spy, scratch: scratch)

        viewModel.createTimer(name: "", duration: 1_800, pinned: false, mode: .endTime)

        #expect(spy.starts.map(\.mode) == [.endTime])
        #expect(spy.starts.first?.preset.duration == 1_800)
    }

    @Test("The To next hour tile starts in next-hour mode")
    func nextHourTileStartsInNextHourMode() {
        let scratch = ScratchDefaults()
        let spy = SpyRunningTimersUseCase()
        let viewModel = makeViewModel(spy: spy, scratch: scratch)

        viewModel.startNextHour()

        #expect(spy.starts.map(\.mode) == [.nextHour])
        #expect(spy.starts.first?.preset.id == NextHour.presetID)
    }

    @Test("A preset tile tap starts in duration mode")
    func presetTileStartsInDurationMode() {
        let scratch = ScratchDefaults()
        let spy = SpyRunningTimersUseCase()
        let viewModel = makeViewModel(spy: spy, scratch: scratch)

        viewModel.start(.fixture())

        #expect(spy.starts.map(\.mode) == [.duration])
    }

    // MARK: - preset_pin / preset_delete · kind

    @Test("Pinning and unpinning the To next hour tile is tagged next_hour")
    func nextHourPinIsTagged() {
        let scratch = ScratchDefaults()
        let analytics = SpyAnalyticsRepo()
        let useCase = TimerPresetsUseCaseImpl(repo: PresetsRepoImpl(defaults: scratch.defaults), analytics: analytics)

        useCase.setNextHourPinned(true)
        useCase.setNextHourPinned(false)

        #expect(analytics.first(named: "preset_pin")?.params["kind"] == .string("next_hour"))
        let delete = analytics.first(named: "preset_delete")
        #expect(delete?.params["kind"] == .string("next_hour"))
        #expect(delete?.params["is_built_in"] == .string("false"))
    }

    @Test("Pinning and deleting a stored preset is tagged preset")
    func storedPresetPinIsTagged() {
        let scratch = ScratchDefaults()
        let analytics = SpyAnalyticsRepo()
        let useCase = TimerPresetsUseCaseImpl(repo: PresetsRepoImpl(defaults: scratch.defaults), analytics: analytics)
        let preset = TimerPreset.fixture()

        useCase.pinPreset(preset)
        useCase.deletePreset(preset)

        #expect(analytics.first(named: "preset_pin")?.params["kind"] == .string("preset"))
        #expect(analytics.first(named: "preset_delete")?.params["kind"] == .string("preset"))
    }
}

// MARK: - Running use case spy

/// Records each start and the mode it was asked for, without touching AlarmKit,
/// so the view model's wiring can be asserted synchronously.
@MainActor
private final class SpyRunningTimersUseCase: RunningTimersUseCase {
    struct Start {
        let preset: TimerPreset
        let mode: AnalyticsTimerMode
    }

    private(set) var starts: [Start] = []
    let running: [RunningTimer] = []
    var onChange: (() -> Void)?
    var onAuthorizationDenied: (() -> Void)?

    func reload() {}

    @discardableResult
    func start(preset: TimerPreset, mode: AnalyticsTimerMode) -> Task<Void, Never> {
        starts.append(Start(preset: preset, mode: mode))
        return Task {}
    }

    func stop(_ timer: RunningTimer) {}
    func pause(_ timer: RunningTimer) {}
    func resume(_ timer: RunningTimer) {}
    func reconcileOnForeground() {}

    @discardableResult
    func explainRefusedWidgetStart() -> Task<Void, Never> { Task {} }
}
