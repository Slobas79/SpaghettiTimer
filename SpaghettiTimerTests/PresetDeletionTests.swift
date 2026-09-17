//
//  PresetDeletionTests.swift
//  SpaghettiTimerTests
//
//  Unpinning a preset deletes it. Built-ins used to be a compile-time list that
//  unpinning only hid, by adding the id to `presets.hiddenBuiltIns`. Now the
//  whole grid is one stored list, seeded with the built-ins, and unpinning
//  removes the entry, whichever kind it is.
//
//  Installs from before the change have no stored list yet. `allPresets()`
//  derives one from the old keys, and the first save stores it.
//

import Foundation
import Testing
@testable import SpaghettiTimer

@MainActor
@Suite("Preset deletion")
struct PresetDeletionTests {

    private let alDente = TimerPreset.builtIns[0]
    private let restSet = TimerPreset.builtIns[1]
    private let pomodoro = TimerPreset.builtIns[2]
    private let powerNap = TimerPreset.builtIns[3]

    private func makeUseCase(_ scratch: ScratchDefaults,
                             analytics: SpyAnalyticsRepo = SpyAnalyticsRepo()) -> TimerPresetsUseCaseImpl {
        TimerPresetsUseCaseImpl(repo: PresetsRepoImpl(defaults: scratch.defaults), analytics: analytics)
    }

    // MARK: Deleting

    @Test("Unpinning a built-in deletes it from the stored list")
    func builtInIsDeleted() {
        let scratch = ScratchDefaults()
        let useCase = makeUseCase(scratch)

        useCase.deletePreset(pomodoro)

        #expect(scratch.defaults.data(forKey: AppGroupKey.presets) != nil)
        #expect(PresetsRepoImpl(defaults: scratch.defaults).allPresets() == [alDente, restSet, powerNap])
        #expect(useCase.presets == [alDente, restSet, powerNap])
    }

    @Test("Unpinning a built-in no longer hides it")
    func builtInIsNotHidden() {
        let scratch = ScratchDefaults()
        let useCase = makeUseCase(scratch)

        useCase.deletePreset(pomodoro)

        #expect(scratch.defaults.data(forKey: AppGroupKey.hiddenBuiltInPresets) == nil)
        #expect(PresetsRepoImpl(defaults: scratch.defaults).loadHiddenBuiltInIDs().isEmpty)
    }

    @Test("A deleted built-in stays gone for the widget's own repo")
    func deletionIsSharedAcrossRepos() {
        let scratch = ScratchDefaults()
        makeUseCase(scratch).deletePreset(alDente)

        let widgetView = PresetsRepoImpl(defaults: scratch.defaults).allPresets()
        #expect(!widgetView.contains { $0.id == alDente.id })
    }

    @Test("Unpinning every built-in leaves an empty grid")
    func deletingEveryBuiltIn() {
        let scratch = ScratchDefaults()
        let useCase = makeUseCase(scratch)

        for preset in TimerPreset.builtIns { useCase.deletePreset(preset) }

        #expect(useCase.presets.isEmpty)
        #expect(PresetsRepoImpl(defaults: scratch.defaults).allPresets().isEmpty)
    }

    @Test("Unpinning a user preset deletes it and leaves the rest in order")
    func userPresetIsDeleted() {
        let scratch = ScratchDefaults()
        let useCase = makeUseCase(scratch)
        let risotto = useCase.addPreset(name: "Risotto", duration: 1080, autoRestartDelaySeconds: nil)
        let intervals = useCase.addPreset(name: "Intervals", duration: 45, autoRestartDelaySeconds: 15)

        useCase.deletePreset(risotto)

        #expect(useCase.presets == TimerPreset.builtIns + [intervals])
    }

    @Test("Deleting a built-in is still reported as a built-in delete")
    func deleteAnalytics() {
        let scratch = ScratchDefaults()
        let analytics = SpyAnalyticsRepo()
        let useCase = makeUseCase(scratch, analytics: analytics)

        useCase.deletePreset(restSet)

        #expect(analytics.first(named: "preset_delete") == .presetDelete(isBuiltIn: true))
    }

    // MARK: Stored list

    @Test("Stored built-ins keep their ids, fields and built-in flag")
    func builtInsRoundTrip() {
        let scratch = ScratchDefaults()
        let repo = PresetsRepoImpl(defaults: scratch.defaults)

        repo.savePresets(TimerPreset.builtIns)

        #expect(PresetsRepoImpl(defaults: scratch.defaults).allPresets() == TimerPreset.builtIns)
    }

    @Test("A saved empty list stays empty rather than falling back to the built-ins")
    func emptyListIsKept() {
        let scratch = ScratchDefaults()
        PresetsRepoImpl(defaults: scratch.defaults).savePresets([])

        #expect(PresetsRepoImpl(defaults: scratch.defaults).allPresets().isEmpty)
    }

    @Test("A new preset goes after the built-ins")
    func addAppends() {
        let scratch = ScratchDefaults()
        let useCase = makeUseCase(scratch)

        let risotto = useCase.addPreset(name: "Risotto", duration: 1080, autoRestartDelaySeconds: nil)

        #expect(PresetsRepoImpl(defaults: scratch.defaults).allPresets() == TimerPreset.builtIns + [risotto])
    }

    // MARK: Pinning

    @Test("Pinning a deleted built-in brings it back once, at the end")
    func repinDeletedBuiltIn() {
        let scratch = ScratchDefaults()
        let useCase = makeUseCase(scratch)
        useCase.deletePreset(alDente)

        useCase.pinPreset(alDente)
        useCase.pinPreset(alDente)

        #expect(useCase.presets == [restSet, pomodoro, powerNap, alDente.pinnedCopy()])
    }

    @Test("Pinning a preset already on the grid adds no duplicate")
    func pinningAVisiblePresetIsANoOp() {
        let scratch = ScratchDefaults()
        let useCase = makeUseCase(scratch)

        useCase.pinPreset(pomodoro)

        #expect(useCase.presets == TimerPreset.builtIns)
    }

    // MARK: Older installs

    private func writeOldFormat(_ scratch: ScratchDefaults, user: [TimerPreset], hidden: Set<UUID>) {
        let repo = PresetsRepoImpl(defaults: scratch.defaults)
        repo.saveUserPresets(user)
        repo.saveHiddenBuiltInIDs(hidden)
    }

    @Test("An older install keeps its hidden built-ins out and its own presets in")
    func olderInstallIsRead() {
        let scratch = ScratchDefaults()
        let mine = TimerPreset.fixture(name: "Risotto", duration: 1080)
        writeOldFormat(scratch, user: [mine], hidden: [restSet.id])

        #expect(makeUseCase(scratch).presets == [alDente, pomodoro, powerNap, mine])
    }

    @Test("The first unpin on an older install stores the rest of its grid")
    func olderInstallMigratesOnFirstSave() {
        let scratch = ScratchDefaults()
        let mine = TimerPreset.fixture(name: "Risotto", duration: 1080)
        writeOldFormat(scratch, user: [mine], hidden: [restSet.id])
        let useCase = makeUseCase(scratch)

        useCase.deletePreset(powerNap)

        #expect(PresetsRepoImpl(defaults: scratch.defaults).allPresets() == [alDente, pomodoro, mine])
    }

    @Test("Once the list is stored, the old keys no longer matter")
    func oldKeysIgnoredAfterSave() {
        let scratch = ScratchDefaults()
        let useCase = makeUseCase(scratch)
        useCase.deletePreset(alDente)

        writeOldFormat(scratch, user: [TimerPreset.fixture(name: "Stale")], hidden: [pomodoro.id])

        #expect(PresetsRepoImpl(defaults: scratch.defaults).allPresets() == [restSet, pomodoro, powerNap])
    }
}
