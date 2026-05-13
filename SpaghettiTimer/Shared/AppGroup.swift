//
//  AppGroup.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 23. 4. 2026..
//

import Foundation

nonisolated enum AppGroup {
    static let id = "group.sloba.SpaghettiTimer"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: id) ?? .standard
    }
}

nonisolated enum AppGroupKey {
    static let userPresets = "presets.user"
    static let hiddenBuiltInPresets = "presets.hiddenBuiltIns"
    static let runningTimers = "runningTimers"
}
