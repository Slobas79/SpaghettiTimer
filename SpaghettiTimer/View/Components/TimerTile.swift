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
            VStack(spacing: 4) {
                Text(preset.name)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(TimerFormatting.format(preset.duration))
                    .font(.system(size: 40, weight: .regular))
                    .monospacedDigit()
                    .foregroundStyle(Theme.mutedTime)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(Theme.cardAspectRatio, contentMode: .fit)
            .background(
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
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .stroke(Theme.cardBorder, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if let onPin {
                Button(action: onPin) {
                    Image(systemName: "pin")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .padding(14)
                .accessibilityLabel("Pin timer")
            } else if let onUnpin {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { onUnpin() }
                } label: {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .padding(14)
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
}
