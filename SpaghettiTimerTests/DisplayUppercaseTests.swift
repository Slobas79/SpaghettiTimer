//
//  DisplayUppercaseTests.swift
//  SpaghettiTimerTests
//
//  The all-caps labels used `uppercased()`, which ignores the language, so
//  Greek capitals kept their accents (“ΔΙΆΡΚΕΙΑ”). These hold them to the
//  rules of the language the app is shown in.
//

import Foundation
import Testing
@testable import SpaghettiTimer

@Suite("All-caps labels")
struct DisplayUppercaseTests {
    private func greek(_ key: String) throws -> String {
        let lproj = try #require(Bundle.main.path(forResource: "el", ofType: "lproj").flatMap(Bundle.init(path:)))
        return lproj.localizedString(forKey: key, value: nil, table: nil)
    }

    @Test("Greek labels drop their accents in capitals",
          arguments: [
            ("Name", "ΟΝΟΜΑ"),
            ("Set timer by", "ΟΡΙΣΜΟΣ ΧΡΟΝΟΜΕΤΡΟΥ ΚΑΤΑ"),
            ("Duration", "ΔΙΑΡΚΕΙΑ"),
            ("End time", "ΩΡΑ ΛΗΞΗΣ"),
            ("Options", "ΕΠΙΛΟΓΕΣ"),
            ("Timer ends", "ΤΟ ΧΡΟΝΟΜΕΤΡΟ ΛΗΓΕΙ")
          ])
    func greekDropsAccents(key: String, expected: String) throws {
        #expect(try greek(key).uppercasedForDisplay(language: "el") == expected)
    }

    @Test("The tour's Greek tip counter drops its accents in capitals")
    func greekTipCounter() throws {
        let tip = String(format: try greek("Tip %lld of %lld"), 1, 5)
        #expect(tip.uppercasedForDisplay(language: "el") == "ΣΥΜΒΟΥΛΗ 1 ΑΠΟ 5")
    }

    @Test("A phone in a language the app doesn't ship capitalizes the English it falls back to by English rules")
    func fallbackUsesEnglishRules() throws {
        // Turkish rules would capitalize “i” as “İ”.
        let shown = try #require(Bundle.preferredLocalizations(from: Bundle.main.localizations,
                                                               forPreferences: ["tr-TR"]).first)
        #expect(shown == "en")
        #expect("Timer ends".uppercasedForDisplay(language: shown) == "TIMER ENDS")
        #expect("Tip 1 of 5".uppercasedForDisplay(language: shown) == "TIP 1 OF 5")
    }

    @Test("By default the label follows the language the app is shown in")
    func defaultsToAppLanguage() {
        let shown = Bundle.main.preferredLocalizations.first ?? "en"
        #expect("Διάρκεια".uppercasedForDisplay() == "Διάρκεια".uppercased(with: Locale(identifier: shown)))
    }
}
