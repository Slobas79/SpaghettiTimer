//
//  TimerTile.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 23. 4. 2026..
//

import SwiftUI

struct TimerTile: View {
    let preset: TimerPreset
    let runningTimers: [RunningTimer]
    let now: Date
    let onStart: () -> Void
    let onStop: () -> Void
    let onUnpin: (() -> Void)?
    let onPin: (() -> Void)?
    let onPause: (() -> Void)?
    let onResume: (() -> Void)?

    var body: some View {
        Button(action: onStart) {
            VStack(spacing: 8) {
                Text(preset.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if let active = runningTimers.first {
                    Text(format(active.remaining(at: now)))
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                    if runningTimers.count > 1 {
                        Text("×\(runningTimers.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(format(preset.duration))
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(runningTimers.isEmpty ? Color(.secondarySystemBackground) : Color.accentColor.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(runningTimers.isEmpty ? Color.clear : Color.accentColor, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if !runningTimers.isEmpty {
                Button(action: onStop) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.accentColor)
                }
                .buttonStyle(.plain)
                .padding(8)
                .accessibilityLabel("Dismiss timer")
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let active = runningTimers.first {
                if active.isPaused, let onResume {
                    Button(action: onResume) {
                        Image(systemName: "play.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .accessibilityLabel("Resume timer")
                } else if !active.isPaused, let onPause {
                    Button(action: onPause) {
                        Image(systemName: "pause.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .accessibilityLabel("Pause timer")
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if let onPin {
                Button(action: onPin) {
                    Image(systemName: "pin.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.accentColor)
                }
                .buttonStyle(.plain)
                .padding(8)
                .accessibilityLabel("Pin timer")
            } else if let onUnpin {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { onUnpin() }
                } label: {
                    Image(systemName: "pin.slash.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.accentColor)
                }
                .buttonStyle(.plain)
                .padding(8)
                .accessibilityLabel("Unpin timer")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .contextMenu {
            if let onPin {
                Button(action: onPin) {
                    Label("Pin timer", systemImage: "pin")
                }
            }
            if let active = runningTimers.first {
                if active.isPaused, let onResume {
                    Button(action: onResume) {
                        Label("Resume", systemImage: "play")
                    }
                } else if !active.isPaused, let onPause {
                    Button(action: onPause) {
                        Label("Pause", systemImage: "pause")
                    }
                }
            }
            if !runningTimers.isEmpty {
                Button(role: .destructive, action: onStop) {
                    Label("Dismiss", systemImage: "xmark.circle")
                }
            }
            if let onUnpin {
                Button(role: .destructive) {
                    withAnimation(.easeInOut(duration: 0.25)) { onUnpin() }
                } label: {
                    Label("Unpin timer", systemImage: "pin.slash")
                }
            }
        }
    }

    private func format(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded(.up))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }
}
