//
//  WKNetworkDispatcher.swift
//  
//
//  Created by Daniel Bernal on 15/11/20.
//


import Combine
import Foundation

public enum WKNetworkRequestError: LocalizedError, Equatable {
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

public struct WKNetworkDispatcher {
        
    let urlSession: URLSession!
    
    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }
    
    /// Dispatches an URLRequest and returns a publisher
    /// - Parameter request: URLRequest
    /// - Returns: A publisher with the provided decoded data or an error
    public func dispatch<ReturnType: Codable>(request: URLRequest, decoder: JSONDecoder?) -> AnyPublisher<ReturnType, WKNetworkRequestError> {

        let decoder = decoder ?? JSONDecoder()

        return urlSession
            .dataTaskPublisher(for: request)
            .tryMap({ data, response in
                if let response = response as? HTTPURLResponse,
                 !(200...299).contains(response.statusCode) {
                    throw httpError(response.statusCode)
                }
                return data
            })
            .decode(type: ReturnType.self, decoder: decoder)
            .mapError { error in
               handleError(error)
            }
            .eraseToAnyPublisher()
    }
    
    
    /// Parses a HTTP StatusCode and returns a proper error
    /// - Parameter statusCode: HTTP status code
    /// - Returns: Mapped Error
    private func httpError(_ statusCode: Int) -> WKNetworkRequestError {
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
    
    
    /// Parses URLSession Publisher errors and return proper ones
    /// - Parameter error: URLSession publisher error
    /// - Returns: Readable NWKNetworkRequestError
    private func handleError(_ error: Error) -> WKNetworkRequestError {
        print(error)
        switch error {
        case is Swift.DecodingError:
            return .decodingError
        case let urlError as URLError:
            return .urlSessionFailed(urlError)
        case let error as WKNetworkRequestError:
            return error
        default:
            return .unknownError
        }
    }
    
    private func debugMessage(_ message: String) {
        #if DEBUG
            print("--- WK Request \(message)")
        #endif
    }
    
}
