//
//  PinAllowanceRepo.swift
//  SpaghettiTimer
//
//  How many user presets have ever been pinned — what the free pin cap counts.
//  Kept in the Keychain rather than `UserDefaults`: the App Group suite is wiped
//  when the app is deleted, so a reinstall would hand a free user a fresh set
//  of pins. Keychain items outlive the app.
//
//  App-target only — the widget never pins, so it never needs the count.
//

import Foundation
import Security

nonisolated protocol PinAllowanceRepo: Sendable {
    /// How many user presets have ever been pinned. Unpinning doesn't lower it,
    /// so a deleted preset never hands back a free pin.
    func loadLifetimePinCount() -> Int
    func saveLifetimePinCount(_ count: Int)
}

nonisolated final class KeychainPinAllowanceRepo: PinAllowanceRepo {
    static let service = "sloba.SpaghettiTimer.pinAllowance"

    private let account: String

    /// - Parameter account: tests pass their own, so they never spend the
    ///   simulator app's real pins.
    init(account: String = "lifetimePinCount") {
        self.account = account
    }

    private var itemQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account
        ]
    }

    func loadLifetimePinCount() -> Int {
        var query = itemQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let count = Int(String(decoding: data, as: UTF8.self)) else { return 0 }
        return count
    }

    func saveLifetimePinCount(_ count: Int) {
        let data = Data(String(count).utf8)
        let status = SecItemUpdate(itemQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        guard status == errSecItemNotFound else { return }
        var item = itemQuery
        item[kSecValueData as String] = data
        // Readable in the background once the phone has been unlocked, and carried
        // to a new phone by an encrypted backup — but never synced via iCloud.
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(item as CFDictionary, nil)
    }
}

/// Holds the count for the life of the instance only. The presets use case's
/// default, so one built without an allowance — tests, previews — never touches
/// the real Keychain item; the app passes `KeychainPinAllowanceRepo`.
nonisolated final class InMemoryPinAllowanceRepo: PinAllowanceRepo, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func loadLifetimePinCount() -> Int {
        lock.withLock { count }
    }

    func saveLifetimePinCount(_ count: Int) {
        lock.withLock { self.count = count }
    }
}
