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
    static let segUnlit = Color(red: 0.00884, green: 0.09946, blue: 0.19392)      // mix(accent 14%, #010810)
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
                    BannerTitle(text: headerTitle(context.attributes.metadata))
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
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
                // Header: timer title — or the app name when the timer is
                // unnamed — followed by the loop glyph, both left-aligned.
                DynamicIslandExpandedRegion(.center) {
                    // No `fixedSize` here: the leading region is narrower
                    // than the title's ideal width on some devices, and
                    // pinning the width pushed the whole header out of
                    // bounds instead of letting the title shrink.
                    HStack {
                        HeaderTitle(text: headerTitle(metadata))
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        
                        if isRepeating {
                            // The name that used to sit beside this glyph now leads
                            // the header, so the glyph carries its own label.
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(LiveActivityStyle.accent)
                                .accessibilityLabel("Auto-restart")
                                .padding(.leading, 24)
                        }

                        // Without this the HStack sizes to its content and the
                        // region centers it; the spacer pins the title left.
                        Spacer(minLength: 0)
                    }
                }
                
                // Body: ring · big countdown · pause/resume · dismiss.
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 14) {
                        progressRing(state: context.state,
                                     diameter: 66, stroke: 6, glyphPointSize: 24)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            if paused {
                                // Non-color cue: paused was previously shown only by
                                // dimming. The glyph reads for everyone and VoiceOver.
                                Image(systemName: "pause.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.55))
                                    .accessibilityLabel("Paused")
                            }
                            countdownText(state: context.state)
                                .font(.system(size: 44, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .opacity(paused ? 0.55 : 1)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        Spacer(minLength: 8)
                        pauseResumeButton(alarmID: metadata?.alarmID, state: context.state, size: 52)
                        cancelButton(alarmID: metadata?.alarmID, state: context.state, size: 52)
                    }
                    .padding(.top, 8)
                }
            } compactLeading: {
                progressRing(state: context.state,
                             diameter: 22, stroke: 3.2, glyphPointSize: 11)
                    .padding(.leading, 2)
            } compactTrailing: {
                countdownText(state: context.state)
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(paused ? .white.opacity(0.6) : .white)
                    .frame(maxWidth: 60)
            } minimal: {
                progressRing(state: context.state,
                             diameter: 22, stroke: 3, glyphPointSize: 10)
            }
            .keylineTint(LiveActivityStyle.accent)
        }
    }

    /// The timer's own title, falling back to the app name when it has none.
    /// An unnamed one-shot timer stores `""` rather than `nil`, so the
    /// metadata's optionality alone isn't enough of a check.
    private func headerTitle(_ metadata: SpaghettiTimerMetadata?) -> String {
        let name = metadata?.presetName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Spaghetti Timer" : name
    }

    @ViewBuilder
    private func pauseResumeButton(alarmID: String?, state: AlarmPresentationState, size: CGFloat = 40) -> some View {
        if let alarmID, let id = UUID(uuidString: alarmID) {
            switch state.mode {
            case .countdown:
                IntentCircleButton(systemName: "pause.fill", intent: PauseTimerIntent(timerID: id.uuidString), size: size)
                    .accessibilityLabel("Pause timer")
            case .paused:
                IntentCircleButton(systemName: "play.fill", intent: ResumeTimerIntent(timerID: id.uuidString), size: size)
                    .accessibilityLabel("Resume timer")
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
                    .accessibilityLabel("Cancel timer")
            default:
                EmptyView()
            }
        }
    }

    /// Accent progress ring with the app mark at its center, mirroring the design's `Ring`.
    /// Uses `ProgressView(timerInterval:)` so the ring depletes live (system-updated) while
    /// running, and a static fraction while paused. The center always carries the app mark —
    /// auto-restart is signalled outside the ring, in the header and the banner.
    @ViewBuilder
    private func progressRing(
        state: AlarmPresentationState,
        diameter: CGFloat,
        stroke: CGFloat,
        glyphPointSize: CGFloat
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

            // The app mark, not a generic stopwatch — 1.22× the old point
            // size because the glyph is tall and narrow where the symbol
            // was square.
            SevenSegMark(height: glyphPointSize * 1.22)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Time remaining")
        .accessibilityValue(spokenRemaining(state: state))
    }

    private func isPaused(state: AlarmPresentationState) -> Bool {
        if case .paused = state.mode { return true }
        return false
    }

    /// Human-readable remaining time for VoiceOver — "5 minutes", "1 hour, 30 seconds".
    private func spokenRemaining(state: AlarmPresentationState) -> String {
        let seconds: TimeInterval
        switch state.mode {
        case .countdown(let countdown):
            seconds = max(0, countdown.fireDate.timeIntervalSinceNow)
        case .paused(let paused):
            seconds = max(0, paused.totalCountdownDuration - paused.previouslyElapsedDuration)
        default:
            return String(localized: "Done")
        }
        let total = Int(min(seconds.rounded(), 8.64e9))
        return Duration.seconds(total)
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))
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
        guard seconds.isFinite else { return "0:00" }
        // Cap well below Int range (~273 years) so the Int() conversion can never trap.
        let total = Int(min(max(0, seconds.rounded()), 8.64e9))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Brand mark

/// The app mark — the seven-segment "5" from the app icon — drawn from shapes
/// rather than loaded from an image.
///
/// The shipped `AppMark` asset is a flattened 1024² export: pure black canvas
/// with the glyph filling only ~30% of it, so at 22–28pt on the black island it
/// read as nothing at all. Drawing it keeps the mark crisp at every size the
/// island asks for and lets it be tinted. Geometry mirrors `SevenSegDigit` in
/// the main app (authored in a 300×480 space, corner radius 18).
private struct SevenSegMark: View {
    private struct Bar: Identifiable {
        let id: Character
        let rect: CGRect
        let lit: Bool
    }

    /// The icon's glyph lights A · F · G · C · D — a seven-segment `5`.
    private static let bars: [Bar] = [
        Bar(id: "A", rect: CGRect(x: 24,  y: 0,   width: 252, height: 62),  lit: true),
        Bar(id: "F", rect: CGRect(x: 0,   y: 78,  width: 58,  height: 126), lit: true),
        Bar(id: "B", rect: CGRect(x: 242, y: 78,  width: 58,  height: 126), lit: false),
        Bar(id: "G", rect: CGRect(x: 24,  y: 209, width: 252, height: 62),  lit: true),
        Bar(id: "E", rect: CGRect(x: 0,   y: 276, width: 58,  height: 126), lit: false),
        Bar(id: "C", rect: CGRect(x: 242, y: 276, width: 58,  height: 126), lit: true),
        Bar(id: "D", rect: CGRect(x: 24,  y: 418, width: 252, height: 62),  lit: true)
    ]

    /// Rendered height in points; width follows the icon's 300:480 aspect.
    let height: CGFloat
    var litColor: Color = LiveActivityStyle.accent
    var unlitColor: Color = LiveActivityStyle.segUnlit

    var body: some View {
        let s = height / 480   // icon space → points
        ZStack(alignment: .topLeading) {
            ForEach(Self.bars) { bar in
                RoundedRectangle(cornerRadius: 18 * s, style: .continuous)
                    .fill(bar.lit ? litColor : unlitColor)
                    .frame(width: bar.rect.width * s, height: bar.rect.height * s)
                    .offset(x: bar.rect.minX * s, y: bar.rect.minY * s)
            }
        }
        .frame(width: 300 * s, height: height, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}

// MARK: - Titles

/// Titles live in their own views because `@ScaledMetric` is a dynamic property
/// and `TimerLiveActivity` is a `Widget`, not a `View` — it can't host one. At
/// the default text size the metric returns the base value unchanged, so these
/// render exactly as the fixed-size versions did.

/// The Dynamic Island header title.
private struct HeaderTitle: View {
    let text: String
    @ScaledMetric(relativeTo: .subheadline) private var size: CGFloat = 14

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .allowsTightening(true)
    }
}

/// The lock screen banner title, mirroring `RunningTimerRow`'s name label.
private struct BannerTitle: View {
    let text: String
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 19

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(.white.opacity(0.85))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
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

// An unnamed one-shot timer — the only states where the header and the banner
// fall back to the app name.
#Preview("DI Expanded · Unnamed", as: .dynamicIsland(.expanded), using: LiveActivityPreviewData.attributes(name: "")) {
    TimerLiveActivity()
} contentStates: {
    LiveActivityPreviewData.countdown(remaining: 125)
}

#Preview("Lock Screen · Unnamed", as: .content, using: LiveActivityPreviewData.attributes(name: "")) {
    TimerLiveActivity()
} contentStates: {
    LiveActivityPreviewData.countdown(remaining: 125)
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
