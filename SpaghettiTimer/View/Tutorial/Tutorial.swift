//
//  Tutorial.swift
//  SpaghettiTimer
//
//  First-run coach-mark tours: per-screen scripts, spotlight target anchors
//  and the once-per-screen persistence flags. Mirrors the "first-run
//  tutorial" design handoff (scrim + spotlight + hint card).
//

import SwiftUI

// MARK: - Screens & persistence

/// Screens that own a coach-mark tour. The raw value is the UserDefaults key.
nonisolated enum TutorialScreen: String, Sendable {
    case home = "tutorial.home.done"
    case newTimer = "tutorial.newTimer.done"
}

/// Once-per-screen gate — set on Done **or** Skip.
nonisolated enum TutorialFlags {
    static func isDone(_ screen: TutorialScreen) -> Bool {
        AppGroup.defaults.bool(forKey: screen.rawValue)
    }

    static func markDone(_ screen: TutorialScreen) {
        AppGroup.defaults.set(true, forKey: screen.rawValue)
    }
}

// MARK: - Spotlight targets

/// Views a tutorial step can spotlight. Marked with `.tutorialTarget(_:)`.
nonisolated enum TutorialTargetID: Hashable, Sendable {
    case presetTile
    case pinBadge
    case addTile
    case runningBanner
    case durationWheel
    case modePicker
    case nameField
    case autoRestartRow
}

/// Collects target bounds anchors from marked views. When several views mark
/// the same target (every grid tile emits `.presetTile`), the first one in
/// layout order wins — the tour spotlights the top-leading instance.
nonisolated struct TutorialTargetPreferenceKey: PreferenceKey {
    static var defaultValue: [TutorialTargetID: Anchor<CGRect>] { [:] }

    static func reduce(value: inout [TutorialTargetID: Anchor<CGRect>],
                       nextValue: () -> [TutorialTargetID: Anchor<CGRect>]) {
        value.merge(nextValue()) { first, _ in first }
    }
}

extension View {
    /// Marks this view as the spotlight target for a tutorial step.
    /// Folds into the subtree's collected anchors (`transformAnchorPreference`)
    /// rather than replacing them, so an outer target — the tile — can't
    /// swallow one emitted deeper inside — the tile's pin badge.
    func tutorialTarget(_ id: TutorialTargetID) -> some View {
        transformAnchorPreference(key: TutorialTargetPreferenceKey.self, value: .bounds) { value, anchor in
            value.merge([id: anchor]) { first, _ in first }
        }
    }
}

// MARK: - Steps & scripts

nonisolated struct TutorialStep: Sendable {
    let target: TutorialTargetID
    let title: LocalizedStringResource
    let body: LocalizedStringResource
    /// Breathing room between the target's bounds and the cutout edge.
    var padding: CGFloat = 6
    /// Cutout corner radius ≈ the target's own radius.
    var cornerRadius: CGFloat = 20
}

/// The per-screen tour scripts. New tips for future features: append a step.
enum TutorialTour {
    static let home: [TutorialStep] = [
        TutorialStep(
            target: .presetTile,
            title: "Tap to start",
            body: "Timers start instantly with one tap — no setup each time.",
            cornerRadius: 22
        ),
        TutorialStep(
            target: .pinBadge,
            title: "Pin your favorites",
            body: "Pinned timers stay on this screen and appear in the widget.",
            padding: 8,
            cornerRadius: 12
        ),
        TutorialStep(
            target: .addTile,
            title: "New timer",
            body: "Create your own — set a duration, or pick the clock time it should end at.",
            cornerRadius: 22
        ),
        TutorialStep(
            target: .runningBanner,
            title: "Always in reach",
            body: "A running timer lives up here. Pause or dismiss it without leaving the grid.",
            padding: 8,
            cornerRadius: 22
        )
    ]

    static let newTimer: [TutorialStep] = [
        TutorialStep(
            target: .durationWheel,
            title: "Dial the duration",
            body: "Scroll hours, minutes and seconds. Start lights up as soon as it’s not zero.",
            cornerRadius: 22
        ),
        TutorialStep(
            target: .modePicker,
            title: "Or pick an end time",
            body: "Switch to End time and choose when the timer should finish — like 11:00 AM. The duration is set for you.",
            padding: 4,
            cornerRadius: 13
        ),
        TutorialStep(
            target: .nameField,
            title: "Name it (optional)",
            body: "A name like “Pasta” shows on the timer card, the widget and the Dynamic Island.",
            cornerRadius: 16
        ),
        TutorialStep(
            target: .autoRestartRow,
            title: "Auto-restart",
            body: "Great for intervals — the timer restarts itself after a cooldown you choose.",
            padding: 2,
            cornerRadius: 18
        )
    ]
}
