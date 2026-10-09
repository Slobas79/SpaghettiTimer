//
//  FreePinNoticeTests.swift
//  SpaghettiTimerTests
//
//  A free pin is spent when a timer is pinned and never comes back on unpin
//  (ST-21). The New Timer sheet says what pinning costs, and Home confirms
//  before a free user unpins; Pro sees neither.
//

import Foundation
import Testing
@testable import SpaghettiTimer

@Suite("Free pin notice")
struct FreePinNoticeTests {

    @Test("Pro has no allowance to announce and unpins without asking", arguments: 0...5)
    func proSeesNothing(lifetimePinCount: Int) {
        #expect(FreePinNotice.current(isPro: true, lifetimePinCount: lifetimePinCount) == nil)
    }

    @Test("A free user is told how many pins pinning leaves")
    func freeUserCountsDown() {
        #expect(FreePinNotice.current(isPro: false, lifetimePinCount: 0) == .spends(leftAfter: 2))
        #expect(FreePinNotice.current(isPro: false, lifetimePinCount: 1) == .spends(leftAfter: 1))
        #expect(FreePinNotice.current(isPro: false, lifetimePinCount: 2) == .spendsLast)
    }

    @Test("Once the free pins are spent they stay spent", arguments: 3...6)
    func freeUserUsedUp(lifetimePinCount: Int) {
        #expect(FreePinNotice.current(isPro: false, lifetimePinCount: lifetimePinCount) == .usedUp)
    }

    @Test("The notice follows the free pin limit")
    func followsTheLimit() {
        let limit = ProConfig.freePinLimit
        #expect(FreePinNotice.current(isPro: false, lifetimePinCount: 0) == .spends(leftAfter: limit - 1))
        #expect(FreePinNotice.current(isPro: false, lifetimePinCount: limit - 1) == .spendsLast)
        #expect(FreePinNotice.current(isPro: false, lifetimePinCount: limit) == .usedUp)
    }
}

@Suite("Free pin strings")
struct FreePinStringsTests {
    private static let missing = "⟨missing⟩"

    /// Every language the app ships besides the English source.
    private static var languages: [String] {
        Bundle.main.localizations.filter { $0 != "en" && $0 != "Base" }.sorted()
    }

    private func lproj(_ language: String) -> Bundle? {
        Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:))
    }

    @Test("Every free pin string is translated in every shipped language", arguments: [
        "Uses your last free pin. Unpinning doesn't give it back.",
        "You've used all your free pins.",
        "Unpin “%@”?",
        "Unpinning doesn't give back a free pin, so pinning it again later uses one.",
        "Unpinning doesn't give back a free pin, and you've used them all — pinning it again needs Pro.",
        "Unpin",
        "You've used all your free pins. Go unlimited — and unlock auto-restart while you're at it.",
    ])
    func translated(key: String) throws {
        #expect(Self.languages.count == 23)
        for language in Self.languages {
            let bundle = try #require(lproj(language), "\(language)")
            let value = bundle.localizedString(forKey: key, value: Self.missing, table: nil)
            #expect(value != Self.missing && value != key, "\(language)")
        }
    }

    @Test("The pins-left caption puts the count in every language", arguments: [1, 2])
    func pinsLeftCaption(left: Int) throws {
        let key = "Uses a free pin — you'll have %lld left. Unpinning doesn't give it back."
        for language in Self.languages {
            let bundle = try #require(lproj(language), "\(language)")
            let format = bundle.localizedString(forKey: key, value: Self.missing, table: nil)
            #expect(format != Self.missing && format != key, "\(language)")
            let text = String(format: format, locale: Locale(identifier: language), left)
            #expect(!text.contains("%"), "\(language): \(text)")
            #expect(text.contains(String(left)) || text.contains(left.formatted(.number.locale(Locale(identifier: language)))),
                    "\(language): \(text)")
        }
    }

    @Test("The old “filled your free presets” subhead is gone")
    func oldSubheadRemoved() throws {
        let key = "You've filled your free presets. Go unlimited — and unlock auto-restart while you're at it."
        for language in Self.languages {
            let bundle = try #require(lproj(language), "\(language)")
            #expect(bundle.localizedString(forKey: key, value: Self.missing, table: nil) == Self.missing, "\(language)")
        }
    }
}

/// The Debug-only `-resetFreePins` launch argument: QA's one way to get the free
/// pins back on a phone, since the count outlives a reinstall.
@Suite("Free pin reset · Debug")
struct FreePinResetTests {
    private let keychain = ScratchPinAllowance()

    @Test("The launch argument zeroes the spent count")
    func resetsWhenAsked() {
        let repo = keychain.repo
        repo.saveLifetimePinCount(ProConfig.freePinLimit)

        repo.resetIfRequested(arguments: ["SpaghettiTimer", KeychainPinAllowanceRepo.resetLaunchArgument])

        #expect(repo.loadLifetimePinCount() == 0)
    }

    @Test("Without the argument the count is left alone")
    func leavesCountOtherwise() {
        let repo = keychain.repo
        repo.saveLifetimePinCount(2)

        repo.resetIfRequested(arguments: ["SpaghettiTimer"])

        #expect(repo.loadLifetimePinCount() == 2)
    }
}

/// The Debug-only ••• menu reset, the phone's way back to fresh free pins.
@MainActor
@Suite("Free pin reset · Debug menu")
struct FreePinMenuResetTests {
    private let keychain = ScratchPinAllowance()

    private func makeUseCase(_ scratch: ScratchDefaults) -> TimerPresetsUseCaseImpl {
        TimerPresetsUseCaseImpl(repo: PresetsRepoImpl(defaults: scratch.defaults), pinAllowance: keychain.repo)
    }

    @Test("Resetting after unpinning hands every free pin back")
    func resetAfterUnpinning() {
        let scratch = ScratchDefaults()
        let useCase = makeUseCase(scratch)
        let pinned = (0..<ProConfig.freePinLimit).map {
            useCase.addPreset(name: "Pin \($0)", duration: 60, autoRestartDelaySeconds: nil)
        }
        for preset in pinned { useCase.deletePreset(preset) }

        useCase.resetLifetimePinCount()

        #expect(useCase.lifetimePinCount == 0)
        #expect(FreePinNotice.current(isPro: false, lifetimePinCount: useCase.lifetimePinCount) == .spends(leftAfter: 2))
    }

    @Test("Presets still on Home stay counted after a reset")
    func resetKeepsPinnedPresetsCounted() {
        let scratch = ScratchDefaults()
        let useCase = makeUseCase(scratch)
        for n in 0..<ProConfig.freePinLimit {
            useCase.addPreset(name: "Pin \(n)", duration: 60, autoRestartDelaySeconds: nil)
        }

        useCase.resetLifetimePinCount()

        #expect(useCase.lifetimePinCount == ProConfig.freePinLimit)
    }
}
