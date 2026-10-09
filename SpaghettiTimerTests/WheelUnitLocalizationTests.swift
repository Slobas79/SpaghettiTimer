//
//  WheelUnitLocalizationTests.swift
//  SpaghettiTimerTests
//
//  The duration and cooldown wheels used to label their columns with a plain
//  "h", "m" and "s", so every language showed the English letters. These hold
//  the symbols to the string catalog in each language the app ships.
//

import Foundation
import Testing
import UIKit
@testable import SpaghettiTimer

@Suite("Wheel unit symbols")
struct WheelUnitLocalizationTests {
    /// Every language the app ships, other than the English source.
    private static var languages: [String] {
        Bundle.main.localizations.filter { $0 != "en" && $0 != "Base" }.sorted()
    }

    private func symbols(in language: String) -> [String] {
        WheelUnit.allCases.map { unit in
            var symbol = unit.symbol
            symbol.locale = Locale(identifier: language)
            return String(localized: symbol)
        }
    }

    @Test("Every shipped language has its own symbol for each unit")
    func everyLanguageIsTranslated() throws {
        #expect(Self.languages.count == 23)
        for language in Self.languages {
            let lproj = try #require(Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)))
            for unit in WheelUnit.allCases {
                let missing = "\u{0}missing"
                #expect(lproj.localizedString(forKey: unit.symbol.key, value: missing, table: nil) != missing,
                        "\(language) has no \(unit) symbol")
            }
        }
    }

    @Test("The wheels show each language's own unit symbols",
          arguments: [
            ("en", ["h", "m", "s"]),
            ("ja", ["時間", "分", "秒"]),
            ("ar", ["س", "د", "ث"]),
            ("ru", ["ч", "мин", "с"]),
            ("bg", ["ч", "мин", "с"]),
            ("el", ["ώ", "λ", "δ"]),
            ("hu", ["ó", "p", "mp"]),
            ("de", ["h", "min", "s"]),
            ("sr-Latn", ["h", "min", "s"])
          ])
    func symbolsResolvePerLocale(language: String, expected: [String]) {
        #expect(symbols(in: language) == expected)
    }

    /// The wheel's trailing padding assumes the seconds symbol sits inside its
    /// 28pt slot with room to spare; a wider one would crowd the band's edge.
    @Test("Every language's seconds symbol fits the wheel's 28pt trailing slot")
    func secondsSymbolFitsTrailingSlot() {
        let font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        for language in ["en"] + Self.languages {
            let seconds = symbols(in: language)[2]
            let width = (seconds as NSString).size(withAttributes: [.font: font]).width
            #expect(width < 28, "\(language) “\(seconds)” is \(width)pt wide")
        }
    }
}
