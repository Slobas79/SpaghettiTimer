//
//  TutorialSampleTileTests.swift
//  SpaghettiTimerTests
//

import Foundation
import Testing
@testable import SpaghettiTimer

/// Unpinning deletes a preset, so a user can empty the grid completely — and
/// then the Home tour's first two tips have nothing to spotlight and the
/// overlay drops them, opening the tour on the running-banner artwork instead
/// of the tile it is named after. `TutorialSample` is the stand-in tile that
/// keeps those tips on screen; these tests hold both halves of that contract.
@Suite("Tutorial sample tile")
struct TutorialSampleTileTests {
    /// The tips the sample tile exists to serve. If the Home script ever stops
    /// opening on the tile and its pin badge, the stand-in is pointing at
    /// nothing and this is the cheapest place to find out.
    @MainActor
    @Test func theHomeTourOpensOnTheTileAndItsPinBadge() {
        let targets = TutorialTour.home.prefix(2).map(\.target)
        #expect(targets == [.presetTile, .pinBadge])
    }

    /// It has to render as a normal tile — a name and a real countdown on the
    /// face — or the spotlight frames a placeholder.
    @Test func itLooksLikeARealTile() {
        #expect(!TutorialSample.preset.name.isEmpty)
        #expect(TutorialSample.preset.duration > 0)
        #expect(TutorialSample.preset.autoRestartDelaySeconds == nil)
    }

    /// …without being one. It is never written to `PresetsRepo`, so nothing in
    /// the app should be able to confuse it with stored state: it carries no
    /// built-in flag and its id stands outside both reserved ids.
    @Test func itIsNotAStoredPreset() {
        #expect(!TutorialSample.preset.isBuiltIn)
        #expect(!TimerPreset.builtIns.contains { $0.id == TutorialSample.presetID })
        #expect(TutorialSample.presetID != NextHour.presetID)
    }

    /// The sample borrows the built-in's name for the artwork to line up, which
    /// makes it exactly the case the allowlist is built for: an id that is not
    /// on the roster reports as `"custom"`, whatever it is called. The tile
    /// never starts a timer, so this only ever fires if someone wires it up.
    @Test func itsNameWouldNotLeaveTheDeviceIfItEverStartedATimer() {
        let reported = AnalyticsEvent.safePresetName(
            presetID: TutorialSample.presetID,
            name: TutorialSample.preset.name
        )
        #expect(reported == "custom")
    }
}
