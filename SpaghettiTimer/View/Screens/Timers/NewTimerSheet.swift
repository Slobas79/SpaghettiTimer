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

    @State private var name: String = ""
    @State private var hours: Int = 0
    @State private var minutes: Int = 5
    @State private var seconds: Int = 0
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

    let onSave: (String, TimeInterval, Bool, TimeInterval?) -> Void

    private var duration: TimeInterval {
        TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }

    private var cooldownTotal: Int {
        cooldownHours * 3600 + cooldownMinutes * 60 + cooldownSeconds
    }

    private var restartDelay: TimeInterval? {
        autoRestart ? TimeInterval(cooldownTotal) : nil
    }

    private var canSave: Bool { duration > 0 }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    fieldGroup("Name") {
                        nameField
                    }
                    fieldGroup("Duration") {
                        WheelPicker(hours: $hours, minutes: $minutes, seconds: $seconds)
                    }
                    fieldGroup("Options") {
                        optionsList
                    }
                }
                .padding(.top, 4)
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .background(Color.black.ignoresSafeArea())
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
                    onSave(name.trimmingCharacters(in: .whitespacesAndNewlines), duration, isPinned, restartDelay)
                    dismiss()
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

private extension NewTimerSheet {
    /// Renders the sheet with the cooldown reveal open so the compact wheel shows.
    func seededAutoRestart() -> some View {
        var copy = self
        copy._autoRestart = State(initialValue: true)
        return copy
    }
}
