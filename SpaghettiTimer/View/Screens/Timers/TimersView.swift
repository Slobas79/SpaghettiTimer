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
    @State private var editingPreset: TimerPreset?

    private let columns = [
        GridItem(.adaptive(minimum: 140), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 0.25)) { context in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.runningRows) { timer in
                            RunningTimerRow(
                                timer: timer,
                                now: context.date,
                                onPause: { viewModel.pause(timer) },
                                onResume: { viewModel.resume(timer) },
                                onCancel: { viewModel.stop(timer) }
                            )
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(viewModel.presetTiles) { item in
                                TimerTile(
                                    preset: item.preset,
                                    onStart: { viewModel.start(item.preset) },
                                    onUnpin: { viewModel.deletePreset(item.preset) },
                                    onPin: nil,
                                    onEdit: { editingPreset = item.preset }
                                )
                            }
                            AddTimerTile(action: { showingNew = true })
                        }
                    }
                    .padding(16)
                    .animation(.easeInOut(duration: 0.25), value: viewModel.runningRows)
                }
            }
            .sheet(isPresented: $showingNew) {
                NewTimerSheet { name, duration, pinned in
                    viewModel.createTimer(name: name, duration: duration, pinned: pinned)
                }
            }
            .sheet(item: $editingPreset) { preset in
                NewTimerSheet(editing: preset) { name, duration, _ in
                    viewModel.updateTimer(preset, name: name, duration: duration)
                }
            }
            .onAppear { viewModel.refresh() }
        }
    }
}
