//
//  TestSupport.swift
//  SpaghettiTimerTests
//

import Foundation
import Testing
@testable import SpaghettiTimer

// MARK: - Scratch storage

/// A `UserDefaults` suite private to one test.
///
/// These tests are hosted in the app, which means they share a process with the
/// real `AppGroup.defaults` and with the app's own `RunningTimersUseCaseImpl`.
/// Every repo and every `UserCancelledTimers` call in a test must be pointed at a
/// scratch suite so tests neither race the host app nor corrupt the simulator's
/// real timer state.
final class ScratchDefaults {
    let suiteName: String
    let defaults: UserDefaults

    init() {
        suiteName = "tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    deinit {
        // Build a fresh instance rather than touching the stored `defaults`:
        // a nonisolated deinit cannot access a non-Sendable stored property
        // under `SWIFT_STRICT_CONCURRENCY = complete`.
        UserDefaults().removePersistentDomain(forName: suiteName)
    }
}

// MARK: - Analytics spy

/// `@unchecked Sendable` + a lock because `AnalyticsRepo` is `nonisolated Sendable`
/// while the project compiles with `SWIFT_STRICT_CONCURRENCY = complete`.
final class SpyAnalyticsRepo: AnalyticsRepo, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [AnalyticsEvent] = []

    var events: [AnalyticsEvent] {
        lock.lock(); defer { lock.unlock() }
        return storage
    }

    func log(_ event: AnalyticsEvent) {
        lock.lock(); defer { lock.unlock() }
        storage.append(event)
    }

    func names() -> [String] { events.map(\.name) }

    func first(named name: String) -> AnalyticsEvent? {
        events.first { $0.name == name }
    }
}

/// Records every write so a test can assert that something was *not* persisted.
final class RecordingRunningTimersRepo: RunningTimersRepo, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [RunningTimer]
    private(set) var saveCount = 0

    init(_ initial: [RunningTimer] = []) { storage = initial }

    func load() -> [RunningTimer] {
        lock.lock(); defer { lock.unlock() }
        return storage
    }

    func save(_ timers: [RunningTimer]) {
        lock.lock(); defer { lock.unlock() }
        storage = timers
        saveCount += 1
    }

    /// Simulates another process writing to shared storage without going through
    /// this use case — what `StopTimerIntent` does when it schedules the next
    /// auto-restart iteration while the app is backgrounded.
    func writeFromAnotherProcess(_ timers: [RunningTimer]) {
        lock.lock(); defer { lock.unlock() }
        storage = timers
    }
}

// MARK: - Fixtures

extension Date {
    /// A fixed reference instant so date arithmetic in tests is exact.
    static let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
}

extension RunningTimer {
    static func fixture(
        id: UUID = UUID(),
        presetID: UUID = UUID(),
        name: String = "Pasta",
        startDate: Date = .t0,
        duration: TimeInterval = 300,
        pausedAt: Date? = nil,
        autoRestartDelaySeconds: TimeInterval? = nil
    ) -> RunningTimer {
        RunningTimer(
            id: id,
            presetID: presetID,
            name: name,
            startDate: startDate,
            duration: duration,
            pausedAt: pausedAt,
            autoRestartDelaySeconds: autoRestartDelaySeconds
        )
    }
}

extension TimerPreset {
    static func fixture(
        id: UUID = UUID(),
        name: String = "Pasta",
        duration: TimeInterval = 300,
        isBuiltIn: Bool = false,
        autoRestartDelaySeconds: TimeInterval? = nil
    ) -> TimerPreset {
        TimerPreset(
            id: id,
            name: name,
            duration: duration,
            isBuiltIn: isBuiltIn,
            autoRestartDelaySeconds: autoRestartDelaySeconds
        )
    }
}
