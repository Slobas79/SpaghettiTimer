//
//  DisplayUppercase.swift
//  SpaghettiTimer
//
//  All-caps labels (the New Timer group headers, “Timer ends”, the tour's
//  “Tip 1 of 5”) used plain `uppercased()`, which ignores the language, so
//  Greek capitals kept their accents: “ΔΙΆΡΚΕΙΑ” instead of “ΔΙΑΡΚΕΙΑ”.
//

import Foundation

nonisolated extension String {
    /// Uppercased by the rules of `language`, which defaults to the language
    /// the app's strings are shown in, so Greek capitals drop their accents.
    ///
    /// Not `Locale.current`: a phone set to a language the app doesn't ship,
    /// such as Turkish, shows the app in English, and Turkish rules would
    /// turn “Timer ends” into “TİMER ENDS”.
    func uppercasedForDisplay(language: String = Bundle.main.preferredLocalizations.first ?? "en") -> String {
        uppercased(with: Locale(identifier: language))
    }
}
