//
//  FreeTryRepo.swift
//  SpaghettiTimer
//
//  Which one-time free tries of a Pro feature a free user has already spent.
//  Kept in the Keychain for the same reason as the pin allowance: the App
//  Group suite is wiped when the app is deleted, so a reinstall would hand
//  the tries back. Keychain items outlive the app.
//
//  App-target only — the widget never starts a timer with a Pro feature.
//

import Foundation
import Security

/// A Pro feature a free user may start once, unpinned, before the paywall.
nonisolated enum FreeTry: String, CaseIterable, Sendable {
    /// One auto-restarting timer.
    case autoRestart
    /// One timer started from the End time tab.
    case endTime
}

nonisolated protocol FreeTryRepo: Sendable {
    func isSpent(_ freeTry: FreeTry) -> Bool
    func markSpent(_ freeTry: FreeTry)
}

nonisolated final class KeychainFreeTryRepo: FreeTryRepo {
    static let service = "sloba.SpaghettiTimer.freeTry"

    private let accountPrefix: String

    /// - Parameter accountPrefix: tests pass their own, so they never spend the
    ///   simulator app's real tries.
    init(accountPrefix: String = "") {
        self.accountPrefix = accountPrefix
    }

    private func itemQuery(_ freeTry: FreeTry) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: accountPrefix + freeTry.rawValue
        ]
    }

    func isSpent(_ freeTry: FreeTry) -> Bool {
        SecItemCopyMatching(itemQuery(freeTry) as CFDictionary, nil) == errSecSuccess
    }

    func markSpent(_ freeTry: FreeTry) {
        guard !isSpent(freeTry) else { return }
        var item = itemQuery(freeTry)
        item[kSecValueData as String] = Data("spent".utf8)
        // Readable in the background once the phone has been unlocked, and carried
        // to a new phone by an encrypted backup — but never synced via iCloud.
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(item as CFDictionary, nil)
    }
}

/// Holds the spent tries for the life of the instance only. The store's
/// default, so one built without a repo — tests, previews — never touches the
/// real Keychain items; the app passes `KeychainFreeTryRepo`.
nonisolated final class InMemoryFreeTryRepo: FreeTryRepo, @unchecked Sendable {
    private let lock = NSLock()
    private var spent: Set<FreeTry> = []

    func isSpent(_ freeTry: FreeTry) -> Bool {
        lock.withLock { spent.contains(freeTry) }
    }

    func markSpent(_ freeTry: FreeTry) {
        lock.withLock { _ = spent.insert(freeTry) }
    }
}
