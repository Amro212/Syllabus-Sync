//
//  APIClient.swift
//  Syllabus Sync
//

import Foundation

/// Represents an HTTP request sent via the API client.
struct APIRequest {
    enum Method: String {
        case get = "GET"
        case post = "POST"
    }

    let path: String
    let method: Method
    var headers: [String: String]
    var body: Data?
    var timeout: TimeInterval?

    init(path: String, method: Method = .get, headers: [String: String] = [:], body: Data? = nil, timeout: TimeInterval? = nil) {
        self.path = path
        self.method = method
        self.headers = headers
        self.body = body
        self.timeout = timeout
    }
}

/// Abstraction over URLSession to make the app's networking testable.
protocol APIClient {
    func send<T: Decodable>(_ request: APIRequest, as type: T.Type) async throws -> T
}

/// Errors thrown by the APIClient.
enum APIClientError: LocalizedError {
    case invalidURL
    case requestFailed(underlying: Error)
    case timeout
    case decoding
    case server(status: Int, message: String?, retryAfter: Int?)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The server URL is invalid."
        case .requestFailed(let underlying):
            return underlying.localizedDescription
        case .timeout:
            return "The request timed out."
        case .decoding:
            return "Received an unexpected response from the server."
        case .server(let status, let message, _):
            if let message, !message.isEmpty {
                return message
            }
            return "Server responded with status code \(status)."
        }
    }
}
