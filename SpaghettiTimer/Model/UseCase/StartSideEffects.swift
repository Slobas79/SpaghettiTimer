//
//  StartSideEffects.swift
//  SpaghettiTimer
//
//  The two side effects a start fires, behind protocols so their *order* can be
//  tested.
//
//  Both are process-wide singletons in production — `AlarmManager.shared` and
//  `WidgetCenter.shared` — with nothing to observe and, in AlarmKit's case, a
//  system permission alert waiting for any test host that touches it. The order
//  between them is not cosmetic: the widget decides which tile is "running" by
//  intersecting shared storage with AlarmKit's live alarm list
//  (`RunningTimersMerge.visible`), so a refresh fired before the alarm is
//  scheduled draws a timer AlarmKit has never heard of as idle.
//

import AlarmKit
import Foundation
import WidgetKit

// MARK: - Scheduling

/// Hands a timer to AlarmKit.
nonisolated protocol AlarmScheduling: Sendable {
    /// Returns once AlarmKit has taken the alarm (or refused it). Failures are
    /// logged, not thrown: the caller has already persisted and published the
    /// timer, and there is no recovery here beyond the reconciliation passes.
    func schedule(_ timer: RunningTimer) async
}

nonisolated struct AlarmKitScheduler: AlarmScheduling {
    init() {}

    func schedule(_ timer: RunningTimer) async {
        let configuration = AlarmConfigurationFactory.makeConfiguration(for: timer)
        do {
            let scheduled = try await AlarmManager.shared.schedule(id: timer.id, configuration: configuration)
            print("[AlarmKit] scheduled id=\(timer.id) state=\(scheduled.state)")
        } catch {
            print("[AlarmKit] schedule error=\(error)")
        }
    }
}

/// Schedules nothing. The default in the test host, where a real schedule pops a
/// system alert the suite cannot answer.
nonisolated struct NoAlarmScheduler: AlarmScheduling {
    init() {}

    func schedule(_ timer: RunningTimer) async {}
}

// MARK: - Widget refresh

/// Redraws the Home Screen widget.
nonisolated protocol WidgetRefreshing: Sendable {
    func reloadTimelines()
}

nonisolated struct WidgetCenterRefresher: WidgetRefreshing {
    init() {}

    func reloadTimelines() { WidgetCenter.shared.reloadAllTimelines() }
}
