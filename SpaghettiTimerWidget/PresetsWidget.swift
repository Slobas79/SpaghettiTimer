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
        let timers = Self.prunedTimers(at: now)
        completion(PresetsEntry(date: now,
                                presets: Self.ordered(presets, timers: timers, at: now),
                                activePresetIDs: Self.activeIDs(in: timers, at: now)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PresetsEntry>) -> Void) {
        let now = Date()
        let presets = PresetsRepoImpl().allPresets()
        let timers = Self.prunedTimers(at: now)

        let transitionDates = timers
            .filter { !$0.isPaused && $0.endDate > now }
            .map { $0.endDate }
            .sorted()

        var entries: [PresetsEntry] = [
            PresetsEntry(date: now,
                         presets: Self.ordered(presets, timers: timers, at: now),
                         activePresetIDs: Self.activeIDs(in: timers, at: now))
        ]
        for date in transitionDates {
            let entryDate = date.addingTimeInterval(0.5)
            entries.append(
                PresetsEntry(date: entryDate,
                             presets: Self.ordered(presets, timers: timers, at: entryDate),
                             activePresetIDs: Self.activeIDs(in: timers, at: entryDate))
            )
        }

        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private static func activeIDs(in timers: [RunningTimer], at date: Date) -> Set<UUID> {
        Set(timers.filter { $0.isPaused || !$0.isFinished(at: date) }.map { $0.presetID })
    }

    /// Mirrors the in-app ordering: presets with an active timer float to the front
    /// (earliest start date first), then the remaining presets keep `allPresets()` order.
    private static func ordered(_ presets: [TimerPreset],
                                timers: [RunningTimer],
                                at date: Date) -> [TimerPreset] {
        var startByPreset: [UUID: Date] = [:]
        for timer in timers where timer.isPaused || !timer.isFinished(at: date) {
            startByPreset[timer.presetID] = min(startByPreset[timer.presetID] ?? timer.startDate, timer.startDate)
        }
        guard !startByPreset.isEmpty else { return presets }

        let active = presets
            .filter { startByPreset[$0.id] != nil }
            .sorted { startByPreset[$0.id]! < startByPreset[$1.id]! }
        let inactive = presets.filter { startByPreset[$0.id] == nil }
        return active + inactive
    }

    private static func prunedTimers(at now: Date) -> [RunningTimer] {
        let repo = RunningTimersRepoImpl()
        let stored = repo.load()
        guard !stored.isEmpty else { return stored }

        let liveAlarmIDs: Set<UUID>?
        if let alarms = try? AlarmManager.shared.alarms {
            liveAlarmIDs = Set(alarms.map(\.id))
        } else {
            liveAlarmIDs = nil
        }

        let kept = stored.filter { timer in
            if let liveAlarmIDs, !liveAlarmIDs.contains(timer.id) { return false }
            if !timer.isPaused && timer.isFinished(at: now) { return false }
            if timer.endDate.addingTimeInterval(1) < now { return false }
            return true
        }

        if kept.count != stored.count {
            repo.save(kept)
        }
        print("[Widget] prunedTimers stored=\(stored.count) live=\(liveAlarmIDs?.count ?? -1) kept=\(kept.count)")
        return kept
    }
}

struct PresetsWidgetView: View {
    let entry: PresetsEntry

    @Environment(\.widgetFamily) private var family

    private let spacing: CGFloat = 8

    private var maxCount: Int { family == .systemLarge ? 9 : 6 }

    /// (cols, rows) for the number of tiles actually shown.
    private func gridShape(_ n: Int) -> (cols: Int, rows: Int) {
        switch n {
        case ..<2:  return (1, 1)   // 0 or 1
        case 2:     return (2, 1)
        case 3:     return (3, 1)
        case 4:     return (2, 2)
        case 5, 6:  return (3, 2)
        default:    return (3, 3)   // 7…9 (large only)
        }
    }

    var body: some View {
        let shown = Array(entry.presets.prefix(maxCount))
        let (cols, _) = gridShape(shown.count)
        let rows = shown.chunked(into: cols)

        VStack(spacing: spacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: spacing) {
                    ForEach(row) { preset in
                        tile(for: preset)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    // Pad the final row to `cols` cells so widths stay even.
                    if row.count < cols {
                        ForEach(0..<(cols - row.count), id: \.self) { _ in
                            Rectangle().hidden()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(8)
    }

    @ViewBuilder
    private func tile(for preset: TimerPreset) -> some View {
        let isActive = entry.activePresetIDs.contains(preset.id)
        let trimmedName = preset.name.trimmingCharacters(in: .whitespacesAndNewlines)
        Button(intent: StartTimerIntent(presetID: preset.id.uuidString)) {
            Group {
                if trimmedName.isEmpty {
                    Text(format(preset.duration))
                        .font(.system(.caption2, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 2) {
                        Text(trimmedName)
                            .font(.caption)
                            .lineLimit(1)
                        Text(format(preset.duration))
                            .font(.system(.caption2, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(isActive ? 0.35 : 0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: isActive ? 1.5 : 0)
            )
            .overlay(alignment: .topTrailing) {
                if isActive {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                        .padding(4)
                }
            }
        }
        .buttonStyle(.plain)
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

struct PresetsWidget: Widget {
    let kind: String = "PresetsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PresetsProvider()) { entry in
            PresetsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("SpaghettiTimer")
        .description("Start your favorite timers right from the Home Screen.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
