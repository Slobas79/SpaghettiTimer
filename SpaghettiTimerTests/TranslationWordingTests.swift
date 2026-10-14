//
//  TranslationWordingTests.swift
//  SpaghettiTimerTests
//
//  A run through all 23 languages on an iPhone SE turned up wording and
//  line-break problems in a few translations (Watchlist ST-18): a Dutch paywall
//  line that read as "one tap deleted", "11 h 00" split across lines in French,
//  the English plural "timers" in Swedish, and labels that broke mid-word in
//  Bulgarian, Polish, Hungarian and Japanese. These hold the fixed strings.
//

import Foundation
import Testing
import CoreText
import UIKit
@testable import SpaghettiTimer

@Suite("Translation wording")
struct TranslationWordingTests {
    /// Every language the app ships, the English source included.
    private static var languages: [String] {
        Bundle.main.localizations.filter { $0 != "Base" }.sorted()
    }

    /// The app and its widget extension, which carry their own string catalogs.
    private static var bundles: [Bundle] {
        let plugIns = (try? FileManager.default.contentsOfDirectory(
            at: Bundle.main.builtInPlugInsURL!, includingPropertiesForKeys: nil)) ?? []
        return [Bundle.main] + plugIns.filter { $0.pathExtension == "appex" }.compactMap(Bundle.init(url:))
    }

    private func lproj(_ language: String, in bundle: Bundle = .main) throws -> Bundle {
        try #require(bundle.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)),
                     "\(bundle.bundleURL.lastPathComponent) has no \(language).lproj")
    }

    /// The string a language shows for `key`. English, the source language,
    /// shows the key itself when its table has no entry for it.
    private func string(_ key: String, in language: String) throws -> String {
        let missing = "\u{0}missing"
        let value = try lproj(language).localizedString(forKey: key, value: missing, table: nil)
        if value == missing, language == "en" { return key }
        try #require(value != missing, "\(language) has no “\(key)”")
        return value
    }

    /// Every string in a compiled table (`.strings` or `.stringsdict`), plural forms included.
    private func allValues(in plist: Any) -> [String] {
        switch plist {
        case let string as String: [string]
        case let dictionary as [String: Any]: dictionary.values.flatMap(allValues(in:))
        case let array as [Any]: array.flatMap(allValues(in:))
        default: []
        }
    }

    /// How wide `text` draws in `language`. The language matters: the system
    /// font switches to localized letterforms, and Bulgarian Cyrillic is wider
    /// than the default (“Продължителност” is 138pt plain but 149pt in Bulgarian).
    private func width(_ text: String, in language: String, size: CGFloat, weight: UIFont.Weight) -> CGFloat {
        NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            NSAttributedString.Key(kCTLanguageAttributeName as String): language
        ]).size().width
    }

    @Test("Dutch paywall: pinned timers are one tap away, not “one tap deleted”")
    func dutchPinLine() throws {
        let line = try string("Pin as many timers as you like, always one tap away.", in: "nl")
        #expect(line == "Zet zoveel timers vast als je wilt — altijd met één tik bereikbaar.")
        #expect(!line.contains("verwijderd"))
    }

    @Test("French End time tip keeps “11 h 00” on one line")
    func frenchTimeDoesNotBreak() throws {
        let body = try string("Switch to End time and choose when the timer should finish — like 11:00 AM. The duration is set for you.",
                              in: "fr")
        #expect(body.contains("11\u{a0}h\u{a0}00"))
        #expect(!body.contains("11 h"))
    }

    @Test("Swedish uses “timrar”, never the English plural “timers”")
    func swedishPlural() throws {
        var checked = 0
        for bundle in Self.bundles {
            let sv = try lproj("sv", in: bundle)
            let tables = (sv.urls(forResourcesWithExtension: "strings", subdirectory: nil) ?? [])
                + (sv.urls(forResourcesWithExtension: "stringsdict", subdirectory: nil) ?? [])
            for table in tables {
                let plist = try #require(NSDictionary(contentsOf: table))
                for value in allValues(in: plist) {
                    checked += 1
                    #expect(!value.localizedCaseInsensitiveContains("timers"),
                            "\(bundle.bundleURL.lastPathComponent) \(table.lastPathComponent): “\(value)”")
                }
            }
        }
        #expect(checked > 100)
        #expect(try string("Pinned timers stay on this screen and appear in the widget.", in: "sv")
                == "Fastnålade timrar stannar på den här skärmen och visas i widgeten.")
    }

    // MARK: - Fit on an iPhone SE (375pt wide)

    /// New Timer's mode picker on an SE: the sheet's 20pt margins, the track's
    /// 3pt inset and the 3pt gap between the two segments leave each one 163pt
    /// for its icon, the 7pt gap and the label. A wider label wraps inside the
    /// segment's fixed height, and a single long word breaks mid-word.
    @Test("Every language's Duration and End time labels fit their mode picker segment on an iPhone SE")
    func modePickerLabelsFit() throws {
        let segment: CGFloat = (375 - 2 * 20 - 2 * 3 - 3) / 2
        let symbol = UIImage.SymbolConfiguration(font: .systemFont(ofSize: 15, weight: .semibold))
        for (key, icon) in [("Duration", "hourglass"), ("End time", "clock")] {
            let iconWidth = try #require(UIImage(systemName: icon, withConfiguration: symbol)).size.width
            for language in Self.languages {
                let label = try string(key, in: language)
                let used = iconWidth + 7 + width(label, in: language, size: 15, weight: .semibold)
                #expect(used <= segment, "\(language) “\(label)” needs \(used)pt of \(segment)pt")
            }
        }
    }

    /// The tour card on an SE: 20pt from each screen edge plus 16pt of padding
    /// leaves 303pt. Above the mode picker there is room for only one title
    /// line, so a longer title was cut off ("…befejezési időpo…" in Hungarian).
    @Test("Every language's End time tip title fits the tour card on one line on an iPhone SE")
    func endTimeTipTitleFits() throws {
        let card: CGFloat = 375 - 2 * 20 - 2 * 16
        for language in Self.languages {
            let title = try string("Or pick an end time", in: language)
            let used = width(title, in: language, size: 18, weight: .bold)
            #expect(used <= card, "\(language) “\(title)” needs \(used)pt of \(card)pt")
        }
    }

    /// The Auto-restart row on an SE: the sheet's 20pt margins, the row's 16pt
    /// padding, the 30pt icon, three 14pt gaps and the switch. Most languages
    /// wrap the title onto a second line at a space; Japanese has no spaces,
    /// and wrapping split 再スタート as “再 / スタート”.
    @Test("The Japanese Auto-restart title fits on one line on an iPhone SE")
    func japaneseAutoRestartTitleFits() throws {
        let toggle = UISwitch().intrinsicContentSize.width
        let column = 375 - 2 * 20 - 2 * 16 - 30 - 3 * 14 - toggle
        let title = try string("Auto-restart after finish", in: "ja")
        #expect(title == "自動で再スタート")
        #expect(width(title, in: "ja", size: 17, weight: .semibold) <= column)
    }
}
