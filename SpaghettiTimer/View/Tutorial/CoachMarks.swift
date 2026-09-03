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
    /// `isActive` is true, persists the once-per-screen flag on Done only
    /// (Skip leaves the tour on offer), and shows the "You're all set" toast
    /// after Done. `onTab` is called
    /// when the shown step declares a sheet tab, so the host screen can put
    /// itself in the state the step spotlights (e.g. switch to End time).
    func coachMarks(_ screen: TutorialScreen,
                    isActive: Binding<Bool>,
                    steps: [TutorialStep],
                    onTab: ((TutorialSheetTab) -> Void)? = nil) -> some View {
        modifier(CoachMarksHost(screen: screen, steps: steps, onTab: onTab, isActive: isActive))
    }
}

private struct CoachMarksHost: ViewModifier {
    let screen: TutorialScreen
    let steps: [TutorialStep]
    let onTab: ((TutorialSheetTab) -> Void)?
    @Binding var isActive: Bool
    @State private var showToast = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlayPreferenceValue(TutorialTargetPreferenceKey.self) { anchors in
                if isActive {
                    GeometryReader { geo in
                        CoachMarksOverlay(steps: steps, anchors: anchors, geo: geo, onTab: onTab) { completed in
                            isActive = false
                            // Only a completed tour retires the screen's Help
                            // button. Skip just puts the tips away — they stay
                            // on offer until the user has actually seen them
                            // through to the last tip.
                            guard completed else { return }
                            TutorialFlags.markDone(screen)
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                                showToast = true
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
    /// Applies a step's required sheet tab on the host screen.
    let onTab: ((TutorialSheetTab) -> Void)?
    /// `completed` is true for Done (shows the toast), false for Skip.
    let onFinish: (_ completed: Bool) -> Void

    @State private var index = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Stable id for the sample timer shown in the running-banner artwork.
    private static let artBannerID = UUID()

    @ScaledMetric(relativeTo: .caption2) private var eyebrowSize: CGFloat = 11
    @ScaledMetric(relativeTo: .headline) private var titleSize: CGFloat = 18
    @ScaledMetric(relativeTo: .subheadline) private var bodySize: CGFloat = 14
    @ScaledMetric(relativeTo: .subheadline) private var controlSize: CGFloat = 15

    var body: some View {
        // Spotlight steps whose target isn't on screen (e.g. a target removed
        // from a screen) are skipped rather than spotlighting empty space.
        // Artwork steps have no target and are always shown. Steps that
        // declare a tab also always stay: their target may be off screen right
        // now (the sheet is in the other mode), but applying the tab brings it
        // back — filtering them out would collapse the step count mid-tour.
        let steps = steps.filter { step in
            if step.art != nil || step.tab != nil { return true }
            if let target = step.target { return anchors[target] != nil }
            return false
        }
        if !steps.isEmpty {
            let i = min(index, steps.count - 1)
            let step = steps[i]

            ZStack {
                if step.art != nil {
                    artworkLayer(step: step, index: i, count: steps.count)
                } else {
                    spotlightLayer(step: step, index: i, count: steps.count)
                }
            }
            .contentShape(Rectangle())
            .animation(reduceMotion ? nil : .timingCurve(0.3, 0.9, 0.3, 1, duration: 0.34), value: i)
            .accessibilityAddTraits(.isModal)
            // Put the screen into the state the step spotlights — on entry
            // and on every Next/Back move (state follows whatever step shows).
            .onAppear {
                if let tab = step.tab { onTab?(tab) }
            }
            .onChange(of: i) { _, newIndex in
                if let tab = steps[min(newIndex, steps.count - 1)].tab { onTab?(tab) }
            }
            // Keep the stored index inside the filtered range. Without this a
            // shrinking script (a spotlight target leaving the screen) would
            // leave `index` past the end, where `min(...)` re-clamps it to the
            // same step every time — Next stops advancing and the final Done,
            // which is what persists the "tour finished" flag, is unreachable.
            .onChange(of: steps.count) { _, newCount in
                index = min(index, max(0, newCount - 1))
            }
        }
    }

    /// Spotlight tip: dimmed scrim with a cutout + halo + connector on the
    /// step's on-screen target, and the hint card below/above the cutout.
    @ViewBuilder
    private func spotlightLayer(step: TutorialStep, index i: Int, count: Int) -> some View {
        if let anchor = step.target.flatMap({ anchors[$0] }) {
            let spot = geo[anchor].insetBy(dx: -step.padding, dy: -step.padding)
            // Card placement: per-step override, else below the spotlight when
            // there's room (mock: target bottom < 520 on an 844pt frame).
            let below = switch step.place {
            case .below: true
            case .above: false
            case nil: spot.maxY < geo.size.height - 324
            }

            scrim(spot: spot, cornerRadius: step.cornerRadius)
            spotlight(spot: spot, cornerRadius: step.cornerRadius)
            connector(spot: spot, below: below)
            card(step: step, index: i, count: count, spot: spot, below: below)
        } else {
            // The target is momentarily off screen — the sheet is still
            // switching into the state `onTab` asked for. Hold the plain scrim
            // until the anchor arrives on the next preference update.
            Theme.tourScrim
                .padding(-200)
        }
    }

    /// Artwork tip: plain full scrim (no cutout) with a card that embeds a
    /// rendering of an off-screen feature above the eyebrow. Most artwork tips
    /// centre the card; the running-banner tip pins it to the top so its
    /// embedded row sits roughly where a real running timer appears — at the
    /// top of the grid, just under the safe area.
    private func artworkLayer(step: TutorialStep, index i: Int, count: Int) -> some View {
        // Real banner lives at safe-area top + 6pt content padding. The card's
        // own 16pt inner top inset sits above the art, so offset the card up by
        // that much to line the art up with where the banner appears.
        let pinnedToTop = step.art == .runningBanner
        let topInset = max(0, geo.safeAreaInsets.top + 6 - 16)

        return ZStack {
            Theme.tourScrim
                .padding(-200) // reach under the status bar / home indicator

            cardBody(step: step, index: i, count: count, art: step.art)
                .frame(maxWidth: .infinity, maxHeight: .infinity,
                       alignment: pinnedToTop ? .top : .center)
                .padding(.top, pinnedToTop ? topInset : 0)
                .padding(.horizontal, 20)
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

    /// Spotlight card: shared card body positioned below/above the cutout.
    private func card(step: TutorialStep, index i: Int, count: Int, spot: CGRect, below: Bool) -> some View {
        cardBody(step: step, index: i, count: count, art: nil)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: below ? .top : .bottom)
            .padding(.top, below ? spot.maxY + 30 : 0)
            .padding(.bottom, below ? 0 : geo.size.height - spot.minY + 30)
            .padding(.horizontal, 20)
    }

    /// The hint card itself — optional artwork, eyebrow, title, body, footer.
    /// Shared by spotlight tips (`art == nil`) and artwork tips.
    private func cardBody(step: TutorialStep, index i: Int, count: Int, art: TutorialArt?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let art {
                artBlock(art)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 12)
            }

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

            // Footer order: step dots · Skip (always) · ‹ Back (tip ≥ 2) · Next/Done.
            HStack(spacing: 12) {
                dots(index: i, count: count)
                Spacer(minLength: 0)
                skipButton
                if i > 0 {
                    backButton(from: i)
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
    }

    /// The feature rendering embedded at the top of an artwork card. Both
    /// inherit the app accent and are non-interactive.
    @ViewBuilder
    private func artBlock(_ art: TutorialArt) -> some View {
        switch art {
        case .runningBanner:
            // The classic running banner as it looks mid-countdown ("Al Dente · 07:59").
            RunningTimerRow(
                timer: RunningTimer(
                    id: Self.artBannerID,
                    presetID: Self.artBannerID,
                    name: "Al Dente",
                    startDate: Date().addingTimeInterval(-1),
                    duration: 480
                ),
                now: Date(),
                onPause: {}, onResume: {}, onCancel: {}
            )
            .scaleEffect(0.92)
            .allowsHitTesting(false)
            .padding(.bottom, -4) // soak up the scale gap (mock: margin-bottom: -4)
            .accessibilityHidden(true)

        case .dynamicIsland:
            // Same fixed-design-scaled-to-fit treatment as the widget art
            // below: pin the layout frame to the scaled size so the art can't
            // push the card off screen on narrow devices.
            let diWidth = TutorialDynamicIslandArt.designWidth
            let diHeight = TutorialDynamicIslandArt.designHeight
            let diScale = min(0.87, (geo.size.width - 80) / diWidth)
            TutorialDynamicIslandArt()
                .scaleEffect(diScale)
                .frame(width: diWidth * diScale, height: diHeight * diScale)

        case .widget:
            // TutorialWidgetArt is a fixed 364×170 design. scaleEffect is a
            // render-only transform, so we must also pin the layout frame to the
            // scaled size — otherwise the art keeps its 364pt layout width and
            // pushes the card off screen. Cap at the design scale (0.87) but
            // shrink further on narrow screens so it always fits the card, whose
            // content width is the screen minus the artwork (20·2) and card
            // (16·2) horizontal insets.
            let available = geo.size.width - 72
            let scale = min(0.87, available / 364)
            TutorialWidgetArt()
                .scaleEffect(scale)
                .frame(width: 364 * scale, height: 170 * scale)
        }
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
