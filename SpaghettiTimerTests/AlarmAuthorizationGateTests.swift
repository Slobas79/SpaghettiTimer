//
//  AlarmAuthorizationGateTests.swift
//  SpaghettiTimerTests
//
//  QA 2.5 found a timer counting down on Home before the AlarmKit permission
//  dialog had even been answered: `start(preset:)` persisted, published and
//  logged the timer first and asked for permission afterwards, on a detached
//  task. Refuse the prompt and the app kept a countdown that AlarmKit knew
//  nothing about — it could never ring.
//
//  These tests pin the order: permission settles first, and a refusal writes
//  nothing at all.
//

import Foundation
import Testing
@testable import SpaghettiTimer

@MainActor
@Suite("AlarmKit permission gate")
struct AlarmAuthorizationGateTests {

    private func makeUseCase(
        authorizer: AlarmAuthorizing,
        repo: RecordingRunningTimersRepo,
        analytics: SpyAnalyticsRepo,
        scratch: ScratchDefaults
    ) -> RunningTimersUseCaseImpl {
        RunningTimersUseCaseImpl(
            repo: repo,
            presetsRepo: PresetsRepoImpl(defaults: scratch.defaults),
            analytics: analytics,
            cancelledTimers: scratch.defaults,
            authorizer: authorizer,
            observesAlarmKit: false
        )
    }

    @Test("A refused permission starts nothing")
    func refusedPermissionStartsNothing() async {
        let scratch = ScratchDefaults()
        let repo = RecordingRunningTimersRepo()
        let analytics = SpyAnalyticsRepo()
        let useCase = makeUseCase(
            authorizer: StubAlarmAuthorizer(.denied),
            repo: repo,
            analytics: analytics,
            scratch: scratch
        )

        var denials = 0
        useCase.onAuthorizationDenied = { denials += 1 }

        await useCase.start(preset: .fixture()).value

        #expect(useCase.running.isEmpty)
        #expect(repo.load().isEmpty)
        #expect(repo.saveCount == 0)
        #expect(analytics.first(named: "timer_start") == nil)
        #expect(denials == 1)
    }

    @Test("A dismissed prompt starts nothing")
    func undecidedPermissionStartsNothing() async {
        // `requestAuthorization()` can come back still undecided. Anything short of
        // an explicit grant has to be treated as a refusal, not waved through.
        let scratch = ScratchDefaults()
        let repo = RecordingRunningTimersRepo()
        let analytics = SpyAnalyticsRepo()
        let useCase = makeUseCase(
            authorizer: StubAlarmAuthorizer(.notDetermined),
            repo: repo,
            analytics: analytics,
            scratch: scratch
        )

        await useCase.start(preset: .fixture()).value

        #expect(useCase.running.isEmpty)
        #expect(repo.saveCount == 0)
    }

    @Test("A granted permission starts the timer")
    func grantedPermissionStartsTheTimer() async {
        let scratch = ScratchDefaults()
        let repo = RecordingRunningTimersRepo()
        let analytics = SpyAnalyticsRepo()
        let useCase = makeUseCase(
            authorizer: StubAlarmAuthorizer(.authorized),
            repo: repo,
            analytics: analytics,
            scratch: scratch
        )

        var denials = 0
        useCase.onAuthorizationDenied = { denials += 1 }

        let preset = TimerPreset.fixture(name: "Pasta", duration: 480)
        await useCase.start(preset: preset).value

        #expect(useCase.running.count == 1)
        #expect(useCase.running.first?.presetID == preset.id)
        #expect(useCase.running.first?.name == "Pasta")
        #expect(repo.load().count == 1)
        #expect(analytics.first(named: "timer_start") != nil)
        #expect(denials == 0)
    }

    @Test("Permission is settled before anything is written")
    func permissionSettlesBeforeAnythingIsWritten() async {
        // The regression itself: the gate must be consulted while the repo is still
        // untouched. Asking afterwards is what put a phantom timer on Home.
        let scratch = ScratchDefaults()
        let repo = RecordingRunningTimersRepo()
        let analytics = SpyAnalyticsRepo()
        let savesWhenAsked = Captured<Int>()
        let useCase = makeUseCase(
            authorizer: StubAlarmAuthorizer(.authorized) { savesWhenAsked.capture(repo.saveCount) },
            repo: repo,
            analytics: analytics,
            scratch: scratch
        )

        await useCase.start(preset: .fixture()).value

        #expect(savesWhenAsked.value == 0)
        #expect(repo.saveCount == 1)
    }

    @Test("Every start asks the gate")
    func everyStartAsksTheGate() async {
        let scratch = ScratchDefaults()
        let repo = RecordingRunningTimersRepo()
        let analytics = SpyAnalyticsRepo()
        let authorizer = StubAlarmAuthorizer(.authorized)
        let useCase = makeUseCase(
            authorizer: authorizer,
            repo: repo,
            analytics: analytics,
            scratch: scratch
        )

        await useCase.start(preset: .fixture()).value
        await useCase.start(preset: .fixture()).value

        #expect(authorizer.resolveCount == 2)
        #expect(useCase.running.count == 2)
    }

    @Test("A refusal reaches the view model as an alert")
    func refusalReachesTheViewModel() async {
        let scratch = ScratchDefaults()
        let repo = RecordingRunningTimersRepo()
        let analytics = SpyAnalyticsRepo()
        let useCase = makeUseCase(
            authorizer: StubAlarmAuthorizer(.denied),
            repo: repo,
            analytics: analytics,
            scratch: scratch
        )
        let viewModel = TimersViewModel(
            presetsUseCase: TimerPresetsUseCaseImpl(repo: PresetsRepoImpl(defaults: scratch.defaults)),
            runningUseCase: useCase
        )

        #expect(viewModel.isAlarmPermissionDenied == false)

        await useCase.start(preset: .fixture()).value

        #expect(viewModel.isAlarmPermissionDenied)
        #expect(viewModel.runningRows.isEmpty)
    }
}
