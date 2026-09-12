//
//  StartSideEffectOrderTests.swift
//  SpaghettiTimerTests
//
//  A timer started in the app left its widget tile drawn as idle for the whole
//  run. Every side effect fired — the timer was saved, the alarm was scheduled,
//  the widget was reloaded — but the reload went out first, on the same runloop
//  turn as the tap, while the alarm was still being handed to AlarmKit on a
//  detached task. The widget decides which tile is "running" by intersecting
//  shared storage with AlarmKit's live alarm list (`RunningTimersMerge.visible`),
//  so it snapshotted a timer AlarmKit had never heard of and filtered it out —
//  and nothing reloaded the timeline again until the timer was stopped. Starting
//  the same preset from the widget looked right, because `StartTimerIntent.run`
//  already schedules before it writes.
//
//  These tests pin the order: save, publish to the app, schedule, then refresh
//  the widget.
//

import Foundation
import Testing
@testable import SpaghettiTimer

@MainActor
@Suite("Start side effects · order")
struct StartSideEffectOrderTests {

    private func makeUseCase(
        repo: RecordingRunningTimersRepo,
        scratch: ScratchDefaults,
        authorizer: AlarmAuthorizing = StubAlarmAuthorizer(.authorized),
        scheduler: AlarmScheduling,
        widgets: WidgetRefreshing,
        analytics: AnalyticsRepo = SpyAnalyticsRepo()
    ) -> RunningTimersUseCaseImpl {
        RunningTimersUseCaseImpl(
            repo: repo,
            presetsRepo: PresetsRepoImpl(defaults: scratch.defaults),
            analytics: analytics,
            cancelledTimers: scratch.defaults,
            authorizer: authorizer,
            scheduler: scheduler,
            widgets: widgets,
            observesAlarmKit: false
        )
    }

    @Test("The widget is refreshed only after AlarmKit has the alarm")
    func widgetRefreshFollowsScheduling() async {
        let scratch = ScratchDefaults()
        let log = SideEffectLog()
        let widgets = SpyWidgetRefresher(log: log)
        let scheduler = SpyAlarmScheduler(log: log)
        let useCase = makeUseCase(
            repo: RecordingRunningTimersRepo(),
            scratch: scratch,
            scheduler: scheduler,
            widgets: widgets
        )

        await useCase.start(preset: .fixture()).value

        #expect(log.events == ["schedule", "reload"])
    }

    @Test("At the moment the alarm is scheduled the widget has not been refreshed")
    func noRefreshBeforeTheAlarmIsTaken() async {
        // The sharp edge of the bug: a refresh landing here reads an AlarmKit that
        // does not know this timer yet, and draws the tile idle.
        let scratch = ScratchDefaults()
        let widgets = SpyWidgetRefresher()
        let refreshesAtScheduleTime = Captured<Int>()
        let scheduler = SpyAlarmScheduler { refreshesAtScheduleTime.capture(widgets.reloadCount) }
        let useCase = makeUseCase(
            repo: RecordingRunningTimersRepo(),
            scratch: scratch,
            scheduler: scheduler,
            widgets: widgets
        )

        await useCase.start(preset: .fixture()).value

        #expect(refreshesAtScheduleTime.value == 0)
        #expect(widgets.reloadCount == 1)
    }

    @Test("The alarm carries the id that was persisted")
    func theScheduledAlarmIsTheStoredTimer() async {
        // The widget matches on `RunningTimer.id`, so a schedule under any other id
        // would leave the tile idle just as surely as a mistimed refresh.
        let scratch = ScratchDefaults()
        let repo = RecordingRunningTimersRepo()
        let scheduler = SpyAlarmScheduler()
        let preset = TimerPreset.fixture(name: "Pasta", duration: 480)
        let useCase = makeUseCase(
            repo: repo,
            scratch: scratch,
            scheduler: scheduler,
            widgets: SpyWidgetRefresher()
        )

        await useCase.start(preset: preset).value

        #expect(scheduler.scheduled.map(\.id) == repo.load().map(\.id))
        #expect(scheduler.scheduled.first?.presetID == preset.id)
    }

    @Test("Home is told about the timer before the alarm is scheduled")
    func theAppPublishesWithoutWaitingForAlarmKit() async {
        // The app has its own state and must not wait on AlarmKit to draw the
        // countdown — only the widget, which has no state of its own, has to.
        let scratch = ScratchDefaults()
        let log = SideEffectLog()
        let scheduler = SpyAlarmScheduler(log: log)
        let useCase = makeUseCase(
            repo: RecordingRunningTimersRepo(),
            scratch: scratch,
            scheduler: scheduler,
            widgets: SpyWidgetRefresher(log: log)
        )
        useCase.onChange = { log.record("change") }

        await useCase.start(preset: .fixture()).value

        #expect(log.events == ["change", "schedule", "reload"])
    }

    @Test("A refused start schedules nothing and refreshes nothing")
    func aRefusedStartFiresNoSideEffects() async {
        let scratch = ScratchDefaults()
        let widgets = SpyWidgetRefresher()
        let scheduler = SpyAlarmScheduler()
        let useCase = makeUseCase(
            repo: RecordingRunningTimersRepo(),
            scratch: scratch,
            authorizer: StubAlarmAuthorizer(.denied),
            scheduler: scheduler,
            widgets: widgets
        )

        await useCase.start(preset: .fixture()).value

        #expect(scheduler.scheduled.isEmpty)
        #expect(widgets.reloadCount == 0)
    }

    @Test("The start task does not finish before its side effects have")
    func theReturnedTaskCoversTheWholeSequence() async {
        // The reload used to run on a task nobody held, which is how it could be
        // both "after the save" and before AlarmKit. Awaiting the returned task has
        // to mean the start has fully settled — the UI ignores it, but this is what
        // makes every assertion above deterministic rather than lucky.
        let scratch = ScratchDefaults()
        let widgets = SpyWidgetRefresher()
        let scheduler = SpyAlarmScheduler()
        let useCase = makeUseCase(
            repo: RecordingRunningTimersRepo(),
            scratch: scratch,
            scheduler: scheduler,
            widgets: widgets
        )

        let task = useCase.start(preset: .fixture())
        await task.value

        #expect(scheduler.scheduled.count == 1)
        #expect(widgets.reloadCount == 1)
    }
}
