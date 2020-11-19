//
//  NetworkDispatcher.swift
//  
//
//  Created by Daniel Bernal on 15/11/20.
//

import Combine
import Foundation

enum FNNetworkRequestError: LocalizedError, Equatable {
    case invalidRequest
    case badRequest
    case unauthorized
    case forbidden
    case notFound
    case error4xx(_ code: Int)
    case serverError
    case error5xx(_ code: Int)
    case decodingError
    case urlSessionFailed(_ error: URLError)
    case unknownError
}

struct FNNetworkDispatcher {
        
    let urlSession: URLSession!
    
    init(urlSession: URLSession = URLSession.shared) {
        self.urlSession = urlSession
    }
    
    func dispatch<ReturnType: Codable>(request: URLRequest) -> AnyPublisher<ReturnType, FNNetworkRequestError> {
        
        return urlSession
            .dataTaskPublisher(for: request)
            .tryMap({ data, response in
                if let response = response as? HTTPURLResponse,
                 !(200...299).contains(response.statusCode) {
                    throw httpError(response.statusCode)
                }
                return data
            })
            .decode(type: ReturnType.self, decoder: JSONDecoder())
            .mapError { error in
               handleError(error: error)
            }
            .eraseToAnyPublisher()
    }
    
    // Common HTTP errors -> Handling
    private func httpError(_ statusCode: Int) -> FNNetworkRequestError {
        switch statusCode {
            case 400: return .badRequest
            case 401: return .unauthorized
            case 403: return .forbidden
            case 404: return .notFound
            case 402, 405...499: return .error4xx(statusCode)
            case 500: return .serverError
            case 501...599: return .error5xx(statusCode)
            default: return .unknownError
        }
    }
    
    // Decoding & General Errors
    private func handleError(error: Error) -> FNNetworkRequestError {
        switch error {
        case is Swift.DecodingError:
            return .decodingError
        case let urlError as URLError:
            return .urlSessionFailed(urlError)
        case let error as FNNetworkRequestError:
            return error
        default:
            return .unknownError
        }
    }
    
}
