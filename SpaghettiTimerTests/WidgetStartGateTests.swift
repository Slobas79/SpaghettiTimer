//
//  WidgetStartGateTests.swift
//  SpaghettiTimerTests
//
//  Tapping a tile on the Home Screen widget stopped starting anything. The
//  permission gate added for the first-run phantom-timer bug required
//  `.authorized`, and `StartTimerIntent` runs in the widget extension — a
//  process with no UI to prompt from, which AlarmKit reports `.notDetermined`
//  to even when the containing app holds the grant. Every tap fell out of the
//  guard before it ever reached AlarmKit.
//
//  These tests freeze the sequence that replaced it:
//
//  * only an explicit `.denied` refuses a widget start;
//  * nothing is persisted or logged until AlarmKit has taken the alarm, which
//    is what now keeps a phantom timer off Home;
//  * the in-app start path is untouched and still demands a real grant.
//

import Foundation
import Testing
@testable import SpaghettiTimer

@Suite("Widget start gate")
struct WidgetStartGateTests {

    // MARK: - The gate

    @Test("An undecided state does not block a widget start")
    func undecidedDoesNotBlockWidgetStart() {
        // The regression itself. The widget process cannot ask, so treating
        // "hasn't been answered here" as "no" makes the tile permanently dead.
        #expect(AlarmAuthorization.notDetermined.allowsUnpromptedStart)
    }

    @Test("An explicit denial blocks a widget start")
    func denialBlocksWidgetStart() {
        #expect(AlarmAuthorization.denied.allowsUnpromptedStart == false)
    }

    @Test("A granted permission allows a widget start")
    func grantAllowsWidgetStart() {
        #expect(AlarmAuthorization.authorized.allowsUnpromptedStart)
    }

    // MARK: - The start sequence

    @Test("Anything short of a denial schedules and persists", arguments: [
        AlarmAuthorization.notDetermined, .authorized
    ])
    func anythingShortOfDenialStartsTheTimer(authorization: AlarmAuthorization) async {
        let preset = TimerPreset.fixture(name: "Pasta", duration: 480)
        let presets = StubPresetsRepo([preset])
        let repo = RecordingRunningTimersRepo()
        let analytics = SpyAnalyticsRepo()
        let scheduled = Captured<UUID>()

        let started = await StartTimerIntent.run(
            presetID: preset.id.uuidString,
            authorization: authorization,
            presetsRepo: presets,
            runningRepo: repo,
            analytics: analytics
        ) { timer in
            scheduled.capture(timer.id)
            return true
        }

        #expect(started?.presetID == preset.id)
        #expect(started?.name == "Pasta")
        #expect(repo.load().count == 1)
        #expect(repo.load().first?.id == started?.id)
        #expect(scheduled.value == started?.id)
        #expect(analytics.first(named: "timer_start") != nil)
    }

    @Test("A denied permission never reaches AlarmKit")
    func denialNeverReachesAlarmKit() async {
        let preset = TimerPreset.fixture()
        let repo = RecordingRunningTimersRepo()
        let analytics = SpyAnalyticsRepo()
        let scheduleCalls = Captured<Int>()

        let started = await StartTimerIntent.run(
            presetID: preset.id.uuidString,
            authorization: .denied,
            presetsRepo: StubPresetsRepo([preset]),
            runningRepo: repo,
            analytics: analytics
        ) { _ in
            scheduleCalls.capture(1)
            return true
        }

        #expect(started == nil)
        #expect(scheduleCalls.value == nil)
        #expect(repo.saveCount == 0)
        #expect(analytics.first(named: "timer_start") == nil)
    }

    @Test("A refused alarm writes nothing at all")
    func refusedAlarmWritesNothing() async {
        // The phantom-timer guarantee, now enforced by AlarmKit's answer rather
        // than by a permission flag that this process cannot read truthfully.
        let preset = TimerPreset.fixture()
        let repo = RecordingRunningTimersRepo()
        let analytics = SpyAnalyticsRepo()

        let started = await StartTimerIntent.run(
            presetID: preset.id.uuidString,
            authorization: .notDetermined,
            presetsRepo: StubPresetsRepo([preset]),
            runningRepo: repo,
            analytics: analytics
        ) { _ in false }

        #expect(started == nil)
        #expect(repo.load().isEmpty)
        #expect(repo.saveCount == 0)
        #expect(analytics.first(named: "timer_start") == nil)
    }

    @Test("The alarm is scheduled before anything is written")
    func alarmIsScheduledBeforeAnythingIsWritten() async {
        let preset = TimerPreset.fixture()
        let repo = RecordingRunningTimersRepo()
        let savesWhenScheduled = Captured<Int>()

        await StartTimerIntent.run(
            presetID: preset.id.uuidString,
            authorization: .notDetermined,
            presetsRepo: StubPresetsRepo([preset]),
            runningRepo: repo,
            analytics: SpyAnalyticsRepo()
        ) { _ in
            savesWhenScheduled.capture(repo.saveCount)
            return true
        }

        #expect(savesWhenScheduled.value == 0)
        #expect(repo.saveCount == 1)
    }

    @Test("A start appends to what another process already wrote")
    func startAppendsToAnotherProcessesTimers() async {
        // Shared storage has four writers. Reading it before the alarm is
        // scheduled and saving that array back would drop whatever landed in the
        // meantime — the failure that once killed the auto-restart chain.
        let preset = TimerPreset.fixture()
        let repo = RecordingRunningTimersRepo()
        let other = RunningTimer(id: UUID(), presetID: UUID(), name: "Elsewhere",
                                 startDate: Date(), duration: 60)

        let started = await StartTimerIntent.run(
            presetID: preset.id.uuidString,
            authorization: .notDetermined,
            presetsRepo: StubPresetsRepo([preset]),
            runningRepo: repo,
            analytics: SpyAnalyticsRepo()
        ) { _ in
            repo.save(repo.load() + [other])   // another process, mid-schedule
            return true
        }

        let stored = repo.load()
        #expect(stored.count == 2)
        #expect(stored.contains { $0.id == other.id })
        #expect(stored.contains { $0.id == started?.id })
    }

    @Test("An unknown preset id still starts a one-minute fallback")
    func unknownPresetFallsBackToAMinute() async {
        let repo = RecordingRunningTimersRepo()

        let started = await StartTimerIntent.run(
            presetID: UUID().uuidString,
            authorization: .notDetermined,
            presetsRepo: StubPresetsRepo([]),
            runningRepo: repo,
            analytics: SpyAnalyticsRepo()
        ) { _ in true }

        #expect(started?.duration == 60)
        #expect(repo.load().count == 1)
    }

    @Test("A repeating preset carries its cooldown into the started timer")
    func repeatingPresetKeepsItsCooldown() async {
        let preset = TimerPreset.fixture(name: "Intervals", duration: 30,
                                         autoRestartDelaySeconds: 5)
        let repo = RecordingRunningTimersRepo()

        let started = await StartTimerIntent.run(
            presetID: preset.id.uuidString,
            authorization: .notDetermined,
            presetsRepo: StubPresetsRepo([preset]),
            runningRepo: repo,
            analytics: SpyAnalyticsRepo()
        ) { _ in true }

        #expect(started?.autoRestartDelaySeconds == 5)
    }

    // MARK: - The in-app path is unchanged

    @Test("In the app an undecided prompt still starts nothing")
    func inAppGateStillRequiresAnExplicitGrant() async {
        // The widget's looser rule must not leak into the app, where the prompt
        // is available and an unanswered dialog still means "don't start".
        let scratch = ScratchDefaults()
        let repo = RecordingRunningTimersRepo()
        let useCase = await RunningTimersUseCaseImpl(
            repo: repo,
            presetsRepo: PresetsRepoImpl(defaults: scratch.defaults),
            analytics: SpyAnalyticsRepo(),
            cancelledTimers: scratch.defaults,
            authorizer: StubAlarmAuthorizer(.notDetermined),
            observesAlarmKit: false
        )

        await useCase.start(preset: .fixture()).value

        #expect(repo.saveCount == 0)
        #expect(await useCase.running.isEmpty)
    }
}
