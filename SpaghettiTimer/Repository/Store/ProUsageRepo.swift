//
//  ProUsageRepo.swift
//  SpaghettiTimer
//
//  Persists the free-tier usage counters that back the "try before buy"
//  gating (currently just the auto-restart use count). Stored in the shared
//  App Group defaults, matching every other repo in this app.
//

import Foundation

nonisolated protocol ProUsageRepo: Sendable {
    /// How many auto-restart timers a free user has already created.
    func autoRestartUseCount() -> Int
    /// Records one more auto-restart use.
    func incrementAutoRestartUse()
}

nonisolated final class ProUsageRepoImpl: ProUsageRepo {
    nonisolated(unsafe) private let defaults: UserDefaults

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
    }

    func autoRestartUseCount() -> Int {
        defaults.integer(forKey: AppGroupKey.autoRestartFreeUses)
    }

    func incrementAutoRestartUse() {
        defaults.set(autoRestartUseCount() + 1, forKey: AppGroupKey.autoRestartFreeUses)
    }
}

nonisolated extension AppGroupKey {
    static let autoRestartFreeUses = "pro.autoRestartFreeUses"
}
