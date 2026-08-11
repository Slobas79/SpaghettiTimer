//
//  NextHour.swift
//  SpaghettiTimer
//
//  Date math for the dynamic "To next hour" home tile: unlike a normal pinned
//  preset — which stores a fixed duration — that tile always counts down to the
//  next full hour, recomputed from the real clock every time it's read.
//

import Foundation

nonisolated enum NextHour {
    /// Stable identity for timers started from the tile. There is no stored
    /// preset behind it — the duration is recomputed on every tap — so this
    /// only groups those runs together in analytics and the widget's
    /// active-tile lookup.
    static let presetID = UUID(uuidString: "11111111-1111-1111-1111-00000000000A")!

    /// A one-shot preset counting down from `now` to the next full hour.
    static func preset(at now: Date) -> TimerPreset {
        TimerPreset(id: presetID, name: label(at: now), duration: duration(at: now))
    }

    /// The next `HH:00` strictly after `now`. At exactly `HH:00` the target
    /// rolls to the following hour, so the countdown is never zero.
    static func target(after now: Date) -> Date {
        Calendar.current.nextDate(
            after: now,
            matching: DateComponents(minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(3600)
    }

    /// Seconds from `now` to the next full hour, floored at 1s so a tap landing
    /// on the boundary still schedules a valid alarm.
    static func duration(at now: Date) -> TimeInterval {
        max(1, target(after: now).timeIntervalSince(now))
    }

    /// Whole minutes left, rounded up — 18:39 → 21, matching the design's
    /// "Until 19:00 · 21 min".
    static func minutesRemaining(at now: Date) -> Int {
        Int((target(after: now).timeIntervalSince(now) / 60).rounded(.up))
    }

    /// "Until 19:00" / "Until 7 PM" — the target hour in the user's clock format.
    static func label(at now: Date) -> String {
        let time = target(after: now).formatted(.dateTime.hour().minute())
        return String(localized: "Until \(time)")
    }
}
