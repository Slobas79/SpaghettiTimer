//
//  AlarmRevocationPurgeTests.swift
//  SpaghettiTimerTests
//
//  QA 6.9 found an auto-restart chain surviving a revocation: with alarms turned
//  off in iOS Settings mid-cycle, the scheduled iteration went silent but the
//  running row stayed put — in the app, on the Lock Screen and in the Dynamic
//  Island — with no way to clear it. A revoked alarm stays in
//  `AlarmManager.shared.alarms` and keeps its Live Activity; it simply never
//  alerts. So the liveness pass, which keys entirely off that list, structurally
//  cannot see it as dismissed. Only permission state can tell us, and until this
//  it was consulted on the start paths and nowhere else.
//
//  These tests pin the purge: an explicit denial clears every running timer
//  wherever it lives, without billing any of them as completed, and nothing short
//  of an explicit denial clears anything.
//

import Foundation
import Testing
@testable import SpaghettiTimer

@MainActor
@Suite("Alarm revocation purge")
struct AlarmRevocationPurgeTests {

    /// A use case whose non-prompting read reports `current` while `resolve()` still
    /// grants — the shape of a revocation, where the timers on screen were started
    /// under a permission that has since been taken away.
    private func makeUseCase(
        current: AlarmAuthorization,
        repo: RecordingRunningTimersRepo,
        analytics: SpyAnalyticsRepo,
        scratch: ScratchDefaults
    ) -> RunningTimersUseCaseImpl {
        RunningTimersUseCaseImpl(
            repo: repo,
            presetsRepo: PresetsRepoImpl(defaults: scratch.defaults),
            analytics: analytics,
            cancelledTimers: scratch.defaults,
            authorizer: StubAlarmAuthorizer(.authorized, current: current),
            observesAlarmKit: false
        )
    }

    // MARK: - The verdict itself

    @Test("Only an explicit denial revokes")
    func onlyDenialRevokes() {
        #expect(AlarmAuthorization.denied.revokesScheduledTimers)
        #expect(AlarmAuthorization.authorized.revokesScheduledTimers == false)
        // The pre-prompt state, and what AlarmKit reports from a process holding no
        // grant of its own. Purging on it would delete timers nobody revoked.
        #expect(AlarmAuthorization.notDetermined.revokesScheduledTimers == false)
    }

    // MARK: - Purging

    @Test("A revocation clears the running timers")
    func revocationClearsRunningTimers() {
        let scratch = ScratchDefaults()
        let repo = RecordingRunningTimersRepo([.fixture(name: "Pasta"), .fixture(name: "Eggs")])
        let useCase = makeUseCase(
            current: .denied, repo: repo, analytics: SpyAnalyticsRepo(), scratch: scratch
        )
        #expect(useCase.running.count == 2)

        let purged = useCase.purgeIfAlarmsRevoked()

        #expect(purged)
        #expect(useCase.running.isEmpty)
        #expect(repo.load().isEmpty)
    }

    @Test("A revocation reaches the view model as the alert")
    func revocationReachesTheViewModel() {
        // Timers vanishing on their own has to be explained, or the app just looks
        // like it lost them.
        let scratch = ScratchDefaults()
        let repo = RecordingRunningTimersRepo([.fixture()])
        let useCase = makeUseCase(
            current: .denied, repo: repo, analytics: SpyAnalyticsRepo(), scratch: scratch
        )
        let viewModel = TimersViewModel(
            presetsUseCase: TimerPresetsUseCaseImpl(repo: PresetsRepoImpl(defaults: scratch.defaults)),
            runningUseCase: useCase
        )
        #expect(viewModel.isAlarmPermissionDenied == false)

        useCase.purgeIfAlarmsRevoked()

        #expect(viewModel.isAlarmPermissionDenied)
        #expect(viewModel.runningRows.isEmpty)
    }

    @Test("A revocation clears a timer only another process knows about")
    func revocationClearsTimersWrittenElsewhere() {
        // The QA 6.9 case exactly: the auto-restart iteration was written to shared
        // storage by `StopTimerIntent` in another process, so the in-memory array has
        // never heard of it. Purging memory alone would leave it on disk, and the next
        // foreground would read it straight back in.
        let scratch = ScratchDefaults()
        let repo = RecordingRunningTimersRepo()
        let useCase = makeUseCase(
            current: .denied, repo: repo, analytics: SpyAnalyticsRepo(), scratch: scratch
        )
        #expect(useCase.running.isEmpty)

        let iteration = RunningTimer.fixture(name: "Pasta", autoRestartDelaySeconds: 30)
        repo.writeFromAnotherProcess([iteration])

        #expect(useCase.purgeIfAlarmsRevoked())
        #expect(repo.load().isEmpty)
        #expect(useCase.running.isEmpty)
    }

    @Test("A revoked timer is not billed as completed")
    func revokedTimersAreNotBilledAsCompleted() {
        // The cancels land as an `alarmUpdates` emission, and `logCompletions` reads
        // the user-cancelled flag to decide whether a vanished timer rang. Without the
        // mark, every revoked timer would report a `timer_complete` nobody heard.
        let scratch = ScratchDefaults()
        let alive = RunningTimer.fixture(name: "Pasta")
        let repo = RecordingRunningTimersRepo([alive])
        let useCase = makeUseCase(
            current: .denied, repo: repo, analytics: SpyAnalyticsRepo(), scratch: scratch
        )

        useCase.purgeIfAlarmsRevoked()

        #expect(UserCancelledTimers.contains(alive.id, in: scratch.defaults))
    }

    @Test("A revocation closes out each timer it clears")
    func revocationLogsATerminalEvent() {
        // Not a user cancellation, but a forced one — and the nearest terminal event
        // in the taxonomy. Logging nothing would leave each of these starts with no end.
        let scratch = ScratchDefaults()
        let analytics = SpyAnalyticsRepo()
        let repo = RecordingRunningTimersRepo([.fixture(name: "Pasta"), .fixture(name: "Eggs")])
        let useCase = makeUseCase(
            current: .denied, repo: repo, analytics: analytics, scratch: scratch
        )

        useCase.purgeIfAlarmsRevoked()

        #expect(analytics.names().filter { $0 == "timer_cancel" }.count == 2)
        #expect(analytics.first(named: "timer_complete") == nil)
    }

    // MARK: - Not purging

    @Test("A granted permission purges nothing", arguments: [
        AlarmAuthorization.authorized, .notDetermined
    ])
    func nonDenialPurgesNothing(current: AlarmAuthorization) {
        let scratch = ScratchDefaults()
        let repo = RecordingRunningTimersRepo([.fixture()])
        let analytics = SpyAnalyticsRepo()
        let useCase = makeUseCase(
            current: current, repo: repo, analytics: analytics, scratch: scratch
        )

        var denials = 0
        useCase.onAuthorizationDenied = { denials += 1 }

        #expect(useCase.purgeIfAlarmsRevoked() == false)
        #expect(useCase.running.count == 1)
        #expect(repo.load().count == 1)
        #expect(repo.saveCount == 0)
        #expect(analytics.names().isEmpty)
        #expect(denials == 0)
    }

    @Test("A denial with nothing running alerts nobody")
    func denialWithNothingRunningAlertsNobody() {
        // Reported as "nothing purged" so the caller falls through to its normal
        // reconciliation — and so every subsequent foreground under the same denial
        // stays silent instead of re-raising the alert.
        let scratch = ScratchDefaults()
        let repo = RecordingRunningTimersRepo()
        let useCase = makeUseCase(
            current: .denied, repo: repo, analytics: SpyAnalyticsRepo(), scratch: scratch
        )

        var denials = 0
        useCase.onAuthorizationDenied = { denials += 1 }

        #expect(useCase.purgeIfAlarmsRevoked() == false)
        #expect(denials == 0)
        #expect(repo.saveCount == 0)
    }

    @Test("A second pass under the same denial is a no-op")
    func secondPassIsANoOp() {
        let scratch = ScratchDefaults()
        let repo = RecordingRunningTimersRepo([.fixture()])
        let useCase = makeUseCase(
            current: .denied, repo: repo, analytics: SpyAnalyticsRepo(), scratch: scratch
        )

        var denials = 0
        useCase.onAuthorizationDenied = { denials += 1 }

        #expect(useCase.purgeIfAlarmsRevoked())
        let savesAfterPurge = repo.saveCount

        #expect(useCase.purgeIfAlarmsRevoked() == false)
        #expect(denials == 1)
        #expect(repo.saveCount == savesAfterPurge)
    }
}
