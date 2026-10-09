//
//  DisplayTracking.swift
//  SpaghettiTimer
//
//  Letter-spaced labels (the tour's “Tip 1 of 5”, the New Timer group
//  headers, “Timer ends”, the To next hour badge) pulled Arabic apart:
//  tracking puts space between letters that are drawn joined, so the tour's
//  eyebrow read “ا لتلميح” instead of “التلميح”.
//

import SwiftUI

nonisolated enum DisplayTracking {
    /// Scripts whose letters join up: Arabic (and the Nastaliq form Urdu is
    /// written in), Syriac, N'Ko, Mongolian, Adlam and Hanifi Rohingya.
    private static let joiningScripts: Set<String> = ["Arab", "Aran", "Syrc", "Nkoo", "Mong", "Adlm", "Rohg"]

    /// Whether `language` is written in a script whose letters join, which
    /// letter spacing would break.
    static func joinsLetters(_ language: String) -> Bool {
        guard let script = Locale.Language(identifier: language).script else { return false }
        return joiningScripts.contains(script.identifier)
    }
}

extension View {
    /// Letter spacing for a label, dropped when `language` — by default the
    /// language the app's strings are shown in — joins its letters.
    func trackingForDisplay(_ tracking: CGFloat,
                            language: String = Bundle.main.preferredLocalizations.first ?? "en") -> some View {
        self.tracking(DisplayTracking.joinsLetters(language) ? 0 : tracking)
    }
}
