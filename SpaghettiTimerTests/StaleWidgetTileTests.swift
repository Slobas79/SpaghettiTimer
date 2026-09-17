//
//  StaleWidgetTileTests.swift
//  SpaghettiTimerTests
//
//  A timer started from the Home Screen widget and cancelled from the Dynamic
//  Island stayed drawn as "Running" on the widget. Shared storage was already
//  correct — the cancel had removed the timer — but the widget never redrew.
//
//  The cancel ran in the widget extension, and WidgetKit ignored the reload it
//  requested from there; it now runs in the app (`CancelTimerIntent` is a
//  `LiveActivityIntent`), and so do the Live Activity's pause and resume, which
//  had the same flaw. Two related gaps are pinned here as well. The widget's
//  timeline asked WidgetKit to reload `.atEnd`, which with nothing running meant
//  "straight away", all day, wasting the reload budget background reloads depend
//  on. And foregrounding the app refreshed the widget only when the app's own
//  timer list changed, which it never does for a timer the app never knew about.
//

import AppIntents
import Foundation
import Testing
import WidgetKit
@testable import SpaghettiTimer

@MainActor
@Suite("Stale widget tile")
struct StaleWidgetTileTests {

    // MARK: Cancel intent

    /// Compile-time: dropping the conformance stops this suite from building.
    private func runsInTheApp<I: LiveActivityIntent>(_: I.Type) -> Bool { true }

    @Test("The Live Activity's cancel runs in the app, where its widget reload is honored")
    func cancelIsALiveActivityIntent() {
        #expect(runsInTheApp(CancelTimerIntent.self))
    }

    // MARK: Pause / resume intents

    // The Live Activity's other two buttons had the same flaw as its cancel. With the
    // widget no longer reloading on its own, an ignored reload from either is not
    // corrected until the app is opened: a paused tile goes idle at the original end
    // time, a resumed tile stays "Running" after the countdown ends.

    @Test("The Live Activity's pause runs in the app, where its widget reload is honored")
    func pauseIsALiveActivityIntent() {
        #expect(runsInTheApp(PauseTimerIntent.self))
    }

    @Test("The Live Activity's resume runs in the app, where its widget reload is honored")
    func resumeIsALiveActivityIntent() {
        #expect(runsInTheApp(ResumeTimerIntent.self))
    }

    // MARK: Timeline

    @Test("The widget never schedules a reload of its own")
    func timelineNeverPolls() {
        #expect(PresetsWidgetTimeline.reloadPolicy == .never)
    }

    @Test("With nothing running the timeline is one idle entry")
    func idleTimeline() {
        let entries = PresetsWidgetTimeline.entries(for: [], now: .t0)

        #expect(entries == [.init(date: .t0, activePresetIDs: [])])
    }

    @Test("A running timer's tile goes idle by itself just after it ends")
    func runningTileGoesIdleOnSchedule() {
        let timer = RunningTimer.fixture(startDate: .t0, duration: 300)

        let entries = PresetsWidgetTimeline.entries(for: [timer], now: .t0.addingTimeInterval(10))

        #expect(entries == [
            .init(date: .t0.addingTimeInterval(10), activePresetIDs: [timer.presetID]),
            .init(date: .t0.addingTimeInterval(300 + PresetsWidgetTimeline.idleLag), activePresetIDs: [])
        ])
    }

    @Test("A paused timer's tile stays running and schedules no transition")
    func pausedTileHasNoTransition() {
        let timer = RunningTimer.fixture(startDate: .t0, duration: 300, pausedAt: .t0.addingTimeInterval(60))

        let entries = PresetsWidgetTimeline.entries(for: [timer], now: .t0.addingTimeInterval(500))

        #expect(entries == [.init(date: .t0.addingTimeInterval(500), activePresetIDs: [timer.presetID])])
    }

    // MARK: Foreground

    private func makeUseCase(
        repo: RecordingRunningTimersRepo,
        widgets: SpyWidgetRefresher,
        scratch: ScratchDefaults
    ) -> RunningTimersUseCaseImpl {
        RunningTimersUseCaseImpl(
            repo: repo,
            presetsRepo: PresetsRepoImpl(defaults: scratch.defaults),
            analytics: SpyAnalyticsRepo(),
            cancelledTimers: scratch.defaults,
            authorizer: StubAlarmAuthorizer(.authorized),
            widgets: widgets,
            observesAlarmKit: false
        )
    }

    @Test("Foregrounding refreshes the widget even when the app's timer list is unchanged")
    func foregroundRefreshesWhenNothingChanged() {
        // The widget-started timer was cancelled from the Dynamic Island: gone from
        // storage and from AlarmKit, and never known to this array.
        let scratch = ScratchDefaults()
        let widgets = SpyWidgetRefresher()
        let useCase = makeUseCase(repo: RecordingRunningTimersRepo(), widgets: widgets, scratch: scratch)

        useCase.reconcileOnForeground(liveAlarmIDs: [], now: .t0)

        #expect(widgets.reloadCount == 1)
    }

    @Test("Foregrounding refreshes the widget when AlarmKit cannot be queried")
    func foregroundRefreshesWithoutAlarmKit() {
        let scratch = ScratchDefaults()
        let widgets = SpyWidgetRefresher()
        let useCase = makeUseCase(repo: RecordingRunningTimersRepo(), widgets: widgets, scratch: scratch)

        useCase.reconcileOnForeground(liveAlarmIDs: nil, now: .t0)

        #expect(widgets.reloadCount == 1)
    }

    @Test("Foregrounding that prunes a dismissed timer refreshes the widget once")
    func foregroundPruneRefreshesOnce() {
        let scratch = ScratchDefaults()
        let widgets = SpyWidgetRefresher()
        let finished = RunningTimer.fixture(startDate: .t0, duration: 300)
        let repo = RecordingRunningTimersRepo([finished])
        let useCase = makeUseCase(repo: repo, widgets: widgets, scratch: scratch)

        useCase.reconcileOnForeground(liveAlarmIDs: [], now: .t0.addingTimeInterval(400))

        #expect(repo.load().isEmpty)
        #expect(useCase.running.isEmpty)
        #expect(widgets.reloadCount == 1)
    }
}
