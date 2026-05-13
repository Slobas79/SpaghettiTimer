//
//  RequestConvertible.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 15. 8. 2025..
//

import Foundation

protocol RequestConvertible {
    func toURLRequest() throws -> URLRequest
}
