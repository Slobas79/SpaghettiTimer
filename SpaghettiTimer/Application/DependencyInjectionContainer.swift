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

    // Use cases
    private(set) lazy var presetsUseCase: TimerPresetsUseCase = TimerPresetsUseCaseImpl(repo: presetsRepo)
    private(set) lazy var runningTimersUseCase: RunningTimersUseCase = RunningTimersUseCaseImpl(repo: runningTimersRepo)
}
