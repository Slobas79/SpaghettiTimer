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

    private let columns = [
        GridItem(.adaptive(minimum: 140), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 0.25)) { context in
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.tiles) { item in
                            TimerTile(
                                preset: item.preset,
                                runningTimers: viewModel.runningTimers(for: item.preset),
                                now: context.date,
                                onStart: { viewModel.start(item.preset) },
                                onStop: { viewModel.stopOldest(for: item.preset) },
                                onUnpin: item.isPinned ? { viewModel.deletePreset(item.preset) } : nil,
                                onPin: item.isPinned ? nil : { viewModel.pin(item.preset) },
                                onPause: { viewModel.pauseOldest(for: item.preset) },
                                onResume: { viewModel.resumeOldest(for: item.preset) }
                            )
                        }
                        AddTimerTile(action: { showingNew = true })
                    }
                    .padding(16)
                }
            }
            .sheet(isPresented: $showingNew) {
                NewTimerSheet { name, duration, pinned in
                    viewModel.createTimer(name: name, duration: duration, pinned: pinned)
                }
            }
            .onAppear { viewModel.refresh() }
        }
    }
}
