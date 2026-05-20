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

    var body: some View {
        Button(action: onStart) {
            VStack(spacing: 8) {
                Text(preset.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(TimerFormatting.format(preset.duration))
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topLeading) {
            if let onPin {
                Button(action: onPin) {
                    Image(systemName: "pin.fill")
                        .font(.title)
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
                        .font(.title)
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
            if let onUnpin {
                Button(role: .destructive) {
                    withAnimation(.easeInOut(duration: 0.25)) { onUnpin() }
                } label: {
                    Label("Unpin timer", systemImage: "pin.slash")
                }
            }
        }
    }
}

enum TimerFormatting {
    static func format(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded(.up))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }
}
