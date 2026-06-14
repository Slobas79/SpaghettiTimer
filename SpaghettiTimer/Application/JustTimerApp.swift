//
//  SpaghettiTimerApp.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 30. 7. 2025..
//

import SwiftUI

@main
struct SpaghettiTimerApp: App {
    @State private var viewModel: TimersViewModel
    @Environment(\.scenePhase) private var scenePhase
    private let runningUseCase: RunningTimersUseCase

    init() {
        let container = DependencyInjectionContainer()
        runningUseCase = container.runningTimersUseCase
        _viewModel = State(initialValue: TimersViewModel(
            presetsUseCase: container.presetsUseCase,
            runningUseCase: container.runningTimersUseCase
        ))
    }

    var body: some Scene {
        WindowGroup {
            HomeView(viewModel: viewModel)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        runningUseCase.reconcileOnForeground()
                    }
                }
        }
    }
}
