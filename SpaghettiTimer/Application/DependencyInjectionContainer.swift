//
//  DependencyInjectionContainer.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 30. 7. 2025..
//

@MainActor
final class DependencyInjectionContainer {
    // Repos
    private lazy var presetsRepo: PresetsRepo = PresetsRepoImpl()
    private lazy var runningTimersRepo: RunningTimersRepo = RunningTimersRepoImpl()
    private(set) lazy var analyticsRepo: AnalyticsRepo = AnalyticsBootstrap.makeRepo()

    // Use cases
    private(set) lazy var presetsUseCase: TimerPresetsUseCase = TimerPresetsUseCaseImpl(repo: presetsRepo, analytics: analyticsRepo)
    private(set) lazy var runningTimersUseCase: RunningTimersUseCase = RunningTimersUseCaseImpl(repo: runningTimersRepo, presetsRepo: presetsRepo, analytics: analyticsRepo)
    private(set) lazy var storeUseCase: StoreUseCase = StoreUseCase(analytics: analyticsRepo)
}
