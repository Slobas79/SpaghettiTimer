//
//  RunningTimerRow.swift
//  SpaghettiTimer
//

import SwiftUI

struct RunningTimerRow: View {
    let timer: RunningTimer
    let now: Date
    let onPause: () -> Void
    let onResume: () -> Void
    let onCancel: () -> Void
    /// Home's VoiceOver focus, so the screen can put focus on this row's
    /// countdown when a neighbouring row is dismissed. `nil` where the row is
    /// only artwork (the tutorial card).
    var focus: AccessibilityFocusState<HomeFocus?>.Binding? = nil

    /// The row is a fixed-height band, so the watermark is sized off that
    /// height rather than off a font size that would overflow and clip.
    private static let rowHeight: CGFloat = 76
    private static let watermarkInset: CGFloat = 14

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var nameSize: CGFloat = 19
    @ScaledMetric(relativeTo: .largeTitle) private var countdownSize: CGFloat = 36
    @ScaledMetric(relativeTo: .title3) private var delayGlyphSize: CGFloat = 18

    private var numericTransition: ContentTransition {
        reduceMotion ? .identity : .numericText(countsDown: true)
    }

    /// Spoken status + remaining time for the combined name/countdown element.
    private var statusValue: String {
        if now < timer.startDate {
            let starts = TimerFormatting.spoken(timer.startDate.timeIntervalSince(now))
            return String(localized: "Starts in \(starts)")
        }
        let remaining = TimerFormatting.spoken(timer.remaining(at: now))
        if timer.isPaused {
            return String(localized: "Paused, \(remaining) remaining")
        }
        return String(localized: "\(remaining) remaining")
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 12) {
                // One button whose content flips, not two in an if/else: a
                // branch swap replaces the view, and VoiceOver loses the button
                // it just activated.
                CircleButton(systemName: timer.isPaused ? "play.fill" : "pause.fill",
                             action: timer.isPaused ? onResume : onPause)
                    .accessibilityLabel(timer.isPaused ? Text("Resume timer") : Text("Pause timer"))
                    .accessibilityHint(timer.isPaused ? Text("Resumes the countdown") : Text("Pauses the countdown"))

                CircleButton(systemName: "xmark", action: onCancel)
                    .accessibilityLabel("Dismiss timer")
                    .accessibilityHint("Stops and removes the timer")
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Spacer(minLength: 0)
                // The countdown must always be fully visible, so the name is the
                // element that gives way: it truncates instead of squeezing the digits.
                Text(timer.name)
                    .font(.system(size: nameSize, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(0)

                if now < timer.startDate {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: delayGlyphSize, weight: .semibold))
                        Text(TimerFormatting.format(timer.startDate.timeIntervalSince(now)))
                            .font(.system(size: countdownSize, weight: .bold))
                            .monospacedDigit()
                            .contentTransition(numericTransition)
                    }
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
                } else {
                    Text(TimerFormatting.format(timer.remaining(at: now)))
                        .font(.system(size: countdownSize, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(numericTransition)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .layoutPriority(1)
                }
            }
            // Read the name + live countdown as a single, frequently-updating
            // element instead of fragmenting it across glyph/name/digits.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(timer.name)
            .accessibilityValue(statusValue)
            .accessibilityAddTraits(.updatesFrequently)
            .modifier(HomeFocusTarget(focus: focus, value: .running(timer.id)))
            // Take the row's leftover width as one block, so the name/countdown
            // pair is measured against all of it rather than a share of it.
            .layoutPriority(1)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: Self.rowHeight)
        .background(rowBackground)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .stroke(Theme.accent, lineWidth: 2)
        )
        .shadow(color: Theme.accent.opacity(0.28), radius: 12, y: 6)
    }

    /// Same auto-repeat watermark the tile uses, so a repeating timer reads the
    /// same whether it is idle on a tile or running in a row. Sits in the
    /// background so the buttons, name and countdown all draw over it.
    private var rowBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .fill(Theme.bannerFill)
            if timer.autoRestartDelaySeconds != nil {
                Image(systemName: "arrow.clockwise")
                    .resizable()
                    .scaledToFit()
                    .fontWeight(.semibold)
                    .padding(.vertical, Self.watermarkInset)
                    .foregroundStyle(Theme.accent.opacity(0.2))
                    .accessibilityHidden(true)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}

private struct CircleButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Theme.accent)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: systemName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                )
        }
        .buttonStyle(.plain)
    }
}
