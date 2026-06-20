//
//  TimersView.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 23. 4. 2026..
//

import SwiftUI

struct TimersView: View {
    @State var viewModel: TimersViewModel
    @State private var showingNew = false

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
                            ForEach(viewModel.presetTiles) { item in
                                TimerTile(
                                    preset: item.preset,
                                    onStart: { viewModel.start(item.preset) },
                                    onUnpin: { viewModel.deletePreset(item.preset) },
                                    onPin: nil
                                )
                            }
                            AddTimerTile(action: { showingNew = true })
                        }
                    }
                    // Cap text growth on the fixed-aspect tiles / fixed-height
                    // rows so very large Dynamic Type sizes can't break the layout.
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.top, 6)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: viewModel.runningRows)
                }
            }
        }
        .sheet(isPresented: $showingNew) {
            NewTimerSheet { name, duration, pinned, autoRestartDelaySeconds in
                viewModel.createTimer(name: name, duration: duration, pinned: pinned, autoRestartDelaySeconds: autoRestartDelaySeconds)
            }
            .presentationBackground(.black)
            .presentationDragIndicator(.hidden)
        }
        .onAppear { viewModel.refresh() }
    }
}

// MARK: - Preview

/// Renders the home screen layout with the handoff's reference state
/// (one running "5 min" timer + the four built-in presets + add card)
/// using the real components, without the AlarmKit-backed view model.
private struct TimersPreviewHarness: View {
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
                        ForEach(TimerPreset.builtIns) { preset in
                            TimerTile(preset: preset, onStart: {}, onUnpin: {}, onPin: nil)
                        }
                        AddTimerTile(action: {})
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 6)
            }
        }
    }
}

#Preview {
    TimersPreviewHarness()
}
