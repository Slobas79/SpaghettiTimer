//
//  FreePinAllowanceTests.swift
//  SpaghettiTimerTests
//
//  A free user gets `ProConfig.freePinLimit` pins in all, not that many tiles
//  at a time. The cap counts every user preset ever pinned, so unpinning one
//  must not hand the slot back — nor may deleting and reinstalling the app,
//  which is why the count lives in the Keychain.
//

import Foundation
import Security
import Testing
@testable import SpaghettiTimer

/// A Keychain item private to one test, deleted when the test ends, so tests
/// never spend the simulator app's real free pins.
final class ScratchPinAllowance {
    let account = "tests.\(UUID().uuidString)"

    var repo: KeychainPinAllowanceRepo { KeychainPinAllowanceRepo(account: account) }

    deinit {
        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainPinAllowanceRepo.service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(item as CFDictionary)
    }
}

@MainActor
@Suite("Free pin allowance")
struct FreePinAllowanceTests {

    private let store = StoreUseCase()
    /// Swift Testing builds a fresh suite per test, so each test gets its own item.
    private let keychain = ScratchPinAllowance()

    private func makeUseCase(_ scratch: ScratchDefaults) -> TimerPresetsUseCaseImpl {
        TimerPresetsUseCaseImpl(repo: PresetsRepoImpl(defaults: scratch.defaults), pinAllowance: keychain.repo)
    }

    private func canPin(_ useCase: TimerPresetsUseCase) -> Bool {
        store.canPin(currentUserPresetCount: useCase.lifetimePinCount)
    }

    @Test("A fresh install has every free pin left")
    func freshInstall() {
        let scratch = ScratchDefaults()
        let useCase = makeUseCase(scratch)

        #expect(useCase.lifetimePinCount == 0)
        #expect(canPin(useCase))
    }

    @Test("Each new pinned preset spends a pin")
    func addingSpendsAPin() {
        let scratch = ScratchDefaults()
        let useCase = makeUseCase(scratch)

        useCase.addPreset(name: "Risotto", duration: 1080, autoRestartDelaySeconds: nil)
        useCase.addPreset(name: "Intervals", duration: 45, autoRestartDelaySeconds: 15)

        #expect(useCase.lifetimePinCount == 2)
    }

    @Test("Unpinning after the free pins are spent doesn't free a slot")
    func unpinningDoesNotRefund() {
        let scratch = ScratchDefaults()
        let useCase = makeUseCase(scratch)
        let pinned = (0..<ProConfig.freePinLimit).map {
            useCase.addPreset(name: "Pin \($0)", duration: 60, autoRestartDelaySeconds: nil)
        }

        for preset in pinned { useCase.deletePreset(preset) }

        #expect(useCase.presets == TimerPreset.builtIns)
        #expect(useCase.lifetimePinCount == ProConfig.freePinLimit)
        #expect(!canPin(useCase))
    }

    @Test("Unpinning mid-allowance leaves only the pins never spent")
    func unpinningMidAllowance() {
        let scratch = ScratchDefaults()
        let useCase = makeUseCase(scratch)
        let risotto = useCase.addPreset(name: "Risotto", duration: 1080, autoRestartDelaySeconds: nil)

        useCase.deletePreset(risotto)

        #expect(useCase.lifetimePinCount == 1)
    }

    @Test("Unpinning a built-in neither spends nor frees a pin")
    func builtInsDoNotCount() {
        let scratch = ScratchDefaults()
        let useCase = makeUseCase(scratch)

        useCase.deletePreset(TimerPreset.builtIns[0])

        #expect(useCase.lifetimePinCount == 0)
    }

    @Test("Re-pinning a deleted built-in spends a pin")
    func repinningBuiltInSpendsAPin() {
        let scratch = ScratchDefaults()
        let useCase = makeUseCase(scratch)
        let alDente = TimerPreset.builtIns[0]
        useCase.deletePreset(alDente)

        useCase.pinPreset(alDente)
        useCase.pinPreset(alDente)

        #expect(useCase.lifetimePinCount == 1)
    }

    @Test("The spent count survives a relaunch")
    func countPersists() {
        let scratch = ScratchDefaults()
        let first = makeUseCase(scratch)
        let risotto = first.addPreset(name: "Risotto", duration: 1080, autoRestartDelaySeconds: nil)
        first.deletePreset(risotto)

        #expect(makeUseCase(scratch).lifetimePinCount == 1)
    }

    @Test("The spent count survives deleting and reinstalling the app")
    func countSurvivesReinstall() {
        let beforeDelete = ScratchDefaults()
        let pinned = (0..<ProConfig.freePinLimit).map {
            makeUseCase(beforeDelete).addPreset(name: "Pin \($0)", duration: 60, autoRestartDelaySeconds: nil)
        }
        #expect(pinned.count == ProConfig.freePinLimit)

        // Deleting the app wipes the App Group suite; the Keychain item stays.
        let reinstalled = makeUseCase(ScratchDefaults())

        #expect(reinstalled.presets == TimerPreset.builtIns)
        #expect(reinstalled.lifetimePinCount == ProConfig.freePinLimit)
        #expect(!canPin(reinstalled))
    }

    @Test("An install from before the count already spent the pins on its grid")
    func existingPinsAreSeeded() {
        let scratch = ScratchDefaults()
        let mine = (0..<ProConfig.freePinLimit).map { TimerPreset.fixture(name: "Mine \($0)") }
        PresetsRepoImpl(defaults: scratch.defaults).savePresets(TimerPreset.builtIns + mine)
        let useCase = makeUseCase(scratch)

        useCase.deletePreset(mine[0])

        #expect(useCase.lifetimePinCount == ProConfig.freePinLimit)
        #expect(!canPin(useCase))
    }

    @Test("The Keychain item reads 0 until written, then round-trips and overwrites")
    func keychainRoundTrip() {
        #expect(keychain.repo.loadLifetimePinCount() == 0)

        keychain.repo.saveLifetimePinCount(2)
        #expect(keychain.repo.loadLifetimePinCount() == 2)

        keychain.repo.saveLifetimePinCount(5)
        #expect(keychain.repo.loadLifetimePinCount() == 5)
    }

    @Test("The view model republishes the spent count")
    func viewModelTracksCount() {
        let scratch = ScratchDefaults()
        let presets = makeUseCase(scratch)
        let viewModel = TimersViewModel(
            presetsUseCase: presets,
            runningUseCase: RunningTimersUseCaseImpl(
                repo: RecordingRunningTimersRepo([]),
                presetsRepo: PresetsRepoImpl(defaults: scratch.defaults),
                cancelledTimers: scratch.defaults,
                widgetRefusals: scratch.defaults,
                authorizer: StubAlarmAuthorizer(.authorized),
                observesAlarmKit: false
            )
        )

        let risotto = presets.addPreset(name: "Risotto", duration: 1080, autoRestartDelaySeconds: nil)
        viewModel.deletePreset(risotto)

        #expect(viewModel.lifetimePinCount == 1)
    }
}
