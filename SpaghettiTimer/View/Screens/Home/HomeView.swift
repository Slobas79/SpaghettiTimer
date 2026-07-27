//
//  HomeView.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 15. 8. 2025..
//

import SwiftUI

struct HomeView: View {
    let viewModel: TimersViewModel
    let store: StoreUseCase

    var body: some View {
        TimersView(viewModel: viewModel, store: store)
    }
}
