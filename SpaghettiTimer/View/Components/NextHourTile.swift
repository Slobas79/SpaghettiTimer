//
//  NextHourTile.swift
//  SpaghettiTimer
//
//  The dynamic "To next hour" tile (`.card-nexthour` in the design handoff).
//  Appears as the first grid cell while an End-time timer is pinned. Unlike a
//  normal pinned timer — which stores a fixed duration — it always offers a
//  countdown to the next full hour, recomputed from `now` on every render.
//

import SwiftUI

struct NextHourTile: View {
    /// Driven by the home screen's `TimelineView`, so the readout follows the
    /// real clock (the minute value only changes once a minute).
    let now: Date
    let onStart: () -> Void
    let onUnpin: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title3) private var labelSize: CGFloat = 21
    @ScaledMetric(relativeTo: .title) private var valueSize: CGFloat = 30
    @ScaledMetric(relativeTo: .caption) private var badgeSize: CGFloat = 12
    @ScaledMetric(relativeTo: .caption) private var badgeGlyphSize: CGFloat = 15
    @ScaledMetric(relativeTo: .body) private var pinSize: CGFloat = 18

    private var minutes: Int { NextHour.minutesRemaining(at: now) }

    /// e.g. "Until 7 PM, 21 minutes" — the two on-screen strings, spoken.
    private var accessibilityValue: String {
        NextHour.label(at: now) + ", " + TimerFormatting.spoken(TimeInterval(minutes * 60))
    }

    var body: some View {
        Button(action: onStart) {
            face
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) { pinButton }
        // One VoiceOver element, matching `TimerTile`: unpinning is a rotor
        // action rather than a separate 30pt target.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("To next hour")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Starts the timer")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, onStart)
        .accessibilityAction(named: Text("Unpin timer"), unpin)
        .contextMenu {
            Button(role: .destructive, action: unpin) {
                Label("Unpin timer", systemImage: "pin.slash")
            }
        }
    }

    private var face: some View {
        VStack(spacing: 4) {
            Text(NextHour.label(at: now))
                .font(.system(size: labelSize, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text("\(minutes) min")
                .font(.system(size: valueSize, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.mutedTime)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(Theme.cardAspectRatio, contentMode: .fit)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .fill(Theme.cardFill)
        )
        // The badge owns the top-left corner; the pin sits opposite it. The
        // trailing inset reserves the pin's 30pt corner, so a translation
        // longer than the English "To next hour" shrinks to fit instead of
        // sliding underneath it.
        .overlay(alignment: .topLeading) {
            badge
                .padding(14)
                .padding(.trailing, 40)
        }
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .stroke(Theme.nextHourBorder, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    private var badge: some View {
        HStack(spacing: 5) {
            Image(systemName: "clock")
                .font(.system(size: badgeGlyphSize, weight: .medium))
            Text("To next hour")
                .font(.system(size: badgeSize, weight: .bold))
                .tracking(0.2)
                .lineLimit(1)
                // Languages that render this far longer than English shrink
                // to fit the pill rather than getting an ellipsis. German
                // ("Nächste Stunde") needs ~0.7, so leave headroom below it.
                .minimumScaleFactor(0.55)
        }
        .foregroundStyle(Theme.accent)
        .padding(.vertical, 4)
        .padding(.leading, 5)
        .padding(.trailing, 9)
        .background(Capsule().fill(Theme.nextHourBadgeFill))
        .accessibilityHidden(true)
    }

    /// Always top-right on this tile, whatever the pin side elsewhere — the
    /// badge occupies the top-left corner.
    private var pinButton: some View {
        Button(action: unpin) {
            Image(systemName: "pin.fill")
                .font(.system(size: pinSize, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .padding(14)
        .accessibilityHidden(true)
    }

    private func unpin() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { onUnpin() }
    }
}

#Preview {
    ZStack {
        Theme.screenBG.ignoresSafeArea()
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: Theme.gridGap),
                GridItem(.flexible(), spacing: Theme.gridGap)
            ],
            spacing: Theme.gridGap
        ) {
            NextHourTile(now: .now, onStart: {}, onUnpin: {})
            TimerTile(preset: TimerPreset.builtIns[0], onStart: {}, onUnpin: {}, onPin: nil)
        }
        .padding(.horizontal, Theme.screenPadding)
    }
}
