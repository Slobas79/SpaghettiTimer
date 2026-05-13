//
//  SpaghettiTimerWidgetBundle.swift
//  SpaghettiTimerWidget
//
//  Created by Slobodan Stamenic on 5. 5. 2026..
//

import WidgetKit
import SwiftUI

@main
struct SpaghettiTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        PresetsWidget()
        TimerLiveActivity()
    }
}
