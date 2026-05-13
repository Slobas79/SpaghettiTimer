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

struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<SpaghettiTimerMetadata>.self) { context in
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.metadata?.presetName ?? "Timer")
                        .font(.headline)
                    countdownText(state: context.state)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                Spacer()
                pauseResumeButton(alarmID: context.attributes.metadata?.alarmID, state: context.state)
                cancelButton(alarmID: context.attributes.metadata?.alarmID, state: context.state)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.85))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.metadata?.presetName ?? "Timer")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdownText(state: context.state)
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
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
                Button(intent: PauseTimerIntent(timerID: id.uuidString)) {
                    Image(systemName: "pause.fill")
                }
                .tint(.accentColor)
            case .paused:
                Button(intent: ResumeTimerIntent(timerID: id.uuidString)) {
                    Image(systemName: "play.fill")
                }
                .tint(.accentColor)
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
                Button(intent: CancelTimerIntent(timerID: id.uuidString)) {
                    Image(systemName: "xmark.circle.fill")
                }
                .tint(.red)
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
