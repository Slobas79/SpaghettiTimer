//
//  CoachMarks.swift
//  SpaghettiTimer
//
//  The coach-mark overlay from the tutorial design handoff: a dimmed scrim
//  with a spotlight cutout over the current step's target, a pulsing halo,
//  a connector line, and a hint card with step dots and Back / Skip / Next.
//  Ends with a "You're all set" toast.
//

import SwiftUI

extension View {
    /// Hosts the coach-mark tour for `screen`: renders the overlay while
    /// `isActive` is true, persists the once-per-screen flag on Skip/Done,
    /// and shows the "You're all set" toast after Done.
    func coachMarks(_ screen: TutorialScreen, isActive: Binding<Bool>, steps: [TutorialStep]) -> some View {
        modifier(CoachMarksHost(screen: screen, steps: steps, isActive: isActive))
    }
}

private struct CoachMarksHost: ViewModifier {
    let screen: TutorialScreen
    let steps: [TutorialStep]
    @Binding var isActive: Bool
    @State private var showToast = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlayPreferenceValue(TutorialTargetPreferenceKey.self) { anchors in
                if isActive {
                    GeometryReader { geo in
                        CoachMarksOverlay(steps: steps, anchors: anchors, geo: geo) { completed in
                            TutorialFlags.markDone(screen)
                            isActive = false
                            if completed {
                                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                                    showToast = true
                                }
                            }
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if showToast {
                    TutorialToast()
                        .padding(.bottom, 46)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                        .task {
                            try? await Task.sleep(for: .seconds(2.2))
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                                showToast = false
                            }
                        }
                }
            }
    }
}

// MARK: - Overlay

private struct CoachMarksOverlay: View {
    let steps: [TutorialStep]
    let anchors: [TutorialTargetID: Anchor<CGRect>]
    let geo: GeometryProxy
    /// `completed` is true for Done (shows the toast), false for Skip.
    let onFinish: (_ completed: Bool) -> Void

    @State private var index = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ScaledMetric(relativeTo: .caption2) private var eyebrowSize: CGFloat = 11
    @ScaledMetric(relativeTo: .headline) private var titleSize: CGFloat = 18
    @ScaledMetric(relativeTo: .subheadline) private var bodySize: CGFloat = 14
    @ScaledMetric(relativeTo: .subheadline) private var controlSize: CGFloat = 15

    var body: some View {
        // Steps whose target isn't on screen (e.g. the running banner on a
        // fresh install) are skipped rather than spotlighting empty space.
        let steps = steps.filter { anchors[$0.target] != nil }
        if !steps.isEmpty {
            let i = min(index, steps.count - 1)
            let step = steps[i]
            let spot = geo[anchors[step.target]!].insetBy(dx: -step.padding, dy: -step.padding)
            // Card goes below the spotlight when there's room (mock: target
            // bottom < 520 on an 844pt frame), above otherwise.
            let below = spot.maxY < geo.size.height - 324

            ZStack {
                scrim(spot: spot, cornerRadius: step.cornerRadius)
                spotlight(spot: spot, cornerRadius: step.cornerRadius)
                connector(spot: spot, below: below)
                card(step: step, index: i, count: steps.count, spot: spot, below: below)
            }
            .contentShape(Rectangle())
            .animation(reduceMotion ? nil : .timingCurve(0.3, 0.9, 0.3, 1, duration: 0.34), value: i)
            .accessibilityAddTraits(.isModal)
        }
    }

    /// Full-screen dim with the spotlight punched out via destination-out.
    private func scrim(spot: CGRect, cornerRadius: CGFloat) -> some View {
        ZStack {
            Theme.tourScrim
                .padding(-200) // reach under the status bar / home indicator
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .frame(width: spot.width, height: spot.height)
                .position(x: spot.midX, y: spot.midY)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
    }

    private func spotlight(spot: CGRect, cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(Theme.accent, lineWidth: 2)
            .overlay(SpotlightHalo(cornerRadius: cornerRadius))
            .frame(width: spot.width, height: spot.height)
            .position(x: spot.midX, y: spot.midY)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func connector(spot: CGRect, below: Bool) -> some View {
        Rectangle()
            .fill(Theme.accent)
            .opacity(0.85)
            .frame(width: 2, height: 26)
            .position(x: spot.midX, y: below ? spot.maxY + 15 : spot.minY - 15)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func card(step: TutorialStep, index i: Int, count: Int, spot: CGRect, below: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "Tip \(i + 1) of \(count)").uppercased())
                .font(.system(size: eyebrowSize, weight: .bold))
                .tracking(1)
                .foregroundStyle(Theme.tourEyebrow)

            Text(step.title)
                .font(.system(size: titleSize, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 5)

            Text(step.body)
                .font(.system(size: bodySize))
                .lineSpacing(bodySize * 0.45)
                .foregroundStyle(Theme.tourBody)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

            HStack(spacing: 12) {
                dots(index: i, count: count)
                Spacer(minLength: 0)
                if i > 0 {
                    backButton(from: i)
                } else {
                    skipButton
                }
                nextButton(from: i, isLast: i == count - 1)
            }
            .padding(.top, 14)
        }
        .padding(.init(top: 16, leading: 16, bottom: 14, trailing: 16))
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.tourCardBG))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.tourCardBorder, lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.6), radius: 22, y: 18)
        // Cap text growth so huge Dynamic Type sizes can't push the card
        // off screen (same cap as the tile grid).
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: below ? .top : .bottom)
        .padding(.top, below ? spot.maxY + 30 : 0)
        .padding(.bottom, below ? 0 : geo.size.height - spot.minY + 30)
        .padding(.horizontal, 20)
    }

    private func dots(index i: Int, count: Int) -> some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { d in
                Capsule()
                    .fill(d == i ? Theme.accent : Theme.tourDot)
                    .frame(width: d == i ? 16 : 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }

    private var skipButton: some View {
        Button {
            onFinish(false)
        } label: {
            Text("Skip")
                .font(.system(size: controlSize, weight: .medium))
                .foregroundStyle(Theme.mutedTime)
                .padding(.vertical, 8)
                .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Ends the tips for this screen")
    }

    private func backButton(from i: Int) -> some View {
        Button {
            index = i - 1
        } label: {
            Circle()
                .fill(Theme.tourBackFill)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.tourLightText)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Previous tip")
    }

    private func nextButton(from i: Int, isLast: Bool) -> some View {
        Button {
            if isLast {
                onFinish(true)
            } else {
                index = i + 1
            }
        } label: {
            Text(isLast ? "Done" : "Next")
                .font(.system(size: controlSize, weight: .semibold))
                .foregroundStyle(.white)
                .frame(height: 36)
                .padding(.horizontal, 18)
                .background(Capsule().fill(Theme.accent))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Halo

/// The pulsing ring around the spotlight: accent @45%, inset −8, scaling
/// 0.99 → 1.06 while fading out, 1.8s loop.
private struct SpotlightHalo: View {
    let cornerRadius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(Theme.accent.opacity(0.45), lineWidth: 1.5)
            .padding(-8)
            .scaleEffect(pulsing ? 1.06 : 0.99)
            .opacity(pulsing ? 0 : 0.9)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                    pulsing = true
                }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Toast

/// "You're all set" pill shown after Done, auto-dismissed by the host.
private struct TutorialToast: View {
    @ScaledMetric(relativeTo: .subheadline) private var textSize: CGFloat = 14

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.success)
                .accessibilityHidden(true)
            Text("You’re all set")
                .font(.system(size: textSize, weight: .semibold))
                .foregroundStyle(Theme.tourLightText)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 18)
        .background(Capsule().fill(Theme.toastBG))
        .overlay(Capsule().strokeBorder(Theme.toastBorder, lineWidth: 0.5))
    }
}
