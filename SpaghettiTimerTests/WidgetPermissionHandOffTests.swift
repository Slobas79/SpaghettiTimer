//
//  WidgetPermissionHandOffTests.swift
//  SpaghettiTimerTests
//
//  With alarms turned off in Settings, tapping a Home Screen widget tile did
//  nothing at all. `StartTimerIntent` correctly refused the start, but the
//  widget has no way to say why, while the same tap in the app gets the
//  "Alarms are turned off" alert with its Open Settings button.
//
//  These tests pin the hand-off that fixed it:
//
//  * the intent can continue in the foreground, which is also what makes the
//    system perform it in the app's process;
//  * a start dropped for anything short of a grant opens the app;
//  * the app shows the existing alert exactly once per refusal, and not at
//    all if the user turned alarms back on before returning.
//

import AppIntents
import Foundation
import Testing
@testable import SpaghettiTimer

@MainActor
@Suite("Widget permission hand-off")
struct WidgetPermissionHandOffTests {

    private func makeUseCase(
        authorizer: StubAlarmAuthorizer,
        scratch: ScratchDefaults
    ) -> RunningTimersUseCaseImpl {
        RunningTimersUseCaseImpl(
            repo: RecordingRunningTimersRepo(),
            presetsRepo: PresetsRepoImpl(defaults: scratch.defaults),
            analytics: SpyAnalyticsRepo(),
            cancelledTimers: scratch.defaults,
            widgetRefusals: scratch.defaults,
            authorizer: authorizer,
            observesAlarmKit: false
        )
    }

    // MARK: - The intent

    @Test("The start intent can bring the app forward")
    func startIntentCanContinueInForeground() {
        let modes = StartTimerIntent.supportedModes
        #expect(modes.contains(.background))
        #expect(modes.contains(.foreground(.dynamic)))
    }

    @Test("A dropped start opens the app unless permission was granted", arguments: [
        (AlarmAuthorization.denied, true),
        (AlarmAuthorization.notDetermined, true),
        (AlarmAuthorization.authorized, false)
    ])
    func droppedStartHandsOffUnlessGranted(authorization: AlarmAuthorization, handsOff: Bool) {
        #expect(StartTimerIntent.needsPermissionHandOff(afterAttempt: authorization) == handsOff)
    }

    // MARK: - The flag

    @Test("A recorded refusal is consumed exactly once")
    func refusalIsConsumedOnce() {
        let scratch = ScratchDefaults()

        #expect(WidgetStartRefusal.consume(in: scratch.defaults) == false)

        WidgetStartRefusal.record(in: scratch.defaults)
        #expect(WidgetStartRefusal.consume(in: scratch.defaults))
        #expect(WidgetStartRefusal.consume(in: scratch.defaults) == false)
    }

    // MARK: - The app

    @Test("A refused widget start raises the alert")
    func refusedWidgetStartRaisesTheAlert() async {
        let scratch = ScratchDefaults()
        let useCase = makeUseCase(authorizer: StubAlarmAuthorizer(.denied), scratch: scratch)
        var denials = 0
        useCase.onAuthorizationDenied = { denials += 1 }

        WidgetStartRefusal.record(in: scratch.defaults)
        await useCase.explainRefusedWidgetStart().value

        #expect(denials == 1)
        #expect(WidgetStartRefusal.consume(in: scratch.defaults) == false)
    }

    @Test("A refusal is explained only once")
    func refusalIsExplainedOnlyOnce() async {
        // Every later foreground under the same denial must not bring the alert back.
        let scratch = ScratchDefaults()
        let useCase = makeUseCase(authorizer: StubAlarmAuthorizer(.denied), scratch: scratch)
        var denials = 0
        useCase.onAuthorizationDenied = { denials += 1 }

        WidgetStartRefusal.record(in: scratch.defaults)
        await useCase.explainRefusedWidgetStart().value
        await useCase.explainRefusedWidgetStart().value

        #expect(denials == 1)
    }

    @Test("Without a refusal a denied foreground stays quiet")
    func noRefusalNoAlert() async {
        let scratch = ScratchDefaults()
        let authorizer = StubAlarmAuthorizer(.denied)
        let useCase = makeUseCase(authorizer: authorizer, scratch: scratch)
        var denials = 0
        useCase.onAuthorizationDenied = { denials += 1 }

        await useCase.explainRefusedWidgetStart().value

        #expect(denials == 0)
        #expect(authorizer.resolveCount == 0)
    }

    @Test("Alarms turned back on before returning need no alert")
    func grantedSinceRefusalStaysQuiet() async {
        let scratch = ScratchDefaults()
        let useCase = makeUseCase(authorizer: StubAlarmAuthorizer(.authorized), scratch: scratch)
        var denials = 0
        useCase.onAuthorizationDenied = { denials += 1 }

        WidgetStartRefusal.record(in: scratch.defaults)
        await useCase.explainRefusedWidgetStart().value

        #expect(denials == 0)
        #expect(WidgetStartRefusal.consume(in: scratch.defaults) == false)
    }

    @Test("An undecided state is asked in the app, and a refusal there is explained")
    func undecidedStateIsAskedInTheApp() async {
        let scratch = ScratchDefaults()
        let authorizer = StubAlarmAuthorizer(.notDetermined)
        let useCase = makeUseCase(authorizer: authorizer, scratch: scratch)
        var denials = 0
        useCase.onAuthorizationDenied = { denials += 1 }

        WidgetStartRefusal.record(in: scratch.defaults)
        await useCase.explainRefusedWidgetStart().value

        #expect(authorizer.resolveCount == 1)
        #expect(denials == 1)
    }

    @Test("The refusal reaches the view model as the alert")
    func refusalReachesTheViewModel() async {
        let scratch = ScratchDefaults()
        let useCase = makeUseCase(authorizer: StubAlarmAuthorizer(.denied), scratch: scratch)
        let viewModel = TimersViewModel(
            presetsUseCase: TimerPresetsUseCaseImpl(repo: PresetsRepoImpl(defaults: scratch.defaults)),
            runningUseCase: useCase
        )
        #expect(viewModel.isAlarmPermissionDenied == false)

        WidgetStartRefusal.record(in: scratch.defaults)
        await useCase.explainRefusedWidgetStart().value

        #expect(viewModel.isAlarmPermissionDenied)
    }
}
