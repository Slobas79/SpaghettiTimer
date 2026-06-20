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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var nameSize: CGFloat = 19
    @ScaledMetric(relativeTo: .largeTitle) private var countdownSize: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var glyphSize: CGFloat = 15
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
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                if timer.isPaused {
                    CircleButton(systemName: "play.fill", action: onResume)
                        .accessibilityLabel("Resume timer")
                        .accessibilityHint("Resumes the countdown")
                } else {
                    CircleButton(systemName: "pause.fill", action: onPause)
                        .accessibilityLabel("Pause timer")
                        .accessibilityHint("Pauses the countdown")
                }

                CircleButton(systemName: "xmark", action: onCancel)
                    .accessibilityLabel("Dismiss timer")
                    .accessibilityHint("Stops and removes the timer")
            }

            Spacer(minLength: 12)

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                if timer.autoRestartDelaySeconds != nil, now >= timer.startDate {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: glyphSize, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .accessibilityHidden(true)
                }
                Text(timer.name)
                    .font(.system(size: nameSize, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

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
                } else {
                    Text(TimerFormatting.format(timer.remaining(at: now)))
                        .font(.system(size: countdownSize, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(numericTransition)
                }
            }
            // Read the name + live countdown as a single, frequently-updating
            // element instead of fragmenting it across glyph/name/digits.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(timer.name)
            .accessibilityValue(statusValue)
            .accessibilityAddTraits(.updatesFrequently)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 76)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .fill(Theme.bannerFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .stroke(Theme.accent, lineWidth: 2)
        )
        .shadow(color: Theme.accent.opacity(0.28), radius: 12, y: 6)
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
