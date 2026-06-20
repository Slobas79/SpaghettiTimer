//
//  TimerTile.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 23. 4. 2026..
//

import SwiftUI

struct TimerTile: View {
    let preset: TimerPreset
    let onStart: () -> Void
    let onUnpin: (() -> Void)?
    let onPin: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title3) private var nameSize: CGFloat = 21
    @ScaledMetric(relativeTo: .largeTitle) private var durationSize: CGFloat = 40
    @ScaledMetric(relativeTo: .body) private var pinSize: CGFloat = 18

    /// Spoken duration, with a "Repeats" note when the preset auto-restarts.
    private var accessibilityValue: String {
        let duration = TimerFormatting.spoken(preset.duration)
        guard preset.autoRestartDelaySeconds != nil else { return duration }
        return duration + ", " + String(localized: "Repeats")
    }

    private var pinTransition: AnyTransition {
        reduceMotion ? .identity : .scale.combined(with: .opacity)
    }

    var body: some View {
        if let onPin {
            tile.accessibilityAction(named: Text("Pin timer"), onPin)
        } else if let onUnpin {
            tile.accessibilityAction(named: Text("Unpin timer")) {
                unpin(onUnpin)
            }
        } else {
            tile
        }
    }

    private var tile: some View {
        Button(action: onStart) {
            face
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) { pinOverlay }
        // Collapse the tile (and its decorative pin overlay) into one VoiceOver
        // element: name as label, spoken duration as value, with pin/unpin
        // reachable as a rotor action rather than a tiny separate target.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(preset.name)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Starts the timer")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, onStart)
        .contextMenu { contextMenuItems }
    }

    private var face: some View {
        VStack(spacing: 4) {
            Text(preset.name)
                .font(.system(size: nameSize, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(TimerFormatting.format(preset.duration))
                .font(.system(size: durationSize, weight: .regular))
                .monospacedDigit()
                .foregroundStyle(Theme.mutedTime)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(Theme.cardAspectRatio, contentMode: .fit)
        .background(faceBackground)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .stroke(Theme.cardBorder, lineWidth: 1.5)
        )
    }

    private var faceBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .fill(Theme.cardFill)
            if preset.autoRestartDelaySeconds != nil {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 80, weight: .semibold))
                    .foregroundStyle(Theme.accent.opacity(0.14))
                    .accessibilityHidden(true)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var pinOverlay: some View {
        if let onPin {
            pinButton(systemName: "pin", action: onPin)
        } else if let onUnpin {
            pinButton(systemName: "pin.fill") { unpin(onUnpin) }
                .transition(pinTransition)
        }
    }

    private func pinButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: pinSize, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .padding(14)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        if let onPin {
            Button(action: onPin) {
                Label("Pin timer", systemImage: "pin")
            }
        }
        if let onUnpin {
            Button(role: .destructive) {
                unpin(onUnpin)
            } label: {
                Label("Unpin timer", systemImage: "pin.slash")
            }
        }
    }

    private func unpin(_ action: @escaping () -> Void) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { action() }
    }
}

enum TimerFormatting {
    static func format(_ interval: TimeInterval) -> String {
        guard interval.isFinite, interval > 0 else { return "00:00" }
        // Cap well below Int range (~273 years) so the Int() conversion can never trap
        // on a corrupt/huge persisted duration.
        let total = Int(min(interval.rounded(.up), 8.64e9))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    /// Human-readable, localized duration for VoiceOver — e.g. "5 minutes",
    /// "1 hour, 30 seconds" — so screen readers don't spell out "05:00".
    static func spoken(_ interval: TimeInterval) -> String {
        let total = Int(min(max(0, interval.rounded()), 8.64e9))
        return Duration.seconds(total)
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))
    }
}
