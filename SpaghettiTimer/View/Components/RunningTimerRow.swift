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

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                if timer.isPaused {
                    CircleButton(systemName: "play.fill", action: onResume)
                        .accessibilityLabel("Resume timer")
                } else {
                    CircleButton(systemName: "pause.fill", action: onPause)
                        .accessibilityLabel("Pause timer")
                }

                CircleButton(systemName: "xmark", action: onCancel)
                    .accessibilityLabel("Dismiss timer")
            }

            Spacer(minLength: 12)

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                if timer.autoRestartDelaySeconds != nil, now >= timer.startDate {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .accessibilityLabel("Auto-restart")
                }
                Text(timer.name)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if now < timer.startDate {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 18, weight: .semibold))
                        Text(TimerFormatting.format(timer.startDate.timeIntervalSince(now)))
                            .font(.system(size: 36, weight: .bold))
                            .monospacedDigit()
                            .contentTransition(.numericText(countsDown: true))
                    }
                    .foregroundStyle(.white)
                } else {
                    Text(TimerFormatting.format(timer.remaining(at: now)))
                        .font(.system(size: 36, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: true))
                }
            }
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
