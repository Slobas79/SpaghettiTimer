//
//  ProEntitlement.swift
//  SpaghettiTimer
//
//  Whether the user owns Pro, from the two places StoreKit reports it: a
//  transaction delivered live (a purchase, or `Transaction.updates`) and a
//  snapshot of `Transaction.currentEntitlements`. The snapshot can be stale:
//  the purchase sheet bounces the app through `.inactive` → `.active`, and the
//  foreground refresh that sets off can read the list before the new purchase
//  is in it. So a snapshot never takes back a purchase seen live this session —
//  only a revocation does.
//

import Foundation

nonisolated struct ProEntitlement: Equatable, Sendable {
    private(set) var isPro = false
    /// A verified, unrevoked Pro transaction was delivered live this session.
    private var verifiedLive = false

    /// A verified Pro transaction arrived from a purchase or `Transaction.updates`.
    mutating func receivedTransaction(revoked: Bool) {
        verifiedLive = !revoked
        isPro = !revoked
    }

    /// A `Transaction.currentEntitlements` read finished. `owned` may describe
    /// the moment the read started, so it can't undo a live purchase.
    mutating func readEntitlements(owned: Bool) {
        isPro = owned || verifiedLive
    }
}
