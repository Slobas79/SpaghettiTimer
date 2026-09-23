//
//  TimersView.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 23. 4. 2026..
//

import SwiftUI
import UIKit

struct TimersView: View {
    @State var viewModel: TimersViewModel
    let store: StoreUseCase
    @State private var showingNew = false
    @State private var showingSplash = false
    @State private var showingTour = false
    @State private var directPaywall: PaywallTrigger?
    /// The Home tour script, resolved once in `onAppear`. Kept in state rather
    /// than recomputed in `body`: `TutorialTour.home` asks the device whether
    /// it has a Dynamic Island, which reads `false` until the key window is
    /// laid out — recomputing per render could change the step count (and with
    /// it which card is last) while the tour is running.
    @State private var homeSteps: [TutorialStep] = []
    /// Mirrors `tutorial.home.done`. `@AppStorage` observes the key, so
    /// finishing or skipping the tour hides the Help button immediately
    /// instead of relying on some other state change to re-run `body`.
    @AppStorage(TutorialScreen.home.rawValue, store: AppGroup.defaults)
    private var homeTourDone = false

    /// Where VoiceOver goes when the element it is on is removed — a
    /// dismissed running row, an unpinned tile. Left alone, VoiceOver stays
    /// on the vanished element and appears stuck.
    @AccessibilityFocusState private var focus: HomeFocus?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    private let columns = [
        GridItem(.flexible(), spacing: Theme.gridGap),
        GridItem(.flexible(), spacing: Theme.gridGap)
    ]

    /// Whether the tour has to supply its own tile to spotlight. Unpinning
    /// deletes a preset, so the grid really can end up empty — and tips 1 and 2
    /// point at a preset tile and its pin badge. Rather than let the overlay
    /// drop both tips as "target not on screen", we stand a sample tile in the
    /// grid for the length of the tour. It is never saved and never starts
    /// anything; see `TutorialSample`.
    private var showsTourSampleTile: Bool {
        showingTour && viewModel.presetTiles.isEmpty
    }

    /// Home's secondary actions, behind the ••• corner menu — the single
    /// entry point for Replay tips, the direct paywall and Restore Purchases.
    @ViewBuilder
    private var secondaryActions: some View {
        Button {
            showingTour = true
        } label: {
            Label("Replay tips", systemImage: "questionmark.circle")
        }
        if !store.isPro {
            Button {
                directPaywall = .general
            } label: {
                Label("Unlock Pro", systemImage: "crown")
            }
        }
        Button {
            Task { await store.restore() }
        } label: {
            Label("Restore Purchases", systemImage: "arrow.clockwise.circle")
        }
    }

    var body: some View {
        ZStack {
            Theme.screenBG.ignoresSafeArea()

            TimelineView(.periodic(from: .now, by: 0.25)) { context in
                ScrollView {
                    VStack(spacing: Theme.stackGap) {
                        if !viewModel.runningRows.isEmpty {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.runningRows) { timer in
                                    RunningTimerRow(
                                        timer: timer,
                                        now: context.date,
                                        onPause: { viewModel.pause(timer) },
                                        onResume: { viewModel.resume(timer) },
                                        onCancel: { dismiss(timer) },
                                        focus: $focus
                                    )
                                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                                }
                            }
                        }

                        LazyVGrid(columns: columns, spacing: Theme.gridGap) {
                            // Always the first cell when present — it never
                            // reorders with the pinned presets behind it.
                            if viewModel.isNextHourPinned {
                                NextHourTile(
                                    now: context.date,
                                    onStart: { viewModel.startNextHour() },
                                    onUnpin: { unpinNextHour() }
                                )
                                .accessibilityFocused($focus, equals: .nextHour)
                            }

                            ForEach(viewModel.presetTiles) { item in
                                TimerTile(
                                    preset: item.preset,
                                    onStart: { viewModel.start(item.preset) },
                                    onUnpin: { unpin(item.preset) },
                                    onPin: nil
                                )
                                .accessibilityFocused($focus, equals: .preset(item.preset.id))
                                .tutorialTarget(.presetTile)
                            }

                            if showsTourSampleTile {
                                TourSampleTile()
                            }
                        }
                    }
                    // Cap text growth on the fixed-aspect tiles / fixed-height
                    // rows so very large Dynamic Type sizes can't break the layout.
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.top, 6)
                    // Clear the floating + FAB so the last grid row never hides beneath it.
                    .padding(.bottom, 96)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: viewModel.runningRows)
                }
            }
        }
        // Floating + FAB, pinned bottom-centre. Sits beneath the coach-mark/
        // splash overlays so the tour scrim covers it — and so tip 3 can
        // spotlight it through the scrim's cutout. Tap only: the secondary
        // actions it used to hide behind a long-press now live in the visible
        // ••• menu bottom-left.
        .overlay(alignment: .bottom) {
            AddTimerFAB(action: { showingNew = true })
                .accessibilityFocused($focus, equals: .add)
                .tutorialTarget(.addTile)
                .padding(.bottom, 34)
        }
        // One-shot Help trigger, bottom-LEFT: starts the Home tour on demand
        // and is gone for good once the tour has been played through to the
        // last tip and finished with Done. Skipping leaves it here. It takes
        // the leading corner precisely because it retires — the corner it
        // vacates is the one the thumb reaches for least. Clear of the running
        // banner (top) and the centre FAB; beneath the coach-mark/splash
        // overlays so the tour scrim covers it.
        .overlay(alignment: .bottomLeading) {
            if !showingSplash && !showingTour && !homeTourDone {
                TutorialHelpButton(style: .corner) {
                    showingTour = true
                }
                .padding(.leading, 20)
                .padding(.bottom, 45)
            }
        }
        // The permanent ••• menu, bottom-RIGHT, mirroring the Help button's
        // corner geometry. This one never goes away, so it owns the settled
        // thumb-side corner: Restore Purchases and the direct paywall stay one
        // tap from the grid for the life of the install. Hidden under the
        // splash/tour like its opposite number.
        .overlay(alignment: .bottomTrailing) {
            if !showingSplash && !showingTour {
                Menu {
                    secondaryActions
                } label: {
                    CornerChromeGlyph(systemName: "ellipsis")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("More options")
                .padding(.trailing, 20)
                .padding(.bottom, 45)
            }
        }
        .coachMarks(.home, isActive: $showingTour, steps: homeSteps)
        .overlay {
            if showingSplash {
                // The splash plays through on its own — the Home tour stays
                // available behind the Help button either way.
                TutorialSplash(
                    onFinish: {
                        showingSplash = false
                        TutorialFlags.markDone(.splash)
                    }
                )
            }
        }
        .sheet(isPresented: $showingNew) {
            NewTimerSheet(
                store: store,
                pinnedCount: viewModel.userPresetCount,
                onSave: { name, duration, pinned, autoRestartDelaySeconds in
                    viewModel.createTimer(name: name, duration: duration, pinned: pinned, autoRestartDelaySeconds: autoRestartDelaySeconds)
                },
                onPinNextHour: { viewModel.setNextHourPinned(true) }
            )
            .presentationBackground(.black)
            .presentationDragIndicator(.hidden)
        }
        .sheet(item: $directPaywall) { trigger in
            PaywallView(store: store, trigger: trigger)
                .presentationBackground(.black)
        }
        // Nothing started, and the tap has to say so. A refused alarm permission is
        // the one case where a preset tap is deliberately inert — silence there
        // reads as a broken tile.
        .alert("Alarms are turned off", isPresented: $viewModel.isAlarmPermissionDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("SpaghettiTimer needs permission to schedule alarms — without it a timer can’t ring, so it won’t start. Turn alarms on in Settings, then try again.")
        }
        .onAppear {
            viewModel.refresh()
            // Resolve the tour script now that the window is laid out, so the
            // Dynamic Island tip is included on the hardware that has one and
            // the step count stays fixed for the life of this screen.
            homeSteps = TutorialTour.home
            // First app run only: play the intro splash, then land on the
            // normal Home screen (with the Help button). The splash never
            // consumes the Home tour — that's the Help button's job.
            if !TutorialFlags.isDone(.splash) {
                showingSplash = true
            }
        }
    }
}

// MARK: - VoiceOver focus hand-off

extension TimersView {
    private func dismiss(_ timer: RunningTimer) {
        let rows = viewModel.runningRows
        var target = firstTileFocus
        if let i = rows.firstIndex(where: { $0.id == timer.id }), rows.count > 1 {
            // The row below takes its place; the last row hands back upward.
            target = .running(rows[i + 1 < rows.count ? i + 1 : i - 1].id)
        }
        viewModel.stop(timer)
        moveFocus(to: target)
    }

    private func unpin(_ preset: TimerPreset) {
        let tiles = viewModel.presetTiles
        var target: HomeFocus = viewModel.isNextHourPinned ? .nextHour : .add
        if let i = tiles.firstIndex(where: { $0.preset.id == preset.id }), tiles.count > 1 {
            target = .preset(tiles[i + 1 < tiles.count ? i + 1 : i - 1].preset.id)
        }
        viewModel.deletePreset(preset)
        moveFocus(to: target)
    }

    private func unpinNextHour() {
        viewModel.setNextHourPinned(false)
        moveFocus(to: viewModel.presetTiles.first.map { .preset($0.preset.id) } ?? .add)
    }

    /// The first grid cell, or the + button when the grid is empty.
    private var firstTileFocus: HomeFocus {
        if viewModel.isNextHourPinned { return .nextHour }
        return viewModel.presetTiles.first.map { .preset($0.preset.id) } ?? .add
    }

    /// Set after the removal animation, once the layout has settled and the
    /// old element is gone — set sooner, VoiceOver can land on the element
    /// that is on its way out.
    private func moveFocus(to target: HomeFocus) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            focus = target
        }
    }
}

/// The Home elements VoiceOver focus can be handed to.
enum HomeFocus: Hashable {
    case running(UUID)
    case nextHour
    case preset(UUID)
    case add
}

/// Binds an element to Home's focus when the view has one to bind to.
struct HomeFocusTarget: ViewModifier {
    let focus: AccessibilityFocusState<HomeFocus?>.Binding?
    let value: HomeFocus

    func body(content: Content) -> some View {
        if let focus {
            content.accessibilityFocused(focus, equals: value)
        } else {
            content
        }
    }
}

// MARK: - Tour sample tile

/// The stand-in tile the Home tour spotlights when every preset has been
/// unpinned. A real `TimerTile` — same face, same pin badge, so tips 1 and 2
/// point at exactly what they describe — but inert: its actions are empty, hit
/// testing is off so it can't be tapped even if the scrim ever let a touch
/// through, and VoiceOver skips it (the tip card carries the meaning). It lives
/// and dies with the tour and never reaches `PresetsRepo`.
private struct TourSampleTile: View {
    var body: some View {
        TimerTile(preset: TutorialSample.preset, onStart: {}, onUnpin: {}, onPin: nil)
            .tutorialTarget(.presetTile)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - Add-timer FAB

/// The floating "New timer" action button — a 60pt accent circle pinned to the
/// bottom-centre of the Home screen (`.add-fab` in the handoff). Replaces the
/// old in-grid dashed add tile.
private struct AddTimerFAB: View {
    let action: () -> Void

    @ScaledMetric(relativeTo: .title) private var plusSize: CGFloat = 30

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: plusSize, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Circle().fill(Theme.accent))
                // 1px top inset highlight (`inset 0 1px 0 rgba(255,255,255,0.25)`).
                .overlay(
                    Circle().strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.25), .clear],
                                       startPoint: .top, endPoint: .center),
                        lineWidth: 1
                    )
                )
                .shadow(color: .black.opacity(0.5), radius: 14, y: 10)
                .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
        }
        .buttonStyle(FABPressStyle())
        .accessibilityLabel("Add timer")
        .accessibilityHint("Creates a new timer")
    }
}

/// Presses the FAB down to 0.95 scale, matching `.add-fab:active`.
private struct FABPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

// MARK: - Preview

/// Renders the home screen layout with the handoff's reference state
/// (one running "Rest Set" timer + the four built-in presets + add card)
/// using the real components, without the AlarmKit-backed view model.
private struct TimersPreviewHarness: View {
    /// Set true to render the coach-mark tour over the harness.
    var tour = false
    /// Set true to render the dynamic "To next hour" tile in the first cell.
    var nextHourPinned = false
    /// Set true to drop every preset, reproducing the all-unpinned grid the
    /// tour has to stand its own sample tile in.
    var emptyGrid = false
    @State private var showingTour = false
    @State private var homeSteps: [TutorialStep] = []

    private let columns = [
        GridItem(.flexible(), spacing: Theme.gridGap),
        GridItem(.flexible(), spacing: Theme.gridGap)
    ]

    private let running = RunningTimer(
        id: UUID(),
        presetID: TimerPreset.builtIns[1].id,
        name: TimerPreset.builtIns[1].name,
        startDate: Date().addingTimeInterval(-1),
        duration: TimerPreset.builtIns[1].duration
    )

    var body: some View {
        ZStack {
            Theme.screenBG.ignoresSafeArea()
            ScrollView {
                VStack(spacing: Theme.stackGap) {
                    RunningTimerRow(
                        timer: running,
                        now: Date(),
                        onPause: {}, onResume: {}, onCancel: {}
                    )
                    LazyVGrid(columns: columns, spacing: Theme.gridGap) {
                        if nextHourPinned {
                            NextHourTile(now: .now, onStart: {}, onUnpin: {})
                        }
                        ForEach(emptyGrid ? [] : TimerPreset.builtIns) { preset in
                            TimerTile(preset: preset, onStart: {}, onUnpin: {}, onPin: nil)
                                .tutorialTarget(.presetTile)
                        }
                        if showingTour && emptyGrid {
                            TourSampleTile()
                        }
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 6)
                .padding(.bottom, 96)
            }
        }
        .overlay(alignment: .bottom) {
            AddTimerFAB(action: {})
                .tutorialTarget(.addTile)
                .padding(.bottom, 34)
        }
        // Layout parity with the real screen — the puck only, since the harness
        // has no store to drive the menu's Pro entries.
        .overlay(alignment: .bottomTrailing) {
            if !showingTour {
                CornerChromeGlyph(systemName: "ellipsis")
                    .padding(.trailing, 20)
                    .padding(.bottom, 45)
            }
        }
        .coachMarks(.home, isActive: $showingTour, steps: homeSteps)
        .onAppear {
            homeSteps = TutorialTour.home
            showingTour = tour
        }
    }
}

#Preview {
    TimersPreviewHarness()
}

#Preview("Home tour") {
    TimersPreviewHarness(tour: true)
}

#Preview("To next hour pinned") {
    TimersPreviewHarness(nextHourPinned: true)
}

/// Every preset unpinned: the tour must still open on the tile tip, spotlighting
/// the sample tile it brings with it.
#Preview("Home tour · empty grid") {
    TimersPreviewHarness(tour: true, emptyGrid: true)
}
