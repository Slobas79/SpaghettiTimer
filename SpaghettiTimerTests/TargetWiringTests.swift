//
//  TargetWiringTests.swift
//  SpaghettiTimerTests
//

import Testing
@testable import SpaghettiTimer

@Suite("Target wiring")
struct TargetWiringTests {
    /// Proves the test bundle is built, hosted, and can see the app module before
    /// any real assertion depends on it.
    @Test func testTargetIsWiredToTheAppModule() {
        #expect(TimerPreset.builtIns.count == 4)
    }
}
