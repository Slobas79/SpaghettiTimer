//
//  TimerActivityAttributes.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 23. 4. 2026..
//

import AlarmKit
import Foundation

nonisolated struct SpaghettiTimerMetadata: AlarmMetadata {
    let presetName: String
    let alarmID: String
}
