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
            .filter { !$0.isPaused && $0.endDate > now }
            .map { $0.endDate.addingTimeInterval(idleLag) }
            .sorted()
        return ([now] + transitions).map { date in
            Entry(date: date, activePresetIDs: activePresetIDs(in: timers, at: date))
        }
    }

    static func activePresetIDs(in timers: [RunningTimer], at date: Date) -> Set<UUID> {
        Set(timers.filter { $0.isPaused || !$0.isFinished(at: date) }.map(\.presetID))
    }

    /// Never. Every change to the running list — start, pause, resume, cancel,
    /// stop, auto-restart — reloads the widget explicitly, and the one change that
    /// happens by itself, a countdown ending, is already an entry above.
    ///
    /// This used to be `.atEnd`. With nothing running the timeline is a single
    /// entry dated `now`, so `.atEnd` meant "ask again straight away", and WidgetKit
    /// kept doing so all day, spending the widget's daily reload budget on
    /// timelines identical to the last one — budget that the reloads requested from
    /// the background (the Live Activity's buttons, the alarm's Stop) depend on.
    static var reloadPolicy: TimelineReloadPolicy { .never }
}
