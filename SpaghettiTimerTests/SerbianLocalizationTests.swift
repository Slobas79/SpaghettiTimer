//
//  SerbianLocalizationTests.swift
//  SpaghettiTimerTests
//
//  The Serbian strings are Latin script but used to ship only as `sr`, which
//  iOS reads as Cyrillic, so a phone on Srpski (latinica) fell back to English.
//  They now ship as `sr-Latn` too; these hold both scripts on Serbian.
//

import Foundation
import Testing
@testable import SpaghettiTimer

@Suite("Serbian localization")
struct SerbianLocalizationTests {
    /// The app and its widget extension, which carry their own string catalogs.
    private static var bundles: [Bundle] {
        let plugIns = (try? FileManager.default.contentsOfDirectory(
            at: Bundle.main.builtInPlugInsURL!, includingPropertiesForKeys: nil)) ?? []
        return [Bundle.main] + plugIns.filter { $0.pathExtension == "appex" }.compactMap(Bundle.init(url:))
    }

    private func lproj(_ language: String, in bundle: Bundle = .main) -> Bundle? {
        bundle.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:))
    }

    @Test("The app and the widget extension ship both Serbian scripts")
    func bothScriptsShip() {
        #expect(Self.bundles.count == 2)
        for bundle in Self.bundles {
            #expect(bundle.localizations.contains("sr"), "\(bundle.bundleURL.lastPathComponent)")
            #expect(bundle.localizations.contains("sr-Latn"), "\(bundle.bundleURL.lastPathComponent)")
        }
    }

    @Test("A Latin-script Serbian phone gets Serbian, not English",
          arguments: ["sr-Latn", "sr-Latn-RS", "sr-Latn-BA", "sr-Latn-ME"])
    func latinPicksSerbian(preference: String) {
        for bundle in Self.bundles {
            #expect(Bundle.preferredLocalizations(from: bundle.localizations, forPreferences: [preference])
                    == ["sr-Latn"])
        }
    }

    @Test("A Cyrillic or unmarked Serbian phone still gets Serbian",
          arguments: ["sr", "sr-Cyrl", "sr-RS", "sr-Cyrl-RS"])
    func cyrillicPicksSerbian(preference: String) {
        for bundle in Self.bundles {
            #expect(Bundle.preferredLocalizations(from: bundle.localizations, forPreferences: [preference])
                    == ["sr"])
        }
    }

    @Test("sr-Latn carries the Serbian strings and the alarm permission text")
    func latinStringsAreSerbian() {
        let latin = lproj("sr-Latn")
        #expect(latin?.localizedString(forKey: "Cancel", value: nil, table: nil) == "Otkaži")
        #expect(latin?.localizedString(forKey: "NSAlarmKitUsageDescription", value: nil, table: "InfoPlist")
                == "Spaghetti Timer koristi alarme da zazvoni kada se vaši tajmeri završe.")
        #expect(latin?.localizedString(forKey: "CFBundleDisplayName", value: nil, table: "InfoPlist")
                == "Spaghetti Timer")
    }

    @Test("The widget's sr-Latn strings are Serbian")
    func widgetStringsAreSerbian() throws {
        let widget = try #require(Self.bundles.first { $0 != .main })
        #expect(lproj("sr-Latn", in: widget)?.localizedString(forKey: "Cancel timer", value: nil, table: nil)
                == "Otkaži tajmer")
    }
}
