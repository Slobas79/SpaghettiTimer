//
//  NewTimerSheet.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 23. 4. 2026..
//
//  Pixel-perfect recreation of the "New Timer (Wheel)" design handoff:
//  full-bleed black sheet, custom nav bar, outlined name field, an
//  accent-tinted scroll-snap duration wheel, and a grouped Options list.
//

import SwiftUI

struct NewTimerSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// The two ways to create a timer: dial a duration, or pick a clock time.
    enum CreationMode: Hashable { case duration, endTime }

    @State private var name: String = ""
    @State private var mode: CreationMode = .duration
    @State private var hours: Int = 0
    @State private var minutes: Int = 5
    @State private var seconds: Int = 0
    /// End-time mode source of truth: minutes-since-midnight of the target clock time (0...1439).
    @State private var endMinutes: Int = 11 * 60
    @State private var didInitEndTime = false
    @State private var isPinned: Bool = false
    @State private var autoRestart: Bool = false
    @State private var cooldownHours: Int = 0
    @State private var cooldownMinutes: Int = 0
    @State private var cooldownSeconds: Int = 0
    @FocusState private var nameFocused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .headline) private var titleSize: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var buttonSize: CGFloat = 17
    @ScaledMetric(relativeTo: .caption) private var groupLabelSize: CGFloat = 13
    @ScaledMetric(relativeTo: .body) private var nameSize: CGFloat = 19
    @ScaledMetric(relativeTo: .body) private var optionTitleSize: CGFloat = 17
    @ScaledMetric(relativeTo: .caption) private var optionDescSize: CGFloat = 13
    @ScaledMetric(relativeTo: .subheadline) private var cooldownLabelSize: CGFloat = 15
    @ScaledMetric(relativeTo: .callout) private var cooldownReadoutSize: CGFloat = 16
    @ScaledMetric(relativeTo: .caption) private var eyebrowSize: CGFloat = 12
    @ScaledMetric(relativeTo: .largeTitle) private var targetTimeSize: CGFloat = 56
    @ScaledMetric(relativeTo: .title2) private var ampmSize: CGFloat = 22
    @ScaledMetric(relativeTo: .footnote) private var dayBadgeSize: CGFloat = 13
    @ScaledMetric(relativeTo: .subheadline) private var durReadoutSize: CGFloat = 15
    @ScaledMetric(relativeTo: .subheadline) private var segLabelSize: CGFloat = 15

    let onSave: (String, TimeInterval, Bool, TimeInterval?) -> Void

    private var duration: TimeInterval {
        TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }

    /// Whether the device locale uses a 24-hour clock (no AM/PM).
    private var uses24Hour: Bool {
        let template = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? "h"
        return !template.contains("a")
    }

    private var cooldownTotal: Int {
        cooldownHours * 3600 + cooldownMinutes * 60 + cooldownSeconds
    }

    private var restartDelay: TimeInterval? {
        autoRestart ? TimeInterval(cooldownTotal) : nil
    }

    /// Duration mode disables Start at 0; End-time mode is always valid.
    private var canSave: Bool {
        switch mode {
        case .duration: return duration > 0
        case .endTime: return true
        }
    }

    /// Seconds from `now` until the picked clock time, rolling to tomorrow when the
    /// target is at or before the current time. The end instant lands on HH:MM:00.
    private func endTimeDuration(now: Date) -> TimeInterval {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: now)
        var target = cal.date(byAdding: .minute, value: endMinutes, to: startOfDay) ?? now
        if target <= now {
            target = cal.date(byAdding: .day, value: 1, to: target) ?? target
        }
        return target.timeIntervalSince(now)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        switch mode {
        case .duration:
            onSave(trimmed, duration, isPinned, restartDelay)
        case .endTime:
            // Auto-restart is meaningless for a fixed clock target, so it's always nil.
            onSave(trimmed, endTimeDuration(now: Date()), isPinned, nil)
        }
        dismiss()
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    fieldGroup("Name") {
                        nameField
                    }
                    fieldGroup("Set timer by") {
                        modePicker
                    }
                    fieldGroup(mode == .endTime ? "End time" : "Duration") {
                        if mode == .endTime {
                            endTimeSurface
                        } else {
                            WheelPicker(hours: $hours, minutes: $minutes, seconds: $seconds)
                        }
                    }
                    fieldGroup("Options") {
                        if mode == .endTime {
                            pinOnlyOptions
                        } else {
                            optionsList
                        }
                    }
                }
                .padding(.top, 4)
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            // Default the clock picker to the top of the next hour the first time.
            guard !didInitEndTime else { return }
            let hour = Calendar.current.component(.hour, from: Date())
            endMinutes = ((hour + 1) % 24) * 60
            didInitEndTime = true
        }
    }

    // MARK: - Nav bar

    private var navBar: some View {
        ZStack {
            Text("New Timer")
                .font(.system(size: titleSize, weight: .bold))
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: buttonSize))
                        .foregroundStyle(Theme.lightText)
                        .padding(.vertical, 9)
                        .padding(.horizontal, 18)
                        .background(Capsule().fill(Theme.subtleFill))
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    save()
                } label: {
                    Text("Start")
                        .font(.system(size: buttonSize, weight: .semibold))
                        .foregroundStyle(canSave ? .white : Theme.disabledText)
                        .padding(.vertical, 9)
                        .padding(.horizontal, 20)
                        .background(Capsule().fill(canSave ? Theme.accent : Theme.disabledFill))
                        .shadow(color: canSave ? Theme.accent.opacity(0.4) : .clear,
                                radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .accessibilityHint("Starts the timer with these settings")
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 18)
    }

    // MARK: - Field group scaffold

    @ViewBuilder
    private func fieldGroup<Content: View>(_ label: LocalizedStringResource, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(String(localized: label).uppercased())
                .font(.system(size: groupLabelSize, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Theme.mutedTime)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    // MARK: - Name field

    private var nameField: some View {
        TextField("", text: $name, prompt: Text("e.g. Pasta").foregroundColor(Theme.disabledText))
            .focused($nameFocused)
            .textInputAutocapitalization(.words)
            .accessibilityLabel("Timer name")
            .font(.system(size: nameSize, weight: .medium))
            .foregroundStyle(.white)
            .tint(Theme.accent)
            .frame(height: 54)
            .padding(.horizontal, 18)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surfaceFill))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(nameFocused ? Theme.accent : Theme.nameFieldBorder,
                                  lineWidth: nameFocused ? 2 : 1.5)
            )
    }

    // MARK: - Options

    private var optionsList: some View {
        VStack(spacing: 0) {
            optionRow(
                icon: "arrow.clockwise",
                title: "Auto-restart after finish",
                description: "Re-run this timer automatically after a cooldown delay.",
                isOn: $autoRestart.animation(reduceMotion ? nil : .easeInOut(duration: 0.2))
            )

            if autoRestart {
                hairline
                cooldownSection
            }

            hairline

            optionRow(
                icon: "pin",
                title: "Pin timer",
                description: "Keep this timer permanently available.",
                isOn: $isPinned
            )
        }
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.surfaceFill))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Theme.surfaceBorder, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func optionRow(icon: String, title: LocalizedStringKey, description: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(Theme.accent)
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: optionTitleSize, weight: .semibold))
                    .foregroundStyle(.white)
                Text(description)
                    .font(.system(size: optionDescSize))
                    .foregroundStyle(Theme.mutedTime)
                    .lineSpacing(optionDescSize * 0.35)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // The toggle below carries the title as its label and the
            // description as its hint, so the visual text is redundant to VO.
            .accessibilityHidden(true)

            Spacer(minLength: 0)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Theme.accent)
                .accessibilityLabel(title)
                .accessibilityHint(description)
        }
        .padding(16)
    }

    private var cooldownSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                Text("Cooldown delay")
                    .font(.system(size: cooldownLabelSize))
                    .foregroundStyle(Theme.mutedTime)
                Spacer(minLength: 8)
                Text(cooldownTotal == 0 ? String(localized: "Immediately") : Self.fmtClock(cooldownTotal))
                    .font(.system(size: cooldownReadoutSize, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.cooldownReadout)
            }
            .padding(.top, 12)
            .padding(.horizontal, 18)
            .accessibilityElement(children: .combine)

            Wheel(hours: $cooldownHours, minutes: $cooldownMinutes, seconds: $cooldownSeconds, compact: true)
        }
        .padding(.bottom, 8)
    }

    /// `m:ss` (or `h:mm:ss` when hours > 0) — matches the design's `fmtClock`.
    private static func fmtClock(_ total: Int) -> String {
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    private var hairline: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 0.5)
    }

    // MARK: - Mode picker (Duration | End time)

    private var modePicker: some View {
        HStack(spacing: 3) {
            segButton(.duration, icon: "hourglass", title: "Duration")
            segButton(.endTime, icon: "clock", title: "End time")
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Theme.segTrackFill))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Theme.segTrackBorder, lineWidth: 1)
        )
    }

    private func segButton(_ target: CreationMode, icon: String, title: LocalizedStringKey) -> some View {
        let selected = mode == target
        return Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.16)) { mode = target }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: segLabelSize, weight: .semibold))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(size: segLabelSize, weight: .semibold))
            }
            .foregroundStyle(selected ? .white : Theme.mutedTime)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? Theme.segSelectedFill : Color.clear)
                    .shadow(color: selected ? .black.opacity(0.35) : .clear, radius: 3, y: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Behaves like a segmented control: the chosen option reads as "selected".
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : [.isButton])
        .accessibilityHint("Choose how to set the timer")
    }

    // MARK: - End-time mode

    private var endTimeSurface: some View {
        VStack(spacing: 0) {
            // The readout depends on "now", so refresh it every second.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                endReadout(endInfo(now: context.date))
            }
            hairline
            clockWheel
        }
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.surfaceFill))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Theme.surfaceBorder, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private struct EndInfo {
        let timeText: String
        let ampm: String?
        let isTomorrow: Bool
        let durationText: String
    }

    private func endInfo(now: Date) -> EndInfo {
        let h24 = endMinutes / 60, minute = endMinutes % 60
        let timeText: String
        let ampm: String?
        if uses24Hour {
            timeText = String(format: "%02d:%02d", h24, minute)
            ampm = nil
        } else {
            let pm = h24 >= 12
            let h12 = ((h24 + 11) % 12) + 1
            timeText = "\(h12):" + String(format: "%02d", minute)
            let df = DateFormatter()
            ampm = pm ? df.pmSymbol : df.amSymbol
        }

        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: now)
        let nowMins = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        var delta = ((endMinutes - nowMins) % 1440 + 1440) % 1440
        let isTomorrow = endMinutes <= nowMins
        if delta == 0 { delta = 1440 }   // same clock time = 24h from now
        let h = delta / 60, m = delta % 60

        var parts: [String] = []
        if h > 0 { parts.append(String(localized: "\(h) hr")) }
        if m > 0 { parts.append(String(localized: "\(m) min")) }
        let durationText = parts.isEmpty ? String(localized: "0 min") : parts.joined(separator: " ")

        return EndInfo(timeText: timeText, ampm: ampm, isTomorrow: isTomorrow, durationText: durationText)
    }

    private func endReadout(_ info: EndInfo) -> some View {
        VStack(spacing: 0) {
            Text(String(localized: "Timer ends").uppercased())
                .font(.system(size: eyebrowSize, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.mutedTime)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(info.timeText)
                    .font(.system(size: targetTimeSize, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if let ampm = info.ampm {
                    Text(ampm)
                        .font(.system(size: ampmSize, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
            .padding(.top, 8)

            HStack(spacing: 10) {
                Text(info.isTomorrow ? "Tomorrow" : "Today")
                    .font(.system(size: dayBadgeSize, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(info.isTomorrow ? Theme.dayTomorrowBG : Theme.dayTodayBG))
                    .foregroundStyle(info.isTomorrow ? Theme.lightText : Theme.dayTodayText)

                (Text(info.durationText)
                    .font(.system(size: durReadoutSize, weight: .bold))
                    .foregroundColor(.white)
                 + Text(verbatim: " ")
                 + Text("from now")
                    .font(.system(size: durReadoutSize, weight: .medium))
                    .foregroundColor(Theme.durMutedText))
            }
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
        .padding(.bottom, 16)
        // Read as one clean sentence instead of the fragmented, all-caps pieces.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(readoutAccessibilityLabel(info))
    }

    /// e.g. "Timer ends 11:00 AM, Tomorrow, 21 hr 49 min from now" — composed from
    /// the same localized fragments shown on screen.
    private func readoutAccessibilityLabel(_ info: EndInfo) -> String {
        let time = info.ampm.map { "\(info.timeText) \($0)" } ?? info.timeText
        let day = info.isTomorrow ? String(localized: "Tomorrow") : String(localized: "Today")
        let ends = String(localized: "Timer ends")
        let fromNow = String(localized: "from now")
        return "\(ends) \(time), \(day), \(info.durationText) \(fromNow)"
    }

    private var clockWheel: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.bandFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.bandBorder, lineWidth: 1)
                )
                .frame(height: 46)
                .padding(.horizontal, 12)
                .allowsHitTesting(false)

            HStack(spacing: 0) {
                if uses24Hour {
                    ClockColumn(labels: Self.hours24Labels, value: hour24Binding, accLabel: "Hours")
                    clockColon
                    ClockColumn(labels: Self.minuteLabels, value: minuteBinding, accLabel: "Minutes")
                } else {
                    ClockColumn(labels: Self.hours12Labels, value: hour12IndexBinding, accLabel: "Hours")
                    clockColon
                    ClockColumn(labels: Self.minuteLabels, value: minuteBinding, accLabel: "Minutes")
                    ClockColumn(labels: ampmLabels, value: ampmBinding, accLabel: "AM/PM", fontSize: 24, weight: .semibold)
                }
            }
        }
        .frame(height: 220)
        .padding(.horizontal, 12)
    }

    private var clockColon: some View {
        Text(verbatim: ":")
            .font(.system(size: 30, weight: .medium))
            .foregroundStyle(Theme.disabledText)
            .frame(width: 14)
            .padding(.bottom, 2)
            .accessibilityHidden(true)
    }

    private static let hours24Labels = (0..<24).map { String(format: "%02d", $0) }
    private static let hours12Labels = (1...12).map { String($0) }
    private static let minuteLabels = (0..<60).map { String(format: "%02d", $0) }
    private var ampmLabels: [String] {
        let df = DateFormatter()
        return [df.amSymbol ?? "AM", df.pmSymbol ?? "PM"]
    }

    // Each column reads/writes a slice of `endMinutes`, the single source of truth.
    private var hour24Binding: Binding<Int> {
        Binding(get: { endMinutes / 60 },
                set: { endMinutes = $0 * 60 + endMinutes % 60 })
    }
    private var minuteBinding: Binding<Int> {
        Binding(get: { endMinutes % 60 },
                set: { endMinutes = (endMinutes / 60) * 60 + $0 })
    }
    private var hour12IndexBinding: Binding<Int> {
        Binding(
            get: { let h24 = endMinutes / 60; return (h24 + 11) % 12 },   // 0...11 → "1".."12"
            set: { idx in
                let nh12 = idx + 1
                let pm = (endMinutes / 60) >= 12
                let nh24 = (nh12 % 12) + (pm ? 12 : 0)
                endMinutes = nh24 * 60 + endMinutes % 60
            }
        )
    }
    private var ampmBinding: Binding<Int> {
        Binding(
            get: { (endMinutes / 60) >= 12 ? 1 : 0 },
            set: { sel in
                let h24 = endMinutes / 60
                let h12 = ((h24 + 11) % 12) + 1
                let nh24 = (h12 % 12) + (sel == 1 ? 12 : 0)
                endMinutes = nh24 * 60 + endMinutes % 60
            }
        )
    }

    private var pinOnlyOptions: some View {
        VStack(spacing: 0) {
            optionRow(
                icon: "pin",
                title: "Pin timer",
                description: "Keep this timer permanently available.",
                isOn: $isPinned
            )
        }
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.surfaceFill))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Theme.surfaceBorder, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - Clock wheel column

/// A snap-scroll wheel column driven by an array of string labels, sharing the
/// duration wheel's mechanics (commit-on-settle, mount-scroll-to-value, VoiceOver
/// adjustable). `value` is the selected index into `labels`.
private struct ClockColumn: View {
    let labels: [String]
    @Binding var value: Int
    let accLabel: LocalizedStringResource
    var fontSize: CGFloat = 30
    var weight: Font.Weight = .medium

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrollID: Int?

    private let itemHeight: CGFloat = 46
    private let wheelHeight: CGFloat = 220
    private var count: Int { labels.count }
    private var spacer: CGFloat { (wheelHeight - itemHeight) / 2 }
    private var clamped: Int { max(0, min(count - 1, value)) }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { i in
                    Text(labels[i])
                        .font(.system(size: fontSize, weight: weight))
                        .monospacedDigit()
                        .foregroundStyle(i == value ? .white : Theme.mutedTime)
                        .frame(maxWidth: .infinity)
                        .frame(height: itemHeight)
                        .id(i)
                }
            }
            .scrollTargetLayout()
        }
        .safeAreaPadding(.vertical, spacer)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrollID, anchor: .center)
        .frame(maxWidth: .infinity)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.32),
                    .init(color: .black, location: 0.68),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
        .sensoryFeedback(.selection, trigger: value)
        .onAppear { scrollID = clamped }
        .onChange(of: scrollID) { _, newValue in
            guard let newValue else { return }
            let c = max(0, min(count - 1, newValue))
            if c != value { value = c }
        }
        .onChange(of: value) { _, newValue in
            guard scrollID != newValue else { return }
            if reduceMotion {
                scrollID = newValue
            } else {
                withAnimation { scrollID = newValue }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accLabel))
        .accessibilityValue(Text(labels[clamped]))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(count - 1, value + 1)
            case .decrement: value = max(0, value - 1)
            @unknown default: break
            }
        }
    }
}

// MARK: - Wheel picker

/// Full-size duration wheel wrapped in the outlined surface.
private struct WheelPicker: View {
    @Binding var hours: Int
    @Binding var minutes: Int
    @Binding var seconds: Int

    var body: some View {
        Wheel(hours: $hours, minutes: $minutes, seconds: $seconds, compact: false)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.surfaceFill))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Theme.surfaceBorder, lineWidth: 1.5)
            )
    }
}

/// The wheel body (selection band + three h/m/s columns), surface-free so it can
/// render full-size in the duration surface or compact inside the Options list.
private struct Wheel: View {
    @Binding var hours: Int
    @Binding var minutes: Int
    @Binding var seconds: Int
    let compact: Bool

    private var wheelHeight: CGFloat { compact ? 144 : 220 }
    private var itemHeight: CGFloat { compact ? 36 : 46 }
    private var fontSize: CGFloat { compact ? 23 : 30 }

    var body: some View {
        ZStack {
            // Selection band, behind the columns
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.bandFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.bandBorder, lineWidth: 1)
                )
                .frame(height: itemHeight)
                .padding(.horizontal, 12)
                .allowsHitTesting(false)

            HStack(spacing: 0) {
                WheelColumn(count: 24, value: $hours, label: "Hours", itemHeight: itemHeight, wheelHeight: wheelHeight, fontSize: fontSize)
                unitLabel("h")
                WheelColumn(count: 60, value: $minutes, label: "Minutes", itemHeight: itemHeight, wheelHeight: wheelHeight, fontSize: fontSize)
                unitLabel("m")
                WheelColumn(count: 60, value: $seconds, label: "Seconds", itemHeight: itemHeight, wheelHeight: wheelHeight, fontSize: fontSize)
                unitLabel("s")
            }
        }
        .frame(height: wheelHeight)
        .padding(.horizontal, 12)
    }

    private func unitLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Theme.unitTint)
            .frame(width: 28)
            .accessibilityHidden(true)
    }
}

private struct WheelColumn: View {
    let count: Int
    @Binding var value: Int
    let label: LocalizedStringResource
    let itemHeight: CGFloat
    let wheelHeight: CGFloat
    let fontSize: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrollID: Int?

    private var spacer: CGFloat { (wheelHeight - itemHeight) / 2 }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { i in
                    Text(String(format: "%02d", i))
                        .font(.system(size: fontSize, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(i == value ? .white : Theme.mutedTime)
                        .frame(maxWidth: .infinity)
                        .frame(height: itemHeight)
                        .id(i)
                }
            }
            .scrollTargetLayout()
        }
        // Inset lives OUTSIDE the snap targets so every settle centers a number,
        // never an empty spacer.
        .safeAreaPadding(.vertical, spacer)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrollID, anchor: .center)
        .frame(maxWidth: .infinity)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.32),
                    .init(color: .black, location: 0.68),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
        .sensoryFeedback(.selection, trigger: value)
        .onAppear {
            scrollID = value
        }
        .onChange(of: scrollID) { _, newValue in
            guard let newValue else { return }
            let clamped = max(0, min(count - 1, newValue))
            if clamped != value { value = clamped }
        }
        // Drive the visible wheel when `value` is changed by the VoiceOver
        // adjustable action (or an external binding update). Guarded so it
        // never fights the scroll → value sync above.
        .onChange(of: value) { _, newValue in
            guard scrollID != newValue else { return }
            if reduceMotion {
                scrollID = newValue
            } else {
                withAnimation { scrollID = newValue }
            }
        }
        // One adjustable VoiceOver element per column: swipe up/down to change
        // the value; the unit ("Hours"/…) is announced as the label.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(verbatim: "\(value)"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(count - 1, value + 1)
            case .decrement: value = max(0, value - 1)
            @unknown default: break
            }
        }
    }
}

// MARK: - Preview

#Preview("Auto-restart ON") {
    NewTimerSheet { _, _, _, _ in }
        .seededAutoRestart()
}

#Preview("End time") {
    NewTimerSheet { _, _, _, _ in }
        .seededEndTime()
}

private extension NewTimerSheet {
    /// Renders the sheet with the cooldown reveal open so the compact wheel shows.
    func seededAutoRestart() -> some View {
        var copy = self
        copy._autoRestart = State(initialValue: true)
        return copy
    }

    /// Renders the sheet pre-switched to the End-time mode.
    func seededEndTime() -> some View {
        var copy = self
        copy._mode = State(initialValue: .endTime)
        copy._didInitEndTime = State(initialValue: true)
        return copy
    }
}
