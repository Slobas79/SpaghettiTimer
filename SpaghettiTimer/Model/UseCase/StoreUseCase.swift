//
//  StoreUseCase.swift
//  SpaghettiTimer
//
//  Owns the StoreKit 2 lifecycle for the single "Pro" non-consumable: loads
//  the product, tracks the entitlement (`isPro`), runs purchase / restore, and
//  answers the gating questions the UI asks ("can this user pin more?",
//  "can this user enable auto-restart?", "can this user set an End time?").
//  Also keeps the one-time free tries of auto-restart and End time.
//  Observable so views react to the entitlement flipping on after a purchase
//  or restore.
//
//  App-target only — the widget extension never imports StoreKit. Premium
//  features are gated at *creation* time inside the app, so the widget can run
//  whatever presets already exist without any entitlement awareness.
//

import Foundation
import StoreKit
import Observation

@MainActor
@Observable
final class StoreUseCase {
    /// True once the user owns the lifetime Pro unlock. Drives every gate.
    private(set) var isPro: Bool = false
    /// The loaded StoreKit product, or nil until `loadProduct()` succeeds.
    private(set) var product: Product?
    private(set) var isLoadingProduct = false
    /// A purchase or restore is in flight — used to disable the paywall buttons.
    private(set) var purchaseInFlight = false
    /// Free tries already used up. Each is spent once its timer has started.
    private(set) var spentFreeTries: Set<FreeTry>

    @ObservationIgnored private let analytics: AnalyticsRepo
    @ObservationIgnored private let freeTryRepo: FreeTryRepo
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init(analytics: AnalyticsRepo = NoOpAnalyticsRepo(), freeTries: FreeTryRepo = InMemoryFreeTryRepo()) {
        self.analytics = analytics
        self.freeTryRepo = freeTries
        spentFreeTries = Set(FreeTry.allCases.filter(freeTries.isSpent))
    }

    /// Inert instance for SwiftUI previews — no product load, no listeners.
    static var preview: StoreUseCase { StoreUseCase() }

    // MARK: - Display

    /// Localized price for the unlock button, or nil until the product loads.
    var displayPrice: String? { product?.displayPrice }

    /// Whether the unlock button should be tappable.
    var canPurchase: Bool { product != nil && !purchaseInFlight }

    // MARK: - Lifecycle

    /// Begin listening for transaction updates and refresh state. Call once at
    /// app launch. Kept out of `init` so previews stay side-effect free.
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { await refreshEntitlements() }
        Task { await loadProduct() }
    }

    func loadProduct() async {
        isLoadingProduct = true
        defer { isLoadingProduct = false }
        do {
            let products = try await Product.products(for: [ProConfig.productID])
            product = products.first
            if products.isEmpty {
                print("[Store] no product returned for \(ProConfig.productID) — StoreKit answered with an empty list. Check the scheme's StoreKit configuration and the product ID.")
            } else {
                print("[Store] loaded \(products.count) product(s): \(products.map(\.id))")
            }
        } catch {
            print("[Store] product load failed: \(error)")
        }
    }

    /// Recomputes `isPro` from the current set of StoreKit entitlements.
    func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == ProConfig.productID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        isPro = owned
    }

    // MARK: - Purchase / restore

    /// Attempts the purchase. Returns true when the user ends up entitled.
    @discardableResult
    func purchase() async -> Bool {
        guard let product else { return false }
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                await handle(verification)
                if isPro { analytics.log(.purchaseSuccess()) }
                return isPro
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    /// Restores prior purchases (required by App Review for non-consumables).
    func restore() async {
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        try? await AppStore.sync()
        await refreshEntitlements()
        analytics.log(.purchaseRestore(restoredPro: isPro))
    }

    private func handle(_ verification: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = verification else { return }
        if transaction.productID == ProConfig.productID, transaction.revocationDate == nil {
            isPro = true
        }
        await transaction.finish()
    }

    // MARK: - Gating

    /// Pinning is allowed for Pro users, or while free pins remain. Pass the
    /// lifetime pin count, not the tiles on the grid — unpinning doesn't hand a
    /// free pin back.
    func canPin(currentUserPresetCount count: Int) -> Bool {
        isPro || count < ProConfig.freePinLimit
    }

    /// The dynamic "To next hour" tile is Pro-only — there is no free trial for
    /// it the way there is for auto-restart, and it doesn't count against the
    /// free pin cap.
    func canPinNextHour() -> Bool {
        isPro
    }

    /// Auto-restart is Pro-only — a free user's single free try aside
    /// (`hasFreeTry(.autoRestart)`), which can't be pinned.
    func canEnableAutoRestart() -> Bool {
        isPro
    }

    /// Starting a timer by End time (picking the clock time it finishes at) is
    /// Pro-only — a free user's single free try aside (`hasFreeTry(.endTime)`).
    /// Free users can still open the End time tab and dial a time — once the
    /// try is spent, Start (and the pin) open the paywall instead.
    func canUseEndTime() -> Bool {
        isPro
    }

    /// Whether a free user can still start one unpinned timer with this Pro
    /// feature. Pro users don't need it, so it's never spent for them.
    func hasFreeTry(_ freeTry: FreeTry) -> Bool {
        !spentFreeTries.contains(freeTry)
    }

    /// Spends `freeTry` once `start` reports the timer actually started, so a
    /// start dropped at the alarm permission prompt doesn't use it up.
    @discardableResult
    func spendFreeTry(_ freeTry: FreeTry, ifStarted start: Task<Bool, Never>) -> Task<Void, Never> {
        // Holds the store strongly: the sheet that asked is already dismissed,
        // and a try must be recorded however long the permission prompt takes.
        Task {
            guard await start.value else { return }
            freeTryRepo.markSpent(freeTry)
            spentFreeTries.insert(freeTry)
        }
    }

    // MARK: - Analytics

    func logPaywallShown(_ trigger: PaywallTrigger) {
        analytics.log(.paywallShow(trigger: trigger.rawValue))
    }
}

// MARK: - Pro analytics events (app-only)

nonisolated extension AnalyticsEvent {
    private static func flag(_ value: Bool) -> AnalyticsValue { .string(value ? "true" : "false") }

    static func paywallShow(trigger: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "paywall_show", params: [
            "source": .string(AnalyticsSource.app.rawValue),
            "trigger": .string(trigger)
        ])
    }

    static func purchaseSuccess() -> AnalyticsEvent {
        AnalyticsEvent(name: "purchase_success", params: [
            "source": .string(AnalyticsSource.app.rawValue)
        ])
    }

    static func purchaseRestore(restoredPro: Bool) -> AnalyticsEvent {
        AnalyticsEvent(name: "purchase_restore", params: [
            "source": .string(AnalyticsSource.app.rawValue),
            "restored_pro": flag(restoredPro)
        ])
    }
}
