//
//  FreeTryTests.swift
//  SpaghettiTimerTests
//
//  A free user may start one auto-restarting timer and one End time timer
//  before the paywall — each once, never pinned. A try is only spent when its
//  timer really started, and like the pin allowance it lives in the Keychain,
//  so neither a relaunch nor a reinstall hands it back.
//

import Foundation
import Security
import Testing
@testable import SpaghettiTimer

/// Keychain items private to one test, deleted when the test ends, so tests
/// never spend the simulator app's real free tries.
final class ScratchFreeTries {
    let prefix = "tests.\(UUID().uuidString)."

    var repo: KeychainFreeTryRepo { KeychainFreeTryRepo(accountPrefix: prefix) }

    deinit {
        for freeTry in FreeTry.allCases {
            let item: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: KeychainFreeTryRepo.service,
                kSecAttrAccount as String: prefix + freeTry.rawValue
            ]
            SecItemDelete(item as CFDictionary)
        }
    }
}

@MainActor
@Suite("Free tries · auto-restart and End time")
struct FreeTryTests {

    /// Swift Testing builds a fresh suite per test, so each test gets its own items.
    private let keychain = ScratchFreeTries()

    private func makeStore() -> StoreUseCase {
        StoreUseCase(freeTries: keychain.repo)
    }

    @Test("A fresh install has one free try of each, while both stay Pro features")
    func freshInstall() {
        let store = makeStore()

        #expect(store.hasFreeTry(.autoRestart))
        #expect(store.hasFreeTry(.endTime))
        #expect(!store.canEnableAutoRestart())
        #expect(!store.canUseEndTime())
    }

    @Test("A started timer spends its try, and only its own", arguments: FreeTry.allCases)
    func startedTimerSpendsTry(freeTry: FreeTry) async {
        let store = makeStore()

        await store.spendFreeTry(freeTry, ifStarted: Task { true }).value

        #expect(!store.hasFreeTry(freeTry))
        for other in FreeTry.allCases where other != freeTry {
            #expect(store.hasFreeTry(other))
        }
    }

    @Test("A start that never happened keeps the try", arguments: FreeTry.allCases)
    func droppedStartKeepsTry(freeTry: FreeTry) async {
        let store = makeStore()

        await store.spendFreeTry(freeTry, ifStarted: Task { false }).value

        #expect(store.hasFreeTry(freeTry))
        #expect(!keychain.repo.isSpent(freeTry))
    }

    @Test("A spent try survives a relaunch and a reinstall")
    func spentTryPersists() async {
        await makeStore().spendFreeTry(.autoRestart, ifStarted: Task { true }).value

        // Deleting the app wipes the App Group suite; the Keychain items stay.
        let relaunched = makeStore()

        #expect(!relaunched.hasFreeTry(.autoRestart))
        #expect(relaunched.hasFreeTry(.endTime))
    }

    @Test("The Keychain item reads unspent until marked, and marking twice is harmless")
    func keychainRoundTrip() {
        let repo = keychain.repo
        #expect(!repo.isSpent(.endTime))

        repo.markSpent(.endTime)
        repo.markSpent(.endTime)

        #expect(repo.isSpent(.endTime))
        #expect(!repo.isSpent(.autoRestart))
    }

    @Test("A store built without a repo never touches the real Keychain")
    func defaultStoreIsInMemory() async {
        let first = StoreUseCase()
        await first.spendFreeTry(.endTime, ifStarted: Task { true }).value

        #expect(!first.hasFreeTry(.endTime))
        #expect(StoreUseCase().hasFreeTry(.endTime))
    }

    // MARK: - Did the timer start?

    private func makeViewModel(_ authorization: AlarmAuthorization, scratch: ScratchDefaults) -> TimersViewModel {
        TimersViewModel(
            presetsUseCase: TimerPresetsUseCaseImpl(repo: PresetsRepoImpl(defaults: scratch.defaults)),
            runningUseCase: RunningTimersUseCaseImpl(
                repo: RecordingRunningTimersRepo([]),
                presetsRepo: PresetsRepoImpl(defaults: scratch.defaults),
                cancelledTimers: scratch.defaults,
                widgetRefusals: scratch.defaults,
                authorizer: StubAlarmAuthorizer(authorization),
                scheduler: SpyAlarmScheduler(),
                widgets: SpyWidgetRefresher(),
                observesAlarmKit: false
            )
        )
    }

    @Test("Creating a timer reports it started once alarms are allowed")
    func createReportsStart() async {
        let scratch = ScratchDefaults()
        let viewModel = makeViewModel(.authorized, scratch: scratch)

        let started = await viewModel.createTimer(name: "Intervals", duration: 45, pinned: false, autoRestartDelaySeconds: 15).value

        #expect(started)
    }

    @Test("Creating a timer reports no start when alarms are refused, so the try is kept")
    func createReportsRefusal() async {
        let scratch = ScratchDefaults()
        let viewModel = makeViewModel(.denied, scratch: scratch)
        let store = makeStore()

        let start = viewModel.createTimer(name: "", duration: 1_800, pinned: false, mode: .endTime)
        await store.spendFreeTry(.endTime, ifStarted: start).value

        let started = await start.value
        #expect(!started)
        #expect(store.hasFreeTry(.endTime))
    }
}
