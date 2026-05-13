//
//  DiscRepo.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 30. 7. 2025..
//

import Foundation
import SwiftUI

protocol DiscRepo {
    var example: Bool { get set }
}

final class DiscRepoImpl: DiscRepo {
    @AppStorage("example") var example = false
}
