//
//  AppConfiguration.swift
//  Syllabus Sync
//

import Foundation

enum AppConfiguration {
    static var apiBaseURL: URL? {
        if let env = ProcessInfo.processInfo.environment["API_BASE_URL"],
           !env.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let url = URL(string: env) {
            return url
        }

        if let configured = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           !configured.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !configured.contains("YOUR_"),
           let url = URL(string: configured) {
            return url
        }

        #if DEBUG
        return URL(string: "http://localhost:8787")
        #else
        return nil
        #endif
    }

    static func makeAPIClient(requestTimeout: TimeInterval, maxRetryCount: Int) -> APIClient {
        guard let baseURL = apiBaseURL else {
            return UnavailableAPIClient()
        }

        return URLSessionAPIClient(configuration: .init(
            baseURL: baseURL,
            defaultHeaders: ["Content-Type": "application/json"],
            requestTimeout: requestTimeout,
            maxRetryCount: maxRetryCount
        ))
    }
}

struct UnavailableAPIClient: APIClient {
    func send<T>(_ request: APIRequest, as type: T.Type) async throws -> T where T: Decodable {
        throw APIClientError.invalidURL
    }

    func sendWithRawResponse<T>(_ request: APIRequest, as type: T.Type) async throws -> (T, String) where T: Decodable {
        throw APIClientError.invalidURL
    }
}
