//
//  TargetWiringTests.swift
//  SpaghettiTimerTests
//

import Foundation
import Testing
@testable import SpaghettiTimer

@Suite("Target wiring")
struct TargetWiringTests {
    /// Proves the test bundle is built, hosted, and can see the app module before
    /// any real assertion depends on it.
    @Test func testTargetIsWiredToTheAppModule() {
        #expect(TimerPreset.builtIns.count == 4)
    }

    /// iOS doesn't load an extension whose minimum is above the device's version,
    /// so a widget extension asking for more than the app would leave iPhones in
    /// between with the app but no widget and no Live Activity.
    @Test("The widget extension runs wherever the app installs")
    func widgetExtensionMinimumMatchesTheApp() throws {
        let plugIns = try FileManager.default.contentsOfDirectory(
            at: try #require(Bundle.main.builtInPlugInsURL), includingPropertiesForKeys: nil)
        let widget = try #require(plugIns.first { $0.pathExtension == "appex" }.flatMap(Bundle.init(url:)))
        let appMinimum = try #require(Bundle.main.object(forInfoDictionaryKey: "MinimumOSVersion") as? String)
        #expect(widget.object(forInfoDictionaryKey: "MinimumOSVersion") as? String == appMinimum)
    }
}
