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
/// `.splash` is not a tour — it's the first-launch 3·2·1 intro, gated by its
/// own flag so skipping/finishing it never consumes the Home tour.
nonisolated enum TutorialScreen: String, Sendable {
    case home = "tutorial.home.done"
    case newTimer = "tutorial.newTimer.done"
    case splash = "tutorial.splash.done"
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
    case durationWheel
    case modePicker
    case nameField
    case autoRestartRow
}

/// A feature that isn't on screen during the tour, rendered as artwork inside
/// a centered hint card instead of being spotlighted (no cutout/connector).
nonisolated enum TutorialArt: Sendable {
    case runningBanner
    case widget
}

/// The New Timer sheet state a step needs before its target can be
/// spotlighted (mirrors the mock's `step.tab`). The tour host maps this onto
/// the sheet's Duration/End-time mode binding.
nonisolated enum TutorialSheetTab: Sendable {
    case duration
    case endTime
}

/// Per-step override of the automatic below-if-room hint-card placement.
nonisolated enum TutorialCardPlacement: Sendable {
    case above
    case below
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
    /// A spotlight step points at an on-screen `target`; an artwork step has no
    /// target and renders `art` in a centered card instead. Exactly one is set.
    var target: TutorialTargetID? = nil
    var art: TutorialArt? = nil
    let title: LocalizedStringResource
    let body: LocalizedStringResource
    /// Breathing room between the target's bounds and the cutout edge.
    var padding: CGFloat = 6
    /// Cutout corner radius ≈ the target's own radius.
    var cornerRadius: CGFloat = 20
    /// Sheet state to force before spotlighting (e.g. the End time tab). A
    /// step with a tab keeps its place in the tour even while its target is
    /// off screen — the host guarantees the target by applying the tab.
    var tab: TutorialSheetTab? = nil
    /// Forces the hint card above/below the spotlight, overriding the
    /// automatic below-if-room rule.
    var place: TutorialCardPlacement? = nil
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
            padding: 8,
            cornerRadius: 30
        ),
        TutorialStep(
            art: .runningBanner,
            title: "Always in reach",
            body: "A running timer lives at the top of this screen. Pause or dismiss it without leaving the grid."
        ),
        TutorialStep(
            art: .widget,
            title: "Add the widget",
            body: "Your pinned timers on the home screen — tap a tile to start it without opening the app. Long-press your home screen and add Spaghetti Timer."
        )
    ]

    static let newTimer: [TutorialStep] = [
        TutorialStep(
            target: .durationWheel,
            title: "Dial the duration",
            body: "Scroll hours, minutes and seconds. Start lights up as soon as it’s not zero.",
            cornerRadius: 22,
            tab: .duration
        ),
        // Spotlights the SELECTED End time segment; the card sits above so the
        // readout + clock wheel below stay fully visible.
        TutorialStep(
            target: .modePicker,
            title: "Or pick an end time",
            body: "Switch to End time and choose when the timer should finish — like 11:00 AM. The duration is set for you.",
            padding: 4,
            cornerRadius: 13,
            tab: .endTime,
            place: .above
        ),
        TutorialStep(
            target: .nameField,
            title: "Name it (optional)",
            body: "A name like “Pasta” shows on the timer card, the widget and the Dynamic Island.",
            cornerRadius: 16,
            tab: .duration
        ),
        TutorialStep(
            target: .autoRestartRow,
            title: "Auto-restart",
            body: "Great for intervals — the timer restarts itself after a cooldown you choose.",
            padding: 2,
            cornerRadius: 18,
            tab: .duration
        )
    ]
}
