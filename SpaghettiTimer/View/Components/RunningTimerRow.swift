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
        HStack(spacing: 8) {
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

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Spacer(minLength: 0)
                if timer.autoRestartDelaySeconds != nil, now >= timer.startDate {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: glyphSize, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .accessibilityHidden(true)
                }
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
            // Take the row's leftover width as one block, so the name/countdown
            // pair is measured against all of it rather than a share of it.
            .layoutPriority(1)
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
