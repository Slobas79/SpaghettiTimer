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
    @State private var store: StoreUseCase
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
        let store = container.storeUseCase
        store.start()
        _store = State(initialValue: store)
        // Deliver events queued by widget / Live Activity intents while the app
        // was not running.
        AnalyticsBootstrap.flushPending(into: container.analyticsRepo)
    }

    var body: some Scene {
        WindowGroup {
            HomeView(viewModel: viewModel, store: store)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        runningUseCase.reconcileOnForeground()
                        AnalyticsBootstrap.flushPending(into: analyticsRepo)
                        // Re-sync entitlements in case a purchase happened on
                        // another device or the sheet was closed mid-flow.
                        Task { await store.refreshEntitlements() }
                    }
                }
        }
    }
}
