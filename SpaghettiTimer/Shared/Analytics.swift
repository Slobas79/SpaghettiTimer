//
//  Analytics.swift
//  SpaghettiTimer
//
//  Dependency-free analytics contract shared between the app and the widget
//  extension. The Firebase-backed implementation lives in the app target only
//  (Repository/Analytics/FirebaseAnalyticsRepo.swift); code here never imports
//  Firebase so it can compile into the extension.
//

import Foundation

// MARK: - Contract

nonisolated protocol AnalyticsRepo: Sendable {
    func log(_ event: AnalyticsEvent)
}

/// A GA4 parameter value. GA4 accepts string and numeric parameters; this app
/// only needs those two.
nonisolated enum AnalyticsValue: Codable, Sendable, Equatable {
    case string(String)
    case int(Int)
}

/// A GA4 event: a snake_case name (≤ 40 chars) plus up to 25 parameters.
nonisolated struct AnalyticsEvent: Codable, Sendable, Equatable {
    let name: String
    let params: [String: AnalyticsValue]

    init(name: String, params: [String: AnalyticsValue] = [:]) {
        self.name = name
        self.params = params
    }
}

/// Where a tracked action originated.
nonisolated enum AnalyticsSource: String, Sendable {
    case app
    case widget
    case liveActivity = "live_activity"
    case alarmAlert = "alarm_alert"
}

// MARK: - No-op

/// Used in DEBUG builds and SwiftUI previews so development traffic never
/// reaches the production GA4 property.
nonisolated struct NoOpAnalyticsRepo: AnalyticsRepo {
    func log(_ event: AnalyticsEvent) {}
}

// MARK: - Cross-process queue

/// AppIntents (widget buttons, Live Activity, alarm alert) run outside the main
/// app process where Firebase can't be initialised. They log here instead: the
/// event is appended to the shared App Group `UserDefaults`, and the main app
/// flushes the queue to Firebase on launch / foreground.
///
/// Read-modify-write is not atomic across processes — this matches the existing
/// `UserCancelledTimers` pattern in this codebase and is acceptable for
/// best-effort usage analytics.
nonisolated struct PendingAnalyticsQueueRepoImpl: AnalyticsRepo {
    /// Guards against unbounded growth if the app is never reopened.
    private static let cap = 500

    func log(_ event: AnalyticsEvent) {
        let defaults = AppGroup.defaults
        var queue = Self.load(from: defaults)
        queue.append(event)
        if queue.count > Self.cap {
            queue.removeFirst(queue.count - Self.cap)
        }
        Self.save(queue, to: defaults)
    }

    /// Pops every queued event, clearing the queue.
    static func drain() -> [AnalyticsEvent] {
        let defaults = AppGroup.defaults
        let events = load(from: defaults)
        defaults.removeObject(forKey: AppGroupKey.pendingAnalytics)
        return events
    }

    private static func load(from defaults: UserDefaults) -> [AnalyticsEvent] {
        guard let data = defaults.data(forKey: AppGroupKey.pendingAnalytics) else { return [] }
        return (try? JSONDecoder().decode([AnalyticsEvent].self, from: data)) ?? []
    }

    private static func save(_ events: [AnalyticsEvent], to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(events) {
            defaults.set(data, forKey: AppGroupKey.pendingAnalytics)
        }
    }
}

nonisolated extension AppGroupKey {
    static let pendingAnalytics = "analytics.pending"
}

// MARK: - Event factory

/// Central builders so event names/parameters stay identical across the main
/// app and the intents. Keeping this in one place is what makes the taxonomy in
/// ANALYTICS_SPEC.md authoritative.
nonisolated extension AnalyticsEvent {
    // Parameter keys
    private enum Key {
        static let source = "source"
        static let presetName = "preset_name"
        static let durationSeconds = "duration_seconds"
        static let isEphemeral = "is_ephemeral"
        static let autoRestart = "auto_restart"
        static let acknowledged = "acknowledged"
        static let isBuiltIn = "is_built_in"
        static let autoRestartIteration = "auto_restart_iteration"
    }

    private static func bool(_ value: Bool) -> AnalyticsValue { .string(value ? "true" : "false") }

    /// User-entered preset names are free text and must not leave the device.
    /// Built-in presets report their real name; everything else reports "custom".
    static func safePresetName(presetID: UUID, name: String) -> String {
        TimerPreset.builtIns.contains { $0.id == presetID } ? name : "custom"
    }

    static func timerStart(
        presetID: UUID,
        name: String,
        durationSeconds: Int,
        isEphemeral: Bool,
        autoRestart: Bool,
        source: AnalyticsSource,
        autoRestartIteration: Bool = false
    ) -> AnalyticsEvent {
        var params: [String: AnalyticsValue] = [
            Key.source: .string(source.rawValue),
            Key.presetName: .string(safePresetName(presetID: presetID, name: name)),
            Key.durationSeconds: .int(durationSeconds),
            Key.isEphemeral: bool(isEphemeral),
            Key.autoRestart: bool(autoRestart)
        ]
        if autoRestartIteration {
            params[Key.autoRestartIteration] = bool(true)
        }
        return AnalyticsEvent(name: "timer_start", params: params)
    }

    static func timerPause(presetID: UUID, name: String, durationSeconds: Int, source: AnalyticsSource) -> AnalyticsEvent {
        AnalyticsEvent(name: "timer_pause", params: lifecycleParams(presetID: presetID, name: name, durationSeconds: durationSeconds, source: source))
    }

    static func timerResume(presetID: UUID, name: String, durationSeconds: Int, source: AnalyticsSource) -> AnalyticsEvent {
        AnalyticsEvent(name: "timer_resume", params: lifecycleParams(presetID: presetID, name: name, durationSeconds: durationSeconds, source: source))
    }

    static func timerCancel(presetID: UUID, name: String, durationSeconds: Int, source: AnalyticsSource) -> AnalyticsEvent {
        AnalyticsEvent(name: "timer_cancel", params: lifecycleParams(presetID: presetID, name: name, durationSeconds: durationSeconds, source: source))
    }

    static func timerComplete(presetID: UUID, name: String, durationSeconds: Int, acknowledged: Bool, source: AnalyticsSource) -> AnalyticsEvent {
        var params = lifecycleParams(presetID: presetID, name: name, durationSeconds: durationSeconds, source: source)
        params[Key.acknowledged] = bool(acknowledged)
        return AnalyticsEvent(name: "timer_complete", params: params)
    }

    static func timerRepeat(presetID: UUID, name: String, durationSeconds: Int, source: AnalyticsSource) -> AnalyticsEvent {
        AnalyticsEvent(name: "timer_repeat", params: lifecycleParams(presetID: presetID, name: name, durationSeconds: durationSeconds, source: source))
    }

    static func presetCreate(durationSeconds: Int, autoRestart: Bool) -> AnalyticsEvent {
        AnalyticsEvent(name: "preset_create", params: [
            Key.source: .string(AnalyticsSource.app.rawValue),
            Key.durationSeconds: .int(durationSeconds),
            Key.autoRestart: bool(autoRestart)
        ])
    }

    static func presetPin() -> AnalyticsEvent {
        AnalyticsEvent(name: "preset_pin", params: [Key.source: .string(AnalyticsSource.app.rawValue)])
    }

    static func presetDelete(isBuiltIn: Bool) -> AnalyticsEvent {
        AnalyticsEvent(name: "preset_delete", params: [
            Key.source: .string(AnalyticsSource.app.rawValue),
            Key.isBuiltIn: bool(isBuiltIn)
        ])
    }

    private static func lifecycleParams(presetID: UUID, name: String, durationSeconds: Int, source: AnalyticsSource) -> [String: AnalyticsValue] {
        [
            Key.source: .string(source.rawValue),
            Key.presetName: .string(safePresetName(presetID: presetID, name: name)),
            Key.durationSeconds: .int(durationSeconds)
        ]
    }
}
