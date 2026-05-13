//
//  NetworkingError.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 15. 8. 2025..
//

enum NetworkingError: Error {
    case invalidURL
    case invalidResponse
    case requestFailed(statusCode: Int)
    case deserializationError
    case unknownError
}
