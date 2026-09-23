//
//  SpokenTimer.swift
//  SpaghettiTimer
//
//  What VoiceOver says for a timer, wherever it appears — Home's running rows
//  and tiles, the Presets widget, the Live Activity.
//
//  This lives here, apart from the views, for the reason `BannerCountdown` does:
//  a view's accessibility label and value cannot be asserted on. The phrasing
//  used to be private properties of each view — with three copies of the
//  duration formatter between them — and the copies drifted: a running
//  auto-restart timer never said "Repeats" though its tile did, and an unnamed
//  timer read as "Timer" on the widget but as nothing in the app.
//

import Foundation

nonisolated enum SpokenTimer {
    /// A localized duration — "5 minutes", "1 hour, 30 seconds" — so VoiceOver
    /// doesn't spell out "05:00". Rounds up like `TimerFormatting.format`, so it
    /// says the same second as the digits beside it.
    static func duration(_ interval: TimeInterval) -> String {
        let seconds = interval.isFinite ? max(0, interval.rounded(.up)) : 0
        // Cap well below Int range (~273 years) so the Int() conversion can never trap.
        let total = Int(min(seconds, 8.64e9))
        return Duration.seconds(total)
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))
    }

    /// A timer's label: its name, or "Timer" when it has none — an unnamed
    /// timer would otherwise be announced by its value alone.
    static func label(for name: String) -> String {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? String(localized: "Timer") : name
    }

    /// A running row's value: "4 minutes, 12 seconds remaining", "Paused, …
    /// remaining", or "Starts in …" during a repeat's restart gap — then
    /// "Repeats" for a timer that auto-restarts, as its tile says.
    static func rowValue(_ timer: RunningTimer, at now: Date) -> String {
        let status: String
        if now < timer.startDate {
            status = String(localized: "Starts in \(duration(timer.startDate.timeIntervalSince(now)))")
        } else if timer.isPaused {
            status = String(localized: "Paused, \(duration(timer.remaining(at: now))) remaining")
        } else {
            status = String(localized: "\(duration(timer.remaining(at: now))) remaining")
        }
        return list(status, timer.autoRestartDelaySeconds != nil ? String(localized: "Repeats") : nil)
    }

    /// A preset tile's value: its duration, then "Running" while one of its
    /// timers is going (the widget's live dot) and "Repeats" when it auto-restarts.
    static func tileValue(_ preset: TimerPreset, isRunning: Bool = false) -> String {
        list(duration(preset.duration),
             isRunning ? String(localized: "Running") : nil,
             preset.autoRestartDelaySeconds != nil ? String(localized: "Repeats") : nil)
    }

    /// The To-next-hour tile's value — its two on-screen strings, spoken:
    /// "Until 7 PM, 21 minutes".
    static func nextHourValue(label: String, minutes: Int) -> String {
        list(label, duration(TimeInterval(minutes * 60)))
    }

    /// The parts of one value, read with a pause between each.
    private static func list(_ parts: String?...) -> String {
        parts.compactMap { $0 }.joined(separator: ", ")
    }
}
