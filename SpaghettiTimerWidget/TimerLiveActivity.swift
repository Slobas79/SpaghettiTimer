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
                    Text(context.attributes.metadata?.presetName ?? String(localized: "Timer"))
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
            let metadata = context.attributes.metadata
            let isRepeating = metadata?.autoRestartDelaySeconds != nil
            let paused = isPaused(state: context.state)

            return DynamicIsland {
                // Header: app mark + "Spaghetti Timer" (leading) · label + loop glyph (trailing).
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Image("AppMark")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 28 * 0.2237, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 28 * 0.2237, style: .continuous)
                                    .stroke(.white.opacity(0.08), lineWidth: 1)
                            )
                        Text("Spaghetti Timer")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 6) {
                        if isRepeating {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(LiveActivityStyle.accent)
                        }
                        Text(metadata?.presetName ?? String(localized: "Timer"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                // Body: ring · big countdown · pause/resume · dismiss.
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 14) {
                        progressRing(state: context.state, isRepeating: isRepeating,
                                     diameter: 66, stroke: 6, glyphPointSize: 24)
                        countdownText(state: context.state)
                            .font(.system(size: 44, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .opacity(paused ? 0.55 : 1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Spacer(minLength: 8)
                        pauseResumeButton(alarmID: metadata?.alarmID, state: context.state, size: 52)
                        cancelButton(alarmID: metadata?.alarmID, state: context.state, size: 52)
                    }
                    .padding(.top, 8)
                }
            } compactLeading: {
                progressRing(state: context.state, isRepeating: isRepeating,
                             diameter: 22, stroke: 3.2, glyphPointSize: 11)
                    .padding(.leading, 2)
            } compactTrailing: {
                countdownText(state: context.state)
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(paused ? .white.opacity(0.6) : .white)
                    .frame(maxWidth: 60)
            } minimal: {
                progressRing(state: context.state, isRepeating: isRepeating,
                             diameter: 22, stroke: 3, glyphPointSize: 10, glyphOnlyWhenRepeating: true)
            }
            .keylineTint(LiveActivityStyle.accent)
        }
    }

    @ViewBuilder
    private func pauseResumeButton(alarmID: String?, state: AlarmPresentationState, size: CGFloat = 40) -> some View {
        if let alarmID, let id = UUID(uuidString: alarmID) {
            switch state.mode {
            case .countdown:
                IntentCircleButton(systemName: "pause.fill", intent: PauseTimerIntent(timerID: id.uuidString), size: size)
            case .paused:
                IntentCircleButton(systemName: "play.fill", intent: ResumeTimerIntent(timerID: id.uuidString), size: size)
            default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func cancelButton(alarmID: String?, state: AlarmPresentationState, size: CGFloat = 40) -> some View {
        if let alarmID, let id = UUID(uuidString: alarmID) {
            switch state.mode {
            case .countdown, .paused:
                IntentCircleButton(systemName: "xmark", intent: CancelTimerIntent(timerID: id.uuidString),
                                   style: .secondary, size: size)
            default:
                EmptyView()
            }
        }
    }

    /// Accent progress ring with a glyph at its center, mirroring the design's `Ring`.
    /// Uses `ProgressView(timerInterval:)` so the ring depletes live (system-updated) while
    /// running, and a static fraction while paused. The glyph is the stopwatch normally, or
    /// the loop glyph when the timer auto-repeats.
    @ViewBuilder
    private func progressRing(
        state: AlarmPresentationState,
        isRepeating: Bool,
        diameter: CGFloat,
        stroke: CGFloat,
        glyphPointSize: CGFloat,
        glyphOnlyWhenRepeating: Bool = false
    ) -> some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.16), lineWidth: stroke)

            switch state.mode {
            case .countdown(let countdown):
                // System-updated depleting ring — counts the elapsed fraction down to 0.
                ProgressView(timerInterval: countdown.startDate...countdown.fireDate, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.circular)
                .tint(LiveActivityStyle.accent)
            case .paused(let paused):
                let fraction = paused.totalCountdownDuration > 0
                    ? max(0, min(1, (paused.totalCountdownDuration - paused.previouslyElapsedDuration) / paused.totalCountdownDuration))
                    : 0
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(LiveActivityStyle.accent.opacity(0.7),
                            style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            default:
                EmptyView()
            }

            if !(glyphOnlyWhenRepeating && !isRepeating) {
                Image(systemName: isRepeating ? "arrow.clockwise" : "stopwatch")
                    .font(.system(size: glyphPointSize, weight: .semibold))
                    .foregroundStyle(LiveActivityStyle.accent)
            }
        }
        .frame(width: diameter, height: diameter)
    }

    private func isPaused(state: AlarmPresentationState) -> Bool {
        if case .paused = state.mode { return true }
        return false
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
            : String(format: "%d:%02d", minutes, secs)
    }
}

/// Filled accent circle button driven by an AppIntent — mirrors the in-app
/// `CircleButton` used in `RunningTimerRow`.
private struct IntentCircleButton<I: AppIntent>: View {
    enum Style { case accent, secondary }

    let systemName: String
    let intent: I
    var style: Style = .accent
    var size: CGFloat = 40

    var body: some View {
        Button(intent: intent) {
            Circle()
                .fill(style == .accent ? AnyShapeStyle(LiveActivityStyle.accent) : AnyShapeStyle(.white.opacity(0.14)))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: systemName)
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundStyle(.white)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#if DEBUG
/// Sample data so the Live Activity / Dynamic Island can be inspected in Xcode
/// previews without AlarmKit scheduling a real alarm (which doesn't work on the
/// Simulator). Build the attributes + content states the same shapes the system
/// hands `TimerLiveActivity` at runtime.
private enum LiveActivityPreviewData {
    /// Attributes mirror `AlarmConfigurationFactory.makeConfiguration` so the
    /// preview metadata (name, auto-restart glyph) matches production.
    static func attributes(name: String, autoRestart: Bool = false) -> AlarmAttributes<SpaghettiTimerMetadata> {
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: name),
            stopButton: .init(text: "Stop", textColor: .white, systemImageName: "stop.fill")
        )
        let countdown = AlarmPresentation.Countdown(
            title: LocalizedStringResource(stringLiteral: name),
            pauseButton: .init(text: "Pause", textColor: .white, systemImageName: "pause.fill")
        )
        let paused = AlarmPresentation.Paused(
            title: LocalizedStringResource(stringLiteral: name),
            resumeButton: .init(text: "Resume", textColor: .white, systemImageName: "play.fill")
        )
        return AlarmAttributes<SpaghettiTimerMetadata>(
            presentation: .init(alert: alert, countdown: countdown, paused: paused),
            metadata: SpaghettiTimerMetadata(
                presetName: name,
                alarmID: UUID().uuidString,
                presetID: UUID().uuidString,
                autoRestartDelaySeconds: autoRestart ? 5 : nil
            ),
            tintColor: .accentColor
        )
    }

    /// Live countdown — `remaining` seconds left of a `total`-second timer.
    static func countdown(remaining: TimeInterval, total: TimeInterval = 300) -> AlarmPresentationState {
        let now = Date()
        return AlarmPresentationState(
            alarmID: UUID(),
            mode: .countdown(.init(
                totalCountdownDuration: total,
                previouslyElapsedDuration: total - remaining,
                startDate: now,
                fireDate: now.addingTimeInterval(remaining)
            ))
        )
    }

    /// Paused with `remaining` seconds frozen on the clock.
    static func paused(remaining: TimeInterval, total: TimeInterval = 300) -> AlarmPresentationState {
        AlarmPresentationState(
            alarmID: UUID(),
            mode: .paused(.init(
                totalCountdownDuration: total,
                previouslyElapsedDuration: total - remaining
            ))
        )
    }

    /// Fired — shows the "Done" state.
    static var alert: AlarmPresentationState {
        AlarmPresentationState(alarmID: UUID(), mode: .alert(.init(time: .init(hour: 0, minute: 0))))
    }
}

#Preview("Lock Screen", as: .content, using: LiveActivityPreviewData.attributes(name: "Pasta")) {
    TimerLiveActivity()
} contentStates: {
    LiveActivityPreviewData.countdown(remaining: 125)
    LiveActivityPreviewData.paused(remaining: 125)
    LiveActivityPreviewData.alert
}

#Preview("DI Expanded", as: .dynamicIsland(.expanded), using: LiveActivityPreviewData.attributes(name: "Pasta")) {
    TimerLiveActivity()
} contentStates: {
    LiveActivityPreviewData.countdown(remaining: 125)
    LiveActivityPreviewData.paused(remaining: 125)
    LiveActivityPreviewData.alert
}

#Preview("DI Compact", as: .dynamicIsland(.compact), using: LiveActivityPreviewData.attributes(name: "Pasta")) {
    TimerLiveActivity()
} contentStates: {
    LiveActivityPreviewData.countdown(remaining: 125)
    LiveActivityPreviewData.paused(remaining: 125)
    LiveActivityPreviewData.alert
}

#Preview("DI Minimal", as: .dynamicIsland(.minimal), using: LiveActivityPreviewData.attributes(name: "Pasta")) {
    TimerLiveActivity()
} contentStates: {
    LiveActivityPreviewData.countdown(remaining: 125)
}

#Preview("DI Expanded · Paused", as: .dynamicIsland(.expanded), using: LiveActivityPreviewData.attributes(name: "Pasta")) {
    TimerLiveActivity()
} contentStates: {
    LiveActivityPreviewData.paused(remaining: 125)
}

#Preview("DI Expanded · Repeat", as: .dynamicIsland(.expanded), using: LiveActivityPreviewData.attributes(name: "1 min", autoRestart: true)) {
    TimerLiveActivity()
} contentStates: {
    LiveActivityPreviewData.countdown(remaining: 51, total: 60)
}

#Preview("DI Minimal · Repeat", as: .dynamicIsland(.minimal), using: LiveActivityPreviewData.attributes(name: "1 min", autoRestart: true)) {
    TimerLiveActivity()
} contentStates: {
    LiveActivityPreviewData.countdown(remaining: 51, total: 60)
}
#endif
