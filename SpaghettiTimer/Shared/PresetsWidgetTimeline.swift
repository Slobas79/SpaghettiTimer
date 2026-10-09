//
//  PresetsWidgetTimeline.swift
//  SpaghettiTimer
//
//  The Presets widget's timeline as plain data — which tiles are running at each
//  instant, and whether WidgetKit should come back for a new timeline on its own.
//  Lives here rather than in the widget target so the test host can reach it.
//

import Foundation
import WidgetKit

nonisolated enum PresetsWidgetTimeline {
    nonisolated struct Entry: Equatable, Sendable {
        let date: Date
        let activePresetIDs: Set<UUID>
    }

    /// How long after a countdown ends its tile is redrawn as idle.
    static let idleLag: TimeInterval = 0.5

    /// One entry for `now`, then one just after each counting-down timer ends, so a
    /// tile goes idle on schedule without anyone having to reload the widget.
    static func entries(for timers: [RunningTimer], now: Date) -> [Entry] {
        let transitions = timers
            .filter { isCountingDown($0, at: now) }
            .map { $0.endDate.addingTimeInterval(idleLag) }
            .sorted()
        return ([now] + transitions).map { date in
            Entry(date: date, activePresetIDs: activePresetIDs(in: timers, at: date))
        }
    }

    static func activePresetIDs(in timers: [RunningTimer], at date: Date) -> Set<UUID> {
        Set(timers.filter { $0.isPaused || !$0.isFinished(at: date) }.map(\.presetID))
    }

    /// `.atEnd` while a timer counts down, `.never` otherwise.
    ///
    /// Every change to the running list — start, pause, resume, cancel, stop,
    /// auto-restart — reloads the widget explicitly, and the one change that happens
    /// by itself, a countdown ending, is already an entry above. But the reloads
    /// requested from the background (the Live Activity's buttons, the alarm's Stop)
    /// count against WidgetKit's daily budget and can be refused, and under `.never`
    /// nothing corrects a refused one: an auto-restart's next round, started by Stop,
    /// stayed drawn as idle for that round and every later one. `.atEnd` asks once
    /// more after the last countdown ends, which picks up a round started meanwhile.
    ///
    /// An idle or paused-only timeline stays `.never`. Its only entry is dated `now`,
    /// so `.atEnd` would mean "ask again straight away", and WidgetKit kept doing so
    /// all day, spending the budget on timelines identical to the last one.
    static func reloadPolicy(for timers: [RunningTimer], now: Date) -> TimelineReloadPolicy {
        timers.contains { isCountingDown($0, at: now) } ? .atEnd : .never
    }

    /// The timers that get an idle transition in `entries`. `reloadPolicy` keys off
    /// the same test, so `.atEnd` is only ever paired with an entry in the future.
    private static func isCountingDown(_ timer: RunningTimer, at now: Date) -> Bool {
        !timer.isPaused && timer.endDate > now
    }
}
