//
//  PresetsRepoTests.swift
//  SpaghettiTimerTests
//

import Foundation
import Testing
@testable import SpaghettiTimer

/// The merge in `PresetsRepoImpl.allPresets()` is the whole mechanism keeping
/// the built-in roster fixed at runtime: built-ins are a compile-time constant
/// that is never written to disk, only *subtracted* from by the hidden-id set.
/// Nothing covered this before, so the freeze in `BuiltInPresetsTests` could
/// hold while the merge quietly stopped honouring it.
@Suite("Presets repo · the built-in merge")
struct PresetsRepoTests {
    private func makeRepo() -> (ScratchDefaults, PresetsRepoImpl) {
        let scratch = ScratchDefaults()
        return (scratch, PresetsRepoImpl(defaults: scratch.defaults))
    }

    @Test func aFreshInstallSeesTheWholeRosterAndNothingElse() {
        let (scratch, repo) = makeRepo()
        defer { _ = scratch }

        #expect(repo.allPresets() == TimerPreset.builtIns)
    }

    @Test func builtInsComeFirstAndKeepTheirRosterOrder() {
        let (scratch, repo) = makeRepo()
        defer { _ = scratch }

        let mine = TimerPreset.fixture(name: "Risotto", duration: 1080)
        repo.saveUserPresets([mine])

        #expect(repo.allPresets() == TimerPreset.builtIns + [mine])
    }

    @Test func hidingABuiltInRemovesThatOneAndLeavesTheRest() {
        let (scratch, repo) = makeRepo()
        defer { _ = scratch }

        let pomodoro = TimerPreset.builtIns[2]
        repo.saveHiddenBuiltInIDs([pomodoro.id])

        let visible = repo.allPresets()
        #expect(!visible.contains { $0.id == pomodoro.id })
        #expect(visible == TimerPreset.builtIns.filter { $0.id != pomodoro.id })
    }

    @Test func hidingEveryBuiltInLeavesOnlyUserPresets() {
        let (scratch, repo) = makeRepo()
        defer { _ = scratch }

        let mine = TimerPreset.fixture(name: "Risotto", duration: 1080)
        repo.saveUserPresets([mine])
        repo.saveHiddenBuiltInIDs(Set(TimerPreset.builtIns.map(\.id)))

        #expect(repo.allPresets() == [mine])
    }

    /// A hidden id that no longer matches a shipped preset is inert rather than
    /// an error — that is what makes retiring a built-in survivable.
    @Test func anUnknownHiddenIDIsIgnored() {
        let (scratch, repo) = makeRepo()
        defer { _ = scratch }

        repo.saveHiddenBuiltInIDs([UUID()])

        #expect(repo.allPresets() == TimerPreset.builtIns)
    }

    /// The roster can never be shadowed by a stale on-disk copy of itself: the
    /// save path drops anything flagged built-in before it is encoded.
    @Test func aBuiltInIsNeverPersistedIntoUserPresets() {
        let (scratch, repo) = makeRepo()
        defer { _ = scratch }

        let mine = TimerPreset.fixture(name: "Risotto", duration: 1080)
        repo.saveUserPresets(TimerPreset.builtIns + [mine])

        #expect(repo.loadUserPresets() == [mine])
    }

    /// Pinning keeps the id — a timer already running from the original still
    /// matches its tile — but the stored copy is user-owned, so the built-in
    /// entry in the roster stays untouched.
    @Test func aPinnedBuiltInIsStoredAsAUserPresetUnderTheSameID() {
        let (scratch, repo) = makeRepo()
        defer { _ = scratch }

        let alDente = TimerPreset.builtIns[0]
        repo.saveUserPresets([alDente.pinnedCopy()])

        let stored = repo.loadUserPresets()
        #expect(stored.count == 1)
        #expect(stored.first?.id == alDente.id)
        #expect(stored.first?.name == alDente.name)
        #expect(stored.first?.duration == alDente.duration)
        #expect(stored.first?.isBuiltIn == false)
        #expect(TimerPreset.builtIns[0] == alDente)
    }

    @Test func presetsSurviveAWriteAndReadThroughSharedStorage() {
        let (scratch, repo) = makeRepo()
        defer { _ = scratch }

        let repeating = TimerPreset.fixture(
            name: "Intervals", duration: 45, autoRestartDelaySeconds: 15
        )
        repo.saveUserPresets([repeating])

        let reread = PresetsRepoImpl(defaults: scratch.defaults).loadUserPresets()
        #expect(reread == [repeating])
    }
}
