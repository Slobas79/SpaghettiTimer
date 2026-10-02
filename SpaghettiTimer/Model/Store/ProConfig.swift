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

    /// Free users may pin this many (user) presets over the life of the install.
    /// Unpinning doesn't give one back, and built-ins never count against the
    /// cap. Pinning past it triggers the paywall.
    static let freePinLimit = 3

    // Auto-restart and End time have no free cap — just one free try each
    // (`FreeTry`): a single start, never pinned, then the paywall.
}
