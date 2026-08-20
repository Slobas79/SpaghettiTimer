//
//  PresetsWidget.swift
//  SpaghettiTimerWidget
//
//  Created by Slobodan Stamenic on 23. 4. 2026..
//

import AlarmKit
import AppIntents
import SwiftUI
import WidgetKit

struct PresetsEntry: TimelineEntry {
    let date: Date
    let presets: [TimerPreset]
    let activePresetIDs: Set<UUID>
}

struct PresetsProvider: TimelineProvider {
    func placeholder(in context: Context) -> PresetsEntry {
        PresetsEntry(date: Date(), presets: TimerPreset.builtIns, activePresetIDs: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (PresetsEntry) -> Void) {
        let now = Date()
        let presets = PresetsRepoImpl().allPresets()
        let timers = RunningTimersMerge.visible(in: RunningTimersRepoImpl().load(),
                                               liveAlarmIDs: Self.liveAlarmIDs(),
                                               now: now)
        completion(PresetsEntry(date: now,
                                presets: presets,
                                activePresetIDs: Self.activeIDs(in: timers, at: now)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PresetsEntry>) -> Void) {
        let now = Date()
        let presets = PresetsRepoImpl().allPresets()
        let timers = RunningTimersMerge.visible(in: RunningTimersRepoImpl().load(),
                                               liveAlarmIDs: Self.liveAlarmIDs(),
                                               now: now)

        let transitionDates = timers
            .filter { !$0.isPaused && $0.endDate > now }
            .map { $0.endDate }
            .sorted()

        var entries: [PresetsEntry] = [
            PresetsEntry(date: now,
                         presets: presets,
                         activePresetIDs: Self.activeIDs(in: timers, at: now))
        ]
        for date in transitionDates {
            let entryDate = date.addingTimeInterval(0.5)
            entries.append(
                PresetsEntry(date: entryDate,
                             presets: presets,
                             activePresetIDs: Self.activeIDs(in: timers, at: entryDate))
            )
        }

        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private static func activeIDs(in timers: [RunningTimer], at date: Date) -> Set<UUID> {
        Set(timers.filter { $0.isPaused || !$0.isFinished(at: date) }.map { $0.presetID })
    }

    /// Live alarm ids, or `nil` when AlarmKit can't be queried from this process.
    ///
    /// The widget only ever *reads* shared storage. It used to write its filtered
    /// list back, which deleted the record of the timer alerting at that moment —
    /// so `StopTimerIntent` found nothing to auto-restart and the chain died. The
    /// filtering now lives in `RunningTimersMerge.visible`, which takes an array and
    /// returns an array and so cannot persist anything.
    private static func liveAlarmIDs() -> Set<UUID>? {
        guard let alarms = try? AlarmManager.shared.alarms else { return nil }
        return Set(alarms.map(\.id))
    }

}

/// Visual constants mirrored from the design handoff (and the main app's `Theme.swift`,
/// which is not compiled into the widget target — same duplication as `LiveActivityStyle`).
private enum WidgetStyle {
    static let accent = Color(red: 10 / 255, green: 132 / 255, blue: 255 / 255)      // #0A84FF
    static let muted = Color(red: 138 / 255, green: 147 / 255, blue: 163 / 255)      // #8A93A3
    static let tileFill = Color.white.opacity(0.02)                                  // outlined tile fill
    static let tileBorder = Color(red: 56 / 255, green: 160 / 255, blue: 255 / 255).opacity(0.32) // rgba(56,160,255,.32)

    static let tileRadius: CGFloat = 17

    /// Container fill — top-lit dark gradient #20242C → #14171D.
    static let containerGradient = LinearGradient(
        colors: [Color(red: 32 / 255, green: 36 / 255, blue: 44 / 255),
                 Color(red: 20 / 255, green: 23 / 255, blue: 29 / 255)],
        startPoint: .top, endPoint: .bottom)

    /// Active tile fill — 160° accent gradient (mix(accent,white) → accent → mix(accent,black)).
    static let activeGradient = LinearGradient(
        stops: [
            .init(color: Color(red: 30 / 255, green: 142 / 255, blue: 255 / 255), location: 0),
            .init(color: accent, location: 0.48),
            .init(color: Color(red: 8 / 255, green: 106 / 255, blue: 204 / 255), location: 1)
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing)
}

struct PresetsWidgetView: View {
    let entry: PresetsEntry

    @Environment(\.widgetFamily) private var family
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    private var isSmall: Bool { family == .systemSmall }
    private var isLarge: Bool { family == .systemLarge }

    private var maxCount: Int { isLarge ? 6 : 4 }
    private var gridRows: Int { isLarge ? 3 : 2 }
    private let gridColumns = 2
    private let gridGap: CGFloat = 10

    private var labelSize: CGFloat { isSmall ? 15 : (isLarge ? 18 : 17) }
    private var subSize: CGFloat { isSmall ? 12 : 14 }
    private var rowGap: CGFloat { isSmall ? 1 : 3 }
    private var sidePadding: CGFloat { isSmall ? 12 : 16 }

    private var contentPadding: EdgeInsets {
        switch family {
        case .systemSmall: return EdgeInsets(top: 13, leading: 13, bottom: 13, trailing: 13)
        case .systemLarge: return EdgeInsets(top: 18, leading: 16, bottom: 16, trailing: 16)
        default:           return EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
        }
    }

    var body: some View {
        let shown = Array(entry.presets.prefix(maxCount))
        VStack(spacing: 14) {
            if isLarge { header }
            grid(shown)
        }
        .padding(contentPadding)
    }

    // MARK: Grid (fixed columns × rows so tile proportions match the mock)

    private func grid(_ presets: [TimerPreset]) -> some View {
        VStack(spacing: gridGap) {
            ForEach(0..<gridRows, id: \.self) { row in
                HStack(spacing: gridGap) {
                    ForEach(0..<gridColumns, id: \.self) { col in
                        let idx = row * gridColumns + col
                        Group {
                            if idx < presets.count {
                                tile(for: presets[idx])
                            } else {
                                Color.clear
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Header (Large only)

    private var header: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(WidgetStyle.accent)
                .frame(width: 22, height: 22)
                .overlay(
                    Image(systemName: "timer")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                )
                .shadow(color: WidgetStyle.accent.opacity(0.45), radius: 3, y: 2)

            Text("Spaghetti Timer")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                if let activeLabel {
                    Circle()
                        .fill(WidgetStyle.accent)
                        .frame(width: 7, height: 7)
                        .accessibilityHidden(true)
                    Text("\(activeLabel) running")
                } else {
                    Text("Quick start")
                }
            }
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(WidgetStyle.muted)
            .monospacedDigit()
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
    }

    /// Label of the currently-running preset (name, or formatted duration if unnamed).
    private var activeLabel: String? {
        guard let preset = entry.presets.first(where: { entry.activePresetIDs.contains($0.id) }) else {
            return nil
        }
        let name = preset.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? format(preset.duration) : name
    }

    // MARK: Tile

    @ViewBuilder
    private func tile(for preset: TimerPreset) -> some View {
        let isActive = entry.activePresetIDs.contains(preset.id)
        let isRepeat = preset.autoRestartDelaySeconds != nil
        let name = preset.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let iconOnly = isRepeat && name.isEmpty
        let unnamedOneShot = !isRepeat && name.isEmpty

        Button(intent: StartTimerIntent(presetID: preset.id.uuidString)) {
            VStack(alignment: .leading, spacing: rowGap) {
                // Label row: optional loop glyph, then optional name (or promoted duration).
                HStack(spacing: 6) {
                    if isRepeat {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: iconOnly ? (isSmall ? 22 : 26) : 18, weight: .semibold))
                            .foregroundStyle(isActive ? Color.white : WidgetStyle.accent)
                            .accessibilityHidden(true)
                    }
                    if !name.isEmpty {
                        Text(name)
                            .font(.system(size: labelSize, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    } else if unnamedOneShot {
                        Text(format(preset.duration))
                            .font(.system(size: labelSize, weight: .semibold))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }

                // Sub line — duration, or "Running" when active.
                // Hidden for an unnamed one-shot (duration already promoted to the label row).
                if !unnamedOneShot {
                    Text(isActive ? String(localized: "Running") : format(preset.duration))
                        .font(.system(size: subSize, weight: isActive ? .semibold : .medium))
                        .foregroundStyle(isActive ? Color.white.opacity(0.9) : WidgetStyle.muted)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .padding(.horizontal, sidePadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: WidgetStyle.tileRadius, style: .continuous)
                    .fill(isActive ? AnyShapeStyle(WidgetStyle.activeGradient)
                                   : AnyShapeStyle(WidgetStyle.tileFill))
            )
            .overlay {
                RoundedRectangle(cornerRadius: WidgetStyle.tileRadius, style: .continuous)
                    .strokeBorder(isActive ? Color.clear : WidgetStyle.tileBorder, lineWidth: 1.5)
            }
            .overlay {
                if isActive {
                    // Inset top highlight rgba(255,255,255,0.25).
                    RoundedRectangle(cornerRadius: WidgetStyle.tileRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [Color.white.opacity(0.25), .clear],
                                           startPoint: .top, endPoint: .center),
                            lineWidth: 1)
                }
            }
            .overlay {
                // Non-color cue: the active tile is otherwise only a blue gradient.
                if isActive && differentiateWithoutColor {
                    RoundedRectangle(cornerRadius: WidgetStyle.tileRadius, style: .continuous)
                        .strokeBorder(Color.white, lineWidth: 2)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isActive { liveDot }
            }
            .clipShape(RoundedRectangle(cornerRadius: WidgetStyle.tileRadius, style: .continuous))
            .shadow(color: isActive ? WidgetStyle.accent.opacity(0.42) : .clear,
                    radius: isActive ? 8 : 0, x: 0, y: isActive ? 6 : 0)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name.isEmpty ? Text("Timer") : Text(name))
        .accessibilityValue(tileAccessibilityValue(preset: preset, isActive: isActive, isRepeat: isRepeat))
        .accessibilityHint("Starts the timer")
        .accessibilityAddTraits(.isButton)
    }

    /// Spoken duration plus running / repeats state for a preset tile.
    private func tileAccessibilityValue(preset: TimerPreset, isActive: Bool, isRepeat: Bool) -> Text {
        var parts = [spoken(preset.duration)]
        if isActive { parts.append(String(localized: "Running")) }
        if isRepeat { parts.append(String(localized: "Repeats")) }
        return Text(parts.joined(separator: ", "))
    }

    private var liveDot: some View {
        let dot: CGFloat = isSmall ? 8 : 9
        let inset: CGFloat = isSmall ? 8 : 11
        return Circle()
            .fill(Color.white)
            .frame(width: dot, height: dot)
            .background(
                Circle()
                    .fill(WidgetStyle.accent.opacity(0.55))
                    .frame(width: dot + 6, height: dot + 6)
            )
            // Non-color cue: ring the dot so it's not a pure color blob.
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(differentiateWithoutColor ? 0.9 : 0),
                                  lineWidth: 1.5)
                    .frame(width: dot + 6, height: dot + 6)
            )
            .padding(inset)
            .accessibilityHidden(true)
    }

    private func format(_ interval: TimeInterval) -> String {
        guard interval.isFinite, interval > 0 else { return "00:00" }
        // Cap well below Int range (~273 years) so the Int() conversion can never trap.
        let total = Int(min(interval.rounded(.up), 8.64e9))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    /// Human-readable, localized duration for VoiceOver — mirrors
    /// `TimerFormatting.spoken` in the app target (not compiled into the widget).
    private func spoken(_ interval: TimeInterval) -> String {
        let total = Int(min(max(0, interval.rounded()), 8.64e9))
        return Duration.seconds(total)
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))
    }
}

struct PresetsWidget: Widget {
    let kind: String = "PresetsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PresetsProvider()) { entry in
            PresetsWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetStyle.containerGradient }
                .environment(\.colorScheme, .dark)
        }
        .contentMarginsDisabled()
        .configurationDisplayName("SpaghettiTimer")
        .description("Start your favorite timers right from the Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#if DEBUG
private extension TimerPreset {
    /// Four-tile set: three named one-shots + one named repeating preset.
    static let previewQuad: [TimerPreset] = [
        TimerPreset(name: "1 min", duration: 60, isBuiltIn: true),
        TimerPreset(name: "5 min", duration: 300, isBuiltIn: true),
        TimerPreset(name: "10 min", duration: 600, isBuiltIn: true),
        TimerPreset(name: "Pasta", duration: 480, autoRestartDelaySeconds: 5)
    ]

    /// Six-tile set for Large: the quad plus 45 min and an unnamed repeating interval.
    static let previewHex: [TimerPreset] = previewQuad + [
        TimerPreset(name: "45 min", duration: 2700),
        TimerPreset(name: "", duration: 5, autoRestartDelaySeconds: 5)
    ]
}

#Preview("Small", as: .systemSmall) {
    PresetsWidget()
} timeline: {
    let p = TimerPreset.previewQuad
    PresetsEntry(date: .now, presets: p, activePresetIDs: [p[0].id])
}

#Preview("Medium", as: .systemMedium) {
    PresetsWidget()
} timeline: {
    let p = TimerPreset.previewQuad
    PresetsEntry(date: .now, presets: p, activePresetIDs: [])
    PresetsEntry(date: .now, presets: p, activePresetIDs: [p[0].id])
}

#Preview("Large", as: .systemLarge) {
    PresetsWidget()
} timeline: {
    let p = TimerPreset.previewHex
    PresetsEntry(date: .now, presets: p, activePresetIDs: [])
    PresetsEntry(date: .now, presets: p, activePresetIDs: [p[0].id])
}
#endif
