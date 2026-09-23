//
//  HomeFocusReplacementTests.swift
//  SpaghettiTimerTests
//

import Foundation
import Testing
@testable import SpaghettiTimer

/// When the element VoiceOver is on leaves Home — dismissed, unpinned, rung out,
/// stopped from the Lock Screen — focus must land on the element that takes its
/// place, never stay on the vanished one.
@Suite("Home focus · hand-off when an element leaves")
struct HomeFocusReplacementTests {
    private let r1 = HomeFocus.running(UUID())
    private let r2 = HomeFocus.running(UUID())
    private let r3 = HomeFocus.running(UUID())
    private let p1 = HomeFocus.preset(UUID())
    private let p2 = HomeFocus.preset(UUID())
    private let p3 = HomeFocus.preset(UUID())

    /// Home's sections, in the shape `TimersView.focusSections` builds them.
    private func home(rows: [HomeFocus] = [], nextHour: Bool = false, presets: [HomeFocus] = []) -> [[HomeFocus]] {
        [rows, (nextHour ? [.nextHour] : []) + presets, [.add]]
    }

    private func handOff(_ removed: HomeFocus, _ old: [[HomeFocus]], _ new: [[HomeFocus]]) -> HomeFocus? {
        HomeFocus.replacement(for: removed, from: old, to: new)
    }

    // MARK: Running rows

    @Test func removedRowHandsToTheRowBelow() {
        #expect(handOff(r2, home(rows: [r1, r2, r3]), home(rows: [r1, r3])) == r3)
    }

    @Test func lastRowHandsBackUpward() {
        #expect(handOff(r2, home(rows: [r1, r2]), home(rows: [r1])) == r1)
    }

    @Test func onlyRowHandsToTheFirstGridCell() {
        #expect(handOff(r1, home(rows: [r1], presets: [p1, p2]), home(presets: [p1, p2])) == p1)
        #expect(handOff(r1, home(rows: [r1], nextHour: true, presets: [p1]),
                        home(nextHour: true, presets: [p1])) == .nextHour)
    }

    @Test func onlyRowOverAnEmptyGridHandsToAdd() {
        #expect(handOff(r1, home(rows: [r1]), home()) == .add)
    }

    @Test("Rows removed together skip each other", arguments: [true, false])
    func rowsRemovedTogether(focusOnLast: Bool) {
        let removed = focusOnLast ? r3 : r2
        #expect(handOff(removed, home(rows: [r1, r2, r3]), home(rows: [r1])) == r1)
    }

    // MARK: Grid

    @Test func unpinnedPresetHandsToTheNextOne() {
        #expect(handOff(p1, home(presets: [p1, p2, p3]), home(presets: [p2, p3])) == p2)
    }

    @Test func lastPresetHandsBackToThePreviousOne() {
        #expect(handOff(p3, home(presets: [p1, p2, p3]), home(presets: [p1, p2])) == p2)
    }

    @Test func onlyPresetHandsToTheNextHourTile() {
        #expect(handOff(p1, home(nextHour: true, presets: [p1]), home(nextHour: true)) == .nextHour)
    }

    @Test func onlyPresetHandsToAdd() {
        #expect(handOff(p1, home(rows: [r1], presets: [p1]), home(rows: [r1])) == .add)
    }

    @Test func unpinnedNextHourHandsToTheFirstPreset() {
        #expect(handOff(.nextHour, home(nextHour: true, presets: [p1, p2]), home(presets: [p1, p2])) == p1)
    }

    // MARK: Nothing to repair

    @Test func elementStillOnScreenIsLeftAlone() {
        #expect(handOff(r1, home(rows: [r1, r2]), home(rows: [r1])) == nil)
    }

    @Test func elementThatWasNeverOnScreenIsLeftAlone() {
        #expect(handOff(r3, home(rows: [r1]), home(rows: [r1])) == nil)
    }
}
