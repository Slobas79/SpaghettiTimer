//
//  ProConfig.swift
//  SpaghettiTimer
//
//  Single source of truth for the monetization model: one non-consumable
//  "Pro" unlock plus the free-tier caps that gate the premium features.
//  Kept in one place so the caps can be tuned from real stall data without
//  hunting through the codebase (see the Pricing & Paywall spec).
//

import Foundation

nonisolated enum ProConfig {
    /// StoreKit product identifier for the lifetime "Pro" unlock (non-consumable).
    /// Must match the product ID in App Store Connect / `SpaghettiTimer.storekit`.
    static let productID = "com.spaghettitimer.pro.lifetime"

    /// Free users may keep up to this many pinned (user) presets. Built-ins
    /// never count against the cap. Pinning past it triggers the paywall.
    static let freePinLimit = 3

    /// Auto-restart is "try before buy": free users may create this many
    /// auto-restart timers before the paywall takes over.
    static let freeAutoRestartUses = 3
}
