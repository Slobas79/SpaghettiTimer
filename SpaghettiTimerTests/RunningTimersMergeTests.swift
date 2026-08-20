//
//  RunningTimersMergeTests.swift
//  SpaghettiTimerTests
//
//  Guards the cross-process reconciliation rules. Shared storage is written by the
//  app, the widget and four AppIntents with no lock between them, so every rule
//  here exists to stop one process erasing another's work.
//

import Foundation
import Testing
@testable import SpaghettiTimer

@Suite("Running timers merge")
struct RunningTimersMergeTests {

    // MARK: What a display surface shows

    @Test("The alerting timer is hidden from the display")
    func visibleHidesAlertingTimer() {
        // It is finished but its alarm is still live and ringing. The widget must
        // hide it — and, crucially, must not persist that decision: this record is
        // exactly what StopTimerIntent needs to schedule the next iteration.
        let alerting = RunningTimer.fixture(startDate: .t0, duration: 300)
        let now = Date.t0.addingTimeInterval(300)
        let shown = RunningTimersMerge.visible(
            in: [alerting], liveAlarmIDs: [alerting.id], now: now
        )
        #expect(shown.isEmpty)
    }

    @Test("A paused timer stays visible while its nominal end date is still ahead")
    func visibleKeepsPausedTimerBeforeItsEndDate() {
        let paused = RunningTimer.fixture(startDate: .t0, duration: 300, pausedAt: Date.t0.addingTimeInterval(60))
        let now = Date.t0.addingTimeInterval(120)
        let shown = RunningTimersMerge.visible(in: [paused], liveAlarmIDs: [paused.id], now: now)
        #expect(shown.map(\.id) == [paused.id])
    }

    @Test("A long-paused timer disappears once wall-clock passes its stale end date")
    func visibleDropsLongPausedTimer() {
        // Documents current behaviour rather than endorsing it. `pausedAt` does not
        // shift `startDate` — that only happens on resume — so `endDate` keeps its
        // original value while paused. The `isFinished` check exempts paused timers,
        // but the `endDate + 1 < now` check below it does not, so a timer paused for
        // longer than its remaining time vanishes from the widget even though it is
        // legitimately paused with time left.
        //
        // Pre-existing, unrelated to auto-restart, and out of scope here — but it
        // looks like a real bug worth its own change. See QA_PLAN 4.3 / 9.5.
        let paused = RunningTimer.fixture(startDate: .t0, duration: 300, pausedAt: Date.t0.addingTimeInterval(60))
        let now = Date.t0.addingTimeInterval(900)
        let shown = RunningTimersMerge.visible(in: [paused], liveAlarmIDs: [paused.id], now: now)
        #expect(shown.isEmpty)
    }

    @Test("A timer whose alarm is gone is hidden")
    func visibleDropsTimersMissingFromAlarmKit() {
        let stale = RunningTimer.fixture(startDate: .t0, duration: 300)
        let shown = RunningTimersMerge.visible(
            in: [stale], liveAlarmIDs: [], now: Date.t0.addingTimeInterval(60)
        )
        #expect(shown.isEmpty)
    }

    @Test("Without an alarm list, only the time-based checks apply")
    func visibleFallsBackToTimeWhenAlarmListUnavailable() {
        let running = RunningTimer.fixture(startDate: .t0, duration: 300)
        let shown = RunningTimersMerge.visible(
            in: [running], liveAlarmIDs: nil, now: Date.t0.addingTimeInterval(60)
        )
        #expect(shown.map(\.id) == [running.id])
    }

    @Test("The visible set is always a subset of its input")
    func visibleIsAlwaysASubsetOfItsInput() {
        // Encodes the read-only contract: this function filters, it never invents,
        // reorders into storage, or writes.
        let timers = (0..<5).map { i in
            RunningTimer.fixture(startDate: .t0, duration: TimeInterval(60 * (i + 1)))
        }
        let now = Date.t0.addingTimeInterval(200)
        let shown = RunningTimersMerge.visible(
            in: timers, liveAlarmIDs: Set(timers.map(\.id)), now: now
        )
        #expect(shown.allSatisfy { shown in timers.contains(where: { $0.id == shown.id }) })
        #expect(shown.count <= timers.count)
    }

    // MARK: Which timers count as dismissed

    @Test("A live, still-counting timer is never dismissed")
    func liveTimerIsNeverDismissed() {
        // QA 8.6 — no false removals.
        let running = RunningTimer.fixture(startDate: .t0, duration: 1500)
        let dismissed = RunningTimersMerge.dismissed(
            in: [running], liveAlarmIDs: [running.id],
            seenIDs: [running.id], now: Date.t0.addingTimeInterval(60)
        )
        #expect(dismissed.isEmpty)
    }

    @Test("A freshly started timer whose alarm is not scheduled yet survives")
    func freshlyStartedUnseenTimerIsNotDismissed() {
        // Not in the live list yet, never observed live, and not finished. This is
        // the race the seen-or-finished requirement exists to protect.
        let fresh = RunningTimer.fixture(startDate: .t0, duration: 300)
        let dismissed = RunningTimersMerge.dismissed(
            in: [fresh], liveAlarmIDs: [], seenIDs: [], now: Date.t0.addingTimeInterval(1)
        )
        #expect(dismissed.isEmpty)
    }

    @Test("A previously seen timer gone from AlarmKit is dismissed")
    func seenTimerGoneFromAlarmKitIsDismissed() {
        let stopped = RunningTimer.fixture(startDate: .t0, duration: 300)
        let dismissed = RunningTimersMerge.dismissed(
            in: [stopped], liveAlarmIDs: [], seenIDs: [stopped.id],
            now: Date.t0.addingTimeInterval(60)
        )
        #expect(dismissed.map(\.id) == [stopped.id])
    }

    @Test("A finished timer never observed live is still dismissed")
    func unseenFinishedTimerIsDismissed() {
        // Started and fired while the app was suspended, so the alarmUpdates
        // observer never ran and it was never recorded as seen. QA 8.4 / 8.5.
        let finished = RunningTimer.fixture(startDate: .t0, duration: 300)
        let dismissed = RunningTimersMerge.dismissed(
            in: [finished], liveAlarmIDs: [], seenIDs: [],
            now: Date.t0.addingTimeInterval(301)
        )
        #expect(dismissed.map(\.id) == [finished.id])
    }

    @Test("An alarm still in the live list is never dismissed, even when finished")
    func alertingTimerStillInAlarmKitIsNotDismissed() {
        // The ringing alarm. Removing it here would destroy the record before
        // StopTimerIntent could read the delay off it.
        let alerting = RunningTimer.fixture(startDate: .t0, duration: 300)
        let dismissed = RunningTimersMerge.dismissed(
            in: [alerting], liveAlarmIDs: [alerting.id], seenIDs: [alerting.id],
            now: Date.t0.addingTimeInterval(301)
        )
        #expect(dismissed.isEmpty)
    }

    // MARK: Not clobbering other processes

    @Test("Removal applies to the disk snapshot, so another process's write survives")
    func removingDismissedOperatesOnTheDiskSnapshot() {
        // B is the next auto-restart iteration, written to disk by StopTimerIntent
        // in another process while this one still held a stale array containing A.
        let a = RunningTimer.fixture(name: "old")
        let b = RunningTimer.fixture(name: "next iteration")
        let kept = RunningTimersMerge.removingDismissed(disk: [a, b], dismissedIDs: [a.id])
        #expect(kept.map(\.id) == [b.id])
    }

    @Test("A live timer only on disk is adopted")
    func adoptablePicksUpForeignLiveTimer() {
        // QA 5.3 / 5.4 — auto-restart while backgrounded, or a widget start.
        let known = RunningTimer.fixture()
        let foreign = RunningTimer.fixture()
        let adopt = RunningTimersMerge.adoptable(
            inMemory: [known], disk: [known, foreign], liveAlarmIDs: [known.id, foreign.id]
        )
        #expect(adopt.map(\.id) == [foreign.id])
    }

    @Test("A disk timer with no live alarm is not adopted")
    func adoptableIgnoresTimersWithoutLiveAlarm() {
        let stale = RunningTimer.fixture()
        let adopt = RunningTimersMerge.adoptable(
            inMemory: [], disk: [stale], liveAlarmIDs: []
        )
        #expect(adopt.isEmpty)
    }

    @Test("Already-known timers are not adopted twice")
    func adoptableIgnoresKnownTimers() {
        let known = RunningTimer.fixture()
        let adopt = RunningTimersMerge.adoptable(
            inMemory: [known], disk: [known], liveAlarmIDs: [known.id]
        )
        #expect(adopt.isEmpty)
    }

    @Test("Merging keeps a timer another process added")
    func mergingKeepsForeignDiskTimer() {
        let mine = RunningTimer.fixture()
        let foreign = RunningTimer.fixture()
        let merged = RunningTimersMerge.merging(inMemory: [mine], disk: [mine, foreign])
        #expect(merged.map(\.id) == [mine.id, foreign.id])
    }

    @Test("Merging does not duplicate by id")
    func mergingDoesNotDuplicateByID() {
        let shared = RunningTimer.fixture()
        let merged = RunningTimersMerge.merging(inMemory: [shared], disk: [shared])
        #expect(merged.count == 1)
    }
}
