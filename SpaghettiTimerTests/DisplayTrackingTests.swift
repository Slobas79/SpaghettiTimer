//
//  DisplayTrackingTests.swift
//  SpaghettiTimerTests
//
//  Letter spacing broke Arabic's joined letters (“ا لتلميح”). These hold the
//  rule that decides which languages keep their tracking.
//

import Foundation
import Testing
@testable import SpaghettiTimer

@Suite("Letter spacing on labels")
struct DisplayTrackingTests {
    @Test("Arabic ships, and its letters join, so its labels get no letter spacing")
    func arabicDropsTracking() {
        #expect(Bundle.main.localizations.contains("ar"))
        #expect(DisplayTracking.joinsLetters("ar"))
    }

    @Test("Every other language the app ships keeps its letter spacing")
    func otherLanguagesKeepTracking() {
        let others = Bundle.main.localizations.filter { $0 != "ar" && $0 != "Base" }
        #expect(others.contains("en") && others.contains("ja"))
        for language in others {
            #expect(!DisplayTracking.joinsLetters(language), "\(language)")
        }
    }

    @Test("Other languages written in joined scripts would drop it too",
          arguments: ["fa", "ur", "ar-EG", "syr"])
    func otherJoinedScripts(language: String) {
        #expect(DisplayTracking.joinsLetters(language))
    }

    @Test("An unknown language keeps its letter spacing")
    func unknownLanguage() {
        #expect(!DisplayTracking.joinsLetters("zz"))
    }
}
