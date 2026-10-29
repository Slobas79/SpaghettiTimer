//
//  ProEntitlementTests.swift
//  SpaghettiTimerTests
//
//  QA 13.10: after a purchase the paywall closed, then Pin opened it again.
//  The purchase sheet bounces the app through `.inactive` → `.active`, and
//  the foreground entitlement refresh read StoreKit's list before the purchase
//  was in it, putting the user back on the free tier.
//

import Foundation
import Testing
@testable import SpaghettiTimer

@Suite("Pro entitlement · purchase vs refresh")
struct ProEntitlementTests {

    @Test("A fresh install is free")
    func startsFree() {
        #expect(!ProEntitlement().isPro)
    }

    @Test("A purchase unlocks Pro")
    func purchaseUnlocks() {
        var entitlement = ProEntitlement()
        entitlement.receivedTransaction(revoked: false)
        #expect(entitlement.isPro)
    }

    @Test("A stale refresh after a purchase keeps Pro (QA 13.10)")
    func staleRefreshKeepsPurchase() {
        var entitlement = ProEntitlement()
        entitlement.receivedTransaction(revoked: false)

        entitlement.readEntitlements(owned: false)

        #expect(entitlement.isPro)
    }

    @Test("A refresh still unlocks a purchase made elsewhere")
    func refreshFindsPurchase() {
        var entitlement = ProEntitlement()
        entitlement.readEntitlements(owned: true)
        #expect(entitlement.isPro)
    }

    @Test("Without a purchase this session, a refresh can take Pro away")
    func refreshDropsLostEntitlement() {
        var entitlement = ProEntitlement()
        entitlement.readEntitlements(owned: true)

        entitlement.readEntitlements(owned: false)

        #expect(!entitlement.isPro)
    }

    @Test("A refund ends Pro, and a later refresh doesn't bring it back")
    func refundEndsPro() {
        var entitlement = ProEntitlement()
        entitlement.receivedTransaction(revoked: false)

        entitlement.receivedTransaction(revoked: true)
        #expect(!entitlement.isPro)

        entitlement.readEntitlements(owned: false)
        #expect(!entitlement.isPro)
    }

    @Test("After a refund, another entitlement found by refresh still counts")
    func refundWithFamilyEntitlement() {
        var entitlement = ProEntitlement()
        entitlement.receivedTransaction(revoked: false)
        entitlement.receivedTransaction(revoked: true)

        entitlement.readEntitlements(owned: true)

        #expect(entitlement.isPro)
    }
}
