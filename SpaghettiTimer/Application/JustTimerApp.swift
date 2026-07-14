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
    private let analyticsRepo: AnalyticsRepo

    init() {
        AnalyticsBootstrap.configure()
        let container = DependencyInjectionContainer()
        runningUseCase = container.runningTimersUseCase
        analyticsRepo = container.analyticsRepo
        _viewModel = State(initialValue: TimersViewModel(
            presetsUseCase: container.presetsUseCase,
            runningUseCase: container.runningTimersUseCase
        ))
        // Deliver events queued by widget / Live Activity intents while the app
        // was not running.
        AnalyticsBootstrap.flushPending(into: container.analyticsRepo)
    }

    var body: some Scene {
        WindowGroup {
            HomeView(viewModel: viewModel)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        runningUseCase.reconcileOnForeground()
                        AnalyticsBootstrap.flushPending(into: analyticsRepo)
                    }
                }
        }
    }
}
