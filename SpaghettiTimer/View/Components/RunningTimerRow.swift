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
        HStack {
            HStack(spacing: 8) {
                if timer.isPaused {
                    Button(action: onResume) {
                        Image(systemName: "play.circle.fill")
                            .font(.title)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Resume timer")
                } else {
                    Button(action: onPause) {
                        Image(systemName: "pause.circle.fill")
                            .font(.title)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Pause timer")
                }

                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.accentColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss timer")
            }

            Spacer()

            HStack(spacing: 8) {
                if timer.autoRestartDelaySeconds != nil, now >= timer.startDate {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityLabel("Auto-restart")
                }
                Text(timer.name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if now < timer.startDate {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                        Text(TimerFormatting.format(timer.startDate.timeIntervalSince(now)))
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText(countsDown: true))
                    }
                    .foregroundStyle(.secondary)
                } else {
                    Text(TimerFormatting.format(timer.remaining(at: now)))
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.accentColor.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.accentColor, lineWidth: 1.5)
        )
    }
}
