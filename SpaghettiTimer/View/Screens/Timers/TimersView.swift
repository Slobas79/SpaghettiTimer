//
//  TimersView.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 23. 4. 2026..
//

import SwiftUI

struct TimersView: View {
    @State var viewModel: TimersViewModel
    let store: StoreUseCase
    @State private var showingNew = false
    @State private var showingSplash = false
    @State private var showingTour = false
    @State private var directPaywall: PaywallTrigger?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = [
        GridItem(.flexible(), spacing: Theme.gridGap),
        GridItem(.flexible(), spacing: Theme.gridGap)
    ]

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
                                        onCancel: { viewModel.stop(timer) }
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
                                    onUnpin: { viewModel.setNextHourPinned(false) }
                                )
                            }

                            ForEach(viewModel.presetTiles) { item in
                                TimerTile(
                                    preset: item.preset,
                                    onStart: { viewModel.start(item.preset) },
                                    onUnpin: { viewModel.deletePreset(item.preset) },
                                    onPin: nil
                                )
                                .tutorialTarget(.presetTile)
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
        // spotlight it through the scrim's cutout. A quiet long-press replays
        // the tips (the one-shot Help button is gone once the tour is done).
        .overlay(alignment: .bottom) {
            AddTimerFAB(action: { showingNew = true })
                .tutorialTarget(.addTile)
                .padding(.bottom, 34)
                .contextMenu {
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
        }
        // One-shot Help trigger in the bottom-right corner: starts the Home
        // tour on demand and is gone for good once the tour is finished or
        // skipped. Clear of the running banner (top) and the centre FAB.
        // Beneath the coach-mark/splash overlays so the tour scrim covers it.
        .overlay(alignment: .bottomTrailing) {
            if !showingSplash && !showingTour && !TutorialFlags.isDone(.home) {
                TutorialHelpButton(style: .corner) {
                    showingTour = true
                }
                .padding(.trailing, 20)
                .padding(.bottom, 45)
            }
        }
        .coachMarks(.home, isActive: $showingTour, steps: TutorialTour.home)
        .overlay {
            if showingSplash {
                // "Skip intro" skips only the splash — the Home tour stays
                // available behind the Help button either way.
                TutorialSplash(
                    onFinish: {
                        showingSplash = false
                        TutorialFlags.markDone(.splash)
                    },
                    onSkip: {
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
        .onAppear {
            viewModel.refresh()
            // First app run only: play the intro splash, then land on the
            // normal Home screen (with the Help button). The splash never
            // consumes the Home tour — that's the Help button's job.
            if !TutorialFlags.isDone(.splash) {
                showingSplash = true
            }
        }
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
/// (one running "5 min" timer + the four built-in presets + add card)
/// using the real components, without the AlarmKit-backed view model.
private struct TimersPreviewHarness: View {
    /// Set true to render the coach-mark tour over the harness.
    var tour = false
    /// Set true to render the dynamic "To next hour" tile in the first cell.
    var nextHourPinned = false
    @State private var showingTour = false

    private let columns = [
        GridItem(.flexible(), spacing: Theme.gridGap),
        GridItem(.flexible(), spacing: Theme.gridGap)
    ]

    private let running = RunningTimer(
        id: UUID(),
        presetID: TimerPreset.builtIns[1].id,
        name: "5 min",
        startDate: Date().addingTimeInterval(-1),
        duration: 300
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
                        ForEach(TimerPreset.builtIns) { preset in
                            TimerTile(preset: preset, onStart: {}, onUnpin: {}, onPin: nil)
                                .tutorialTarget(.presetTile)
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
        .coachMarks(.home, isActive: $showingTour, steps: TutorialTour.home)
        .onAppear { showingTour = tour }
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
