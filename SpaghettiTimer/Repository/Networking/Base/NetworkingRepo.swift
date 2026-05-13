//
//  NetworkingRepo.swift
//  SpaghettiTimer
//
//  Created by Slobodan Stamenic on 15. 8. 2025..
//

import Foundation
import Combine

protocol NetworkingRepo {
    func request<T: Decodable>(_ resultType: T.Type, endpoint: RequestConvertible) -> AnyPublisher<T, Error>
    func request<T: Decodable>(_ resultType: T.Type, endpoint: RequestConvertible) async throws -> T
}

extension NetworkingRepo {
    func validateResponse(data: Data, response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkingError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkingError.requestFailed(statusCode: httpResponse.statusCode)
        }
    }
}

final class NetworkingRepoImpl: NetworkingRepo {
    private let session: URLSession

    init(session: URLSession = URLSession.shared) {
        self.session = session
    }
    
    func request<T>(_ resultType: T.Type, endpoint: any RequestConvertible) -> AnyPublisher<T, any Error> where T : Decodable {
        do {
            let request = try endpoint.toURLRequest()

            return session.dataTaskPublisher(for: request)
                .tryMap {[weak self] element -> Data in
                    guard let self = self else { return Data() }

                    try self.validateResponse(data: element.data, response: element.response)

                    return element.data
                }
            
                .decode(type: resultType, decoder: JSONDecoder())
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    func request<T>(_ resultType: T.Type, endpoint: any RequestConvertible) async throws -> T where T : Decodable {
        let request = try endpoint.toURLRequest()
        let (data, response) = try await session.data(for: request)
        
        try validateResponse(data: data, response: response)
        
        let decoder = JSONDecoder()
        
        do {
            let instance = try decoder.decode(resultType, from: data)
            return instance
        } catch {
            throw NetworkingError.deserializationError
        }
    }
}
