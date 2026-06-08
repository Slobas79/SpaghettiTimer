//
//  TimerLiveActivity.swift
//  SpaghettiTimerWidget
//
//  Created by Slobodan Stamenic on 23. 4. 2026..
//

import ActivityKit
import AlarmKit
import AppIntents
import SwiftUI
import WidgetKit

/// Visual constants mirrored from the main app's `Theme.swift` so the
/// running-timer Live Activity matches `RunningTimerRow` exactly.
/// `Theme.swift` is not compiled into the widget target, hence the duplication.
private enum LiveActivityStyle {
    static let accent = Color(red: 10 / 255, green: 132 / 255, blue: 255 / 255)   // #0A84FF
    static let bannerFill = Color(red: 2 / 255, green: 21 / 255, blue: 41 / 255)  // #021529
    static let cornerRadius: CGFloat = 22
}

struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<SpaghettiTimerMetadata>.self) { context in
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    pauseResumeButton(alarmID: context.attributes.metadata?.alarmID, state: context.state)
                    cancelButton(alarmID: context.attributes.metadata?.alarmID, state: context.state)
                }

                Spacer(minLength: 12)

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    if context.attributes.metadata?.autoRestartDelaySeconds != nil {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(LiveActivityStyle.accent)
                            .accessibilityLabel("Auto-restart")
                    }
                    Text(context.attributes.metadata?.presetName ?? "Timer")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    countdownText(state: context.state)
                        .font(.system(size: 36, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .background(
                RoundedRectangle(cornerRadius: LiveActivityStyle.cornerRadius, style: .continuous)
                    .fill(LiveActivityStyle.bannerFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LiveActivityStyle.cornerRadius, style: .continuous)
                    .stroke(LiveActivityStyle.accent, lineWidth: 2)
            )
            .shadow(color: LiveActivityStyle.accent.opacity(0.28), radius: 12, y: 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.85))
            .activitySystemActionForegroundColor(.white)
            .environment(\.colorScheme, .dark)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.metadata?.presetName ?? "Timer")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdownText(state: context.state)
                        .font(.system(size: 28, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        pauseResumeButton(alarmID: context.attributes.metadata?.alarmID, state: context.state)
                        cancelButton(alarmID: context.attributes.metadata?.alarmID, state: context.state)
                    }
                    .frame(maxWidth: .infinity)
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                countdownText(state: context.state)
                    .monospacedDigit()
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }

    @ViewBuilder
    private func pauseResumeButton(alarmID: String?, state: AlarmPresentationState) -> some View {
        if let alarmID, let id = UUID(uuidString: alarmID) {
            switch state.mode {
            case .countdown:
                IntentCircleButton(systemName: "pause.fill", intent: PauseTimerIntent(timerID: id.uuidString))
            case .paused:
                IntentCircleButton(systemName: "play.fill", intent: ResumeTimerIntent(timerID: id.uuidString))
            default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func cancelButton(alarmID: String?, state: AlarmPresentationState) -> some View {
        if let alarmID, let id = UUID(uuidString: alarmID) {
            switch state.mode {
            case .countdown, .paused:
                IntentCircleButton(systemName: "xmark", intent: CancelTimerIntent(timerID: id.uuidString))
            default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func countdownText(state: AlarmPresentationState) -> some View {
        switch state.mode {
        case .countdown(let countdown):
            Text(timerInterval: Date()...countdown.fireDate, countsDown: true)
        case .paused(let paused):
            Text(formatRemaining(paused.totalCountdownDuration - paused.previouslyElapsedDuration))
        case .alert:
            Text("Done")
        default:
            Text("--:--")
        }
    }

    private func formatRemaining(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%02d:%02d", minutes, secs)
    }
}

/// Filled accent circle button driven by an AppIntent — mirrors the in-app
/// `CircleButton` used in `RunningTimerRow`.
private struct IntentCircleButton<I: AppIntent>: View {
    let systemName: String
    let intent: I

    var body: some View {
        Button(intent: intent) {
            Circle()
                .fill(LiveActivityStyle.accent)
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
