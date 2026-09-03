//
//  BuiltInPresetsTests.swift
//  SpaghettiTimerTests
//

import Foundation
import Testing
@testable import SpaghettiTimer

/// Locks down the roster a fresh install ships with. The built-ins are one
/// flagship example per target group — cooking, gym, focus, self-care — and their
/// ids are load-bearing beyond the grid: `presets.hiddenBuiltIns` persists them,
/// and `Analytics.safePresetName` uses membership here to decide whether a preset
/// name may leave the device.
@Suite("Built-in presets")
struct BuiltInPresetsTests {
    private static let expected: [(id: String, name: String, duration: TimeInterval)] = [
        ("11111111-1111-1111-1111-000000000001", "Al Dente",  480),
        ("11111111-1111-1111-1111-000000000002", "Rest Set",  90),
        ("11111111-1111-1111-1111-000000000003", "Pomodoro",  1500),
        ("11111111-1111-1111-1111-000000000004", "Power Nap", 1200)
    ]

    @Test func shipsOneExamplePerTargetGroupInGridOrder() {
        let builtIns = TimerPreset.builtIns
        #expect(builtIns.count == Self.expected.count)

        for (preset, want) in zip(builtIns, Self.expected) {
            #expect(preset.name == want.name)
            #expect(preset.duration == want.duration)
        }
    }

    @Test func allAreFlaggedBuiltInAndNonRepeating() {
        for preset in TimerPreset.builtIns {
            #expect(preset.isBuiltIn)
            #expect(preset.autoRestartDelaySeconds == nil)
        }
    }

    /// Changing a built-in id would resurrect presets the user had hidden, orphan
    /// the old id in `presets.hiddenBuiltIns` forever, and reclassify historical
    /// analytics events as `"custom"`. It must be a deliberate act, not a slip.
    @Test func idsAreStableAcrossReleases() {
        let ids = TimerPreset.builtIns.map(\.id)
        #expect(ids == Self.expected.map { UUID(uuidString: $0.id)! })
        #expect(Set(ids).count == ids.count)
    }

    /// The dynamic "To next hour" tile shares the `11111111-…` namespace but is not
    /// a stored preset — its id must never collide with one.
    @Test func nextHourIDIsNotABuiltIn() {
        #expect(!TimerPreset.builtIns.contains { $0.id == NextHour.presetID })
    }
}

/// The freeze itself: one assertion over the entire shipped roster, so *any*
/// drift trips a single obvious failure — a rename, a retime, a reorder, an
/// added preset or a removed one.
///
/// If this fails and the change was deliberate, update `frozen` below and work
/// the checklist in the failure comment. If it fails and you didn't touch
/// `TimerPreset.builtIns`, something merged a roster change underneath you.
@Suite("Built-in presets · freeze")
struct BuiltInPresetsFreezeTests {
    /// One line per preset: id | name | whole seconds | built-in flag | repeat delay.
    private static func digest(_ presets: [TimerPreset]) -> String {
        presets.map { preset in
            [
                preset.id.uuidString,
                preset.name,
                String(Int(preset.duration)),
                preset.isBuiltIn ? "builtIn" : "user",
                preset.autoRestartDelaySeconds.map { String(Int($0)) } ?? "oneShot"
            ].joined(separator: " | ")
        }
        .joined(separator: "\n")
    }

    private static let frozen = """
    11111111-1111-1111-1111-000000000001 | Al Dente | 480 | builtIn | oneShot
    11111111-1111-1111-1111-000000000002 | Rest Set | 90 | builtIn | oneShot
    11111111-1111-1111-1111-000000000003 | Pomodoro | 1500 | builtIn | oneShot
    11111111-1111-1111-1111-000000000004 | Power Nap | 1200 | builtIn | oneShot
    """

    /// Changing the roster is a product decision with a tail of consequences —
    /// four places mirror this list as static artwork or reviewer-facing copy:
    ///
    ///   • `TutorialWidgetArt.tiles` — the tour's widget illustration.
    ///   • `CoachMarks.artBlock(.runningBanner)` — the sample running timer.
    ///   • `TutorialDynamicIslandArt.title` / `.countdown` — the same sample.
    ///   • `QA_PLAN.md` rows 2.3 and 2.5.
    ///
    /// Update those in the same commit, not the next one.
    @Test func theShippedRosterIsFrozen() {
        #expect(Self.digest(TimerPreset.builtIns) == Self.frozen)
    }
}

/// Built-in ids are the allowlist deciding whether a preset name may leave the
/// device, so freezing the roster is a privacy control as much as a product one.
@Suite("Built-in presets · analytics allowlist")
struct BuiltInPresetNameReportingTests {
    @Test func everyBuiltInReportsItsRealName() {
        for preset in TimerPreset.builtIns {
            let reported = AnalyticsEvent.safePresetName(presetID: preset.id, name: preset.name)
            #expect(reported == preset.name)
        }
    }

    @Test func aUserPresetIsReportedAsCustomEvenWhenItBorrowsABuiltInName() {
        let mine = TimerPreset.fixture(name: "Al Dente", duration: 480)
        #expect(AnalyticsEvent.safePresetName(presetID: mine.id, name: mine.name) == "custom")
    }

    /// The "To next hour" tile is not in the roster, so its label — which is a
    /// formatted clock time, not free text — reports as custom.
    @Test func theNextHourTileIsNotOnTheAllowlist() {
        #expect(AnalyticsEvent.safePresetName(presetID: NextHour.presetID, name: "Until 11:00") == "custom")
    }
}
