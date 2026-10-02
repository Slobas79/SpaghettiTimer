//
//  ProGateTests.swift
//  SpaghettiTimerTests
//
//  What a free user may do without Pro. Only pinning has a free allowance
//  (up to `ProConfig.freePinLimit` user presets); auto-restart, End time and
//  the "To next hour" tile are Pro-only, with no free trial.
//

import Foundation
import Testing
@testable import SpaghettiTimer

@MainActor
@Suite("Pro gates · free tier")
struct ProGateTests {

    /// A fresh store has no entitlement until StoreKit says otherwise.
    private let store = StoreUseCase()

    @Test("A free user starts without Pro")
    func freeUserIsNotPro() {
        #expect(!store.isPro)
    }

    @Test("Auto-restart is Pro-only, with no free uses")
    func autoRestartNeedsPro() {
        #expect(!store.canEnableAutoRestart())
    }

    @Test("End time is Pro-only")
    func endTimeNeedsPro() {
        #expect(!store.canUseEndTime())
    }

    @Test("The “To next hour” tile is Pro-only")
    func nextHourNeedsPro() {
        #expect(!store.canPinNextHour())
    }

    @Test("Pinning is free up to the cap, then needs Pro", arguments: 0...5)
    func pinningStopsAtTheFreeCap(userPresets: Int) {
        #expect(store.canPin(currentUserPresetCount: userPresets) == (userPresets < ProConfig.freePinLimit))
    }
}
