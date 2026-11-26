//
//  AppConfiguration.swift
//  Syllabus Sync
//

import Foundation

enum AppConfiguration {
    static var apiBaseURL: URL? {
        #if DEBUG
        if let url = validatedURL(ProcessInfo.processInfo.environment["API_BASE_URL"], schemes: ["http", "https"]) {
            return url
        }
        #endif

        let configured = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
        if let url = validatedURL(configured, schemes: ["https"]) {
            return url
        }

        #if DEBUG
        return URL(string: "http://localhost:8787")
        #else
        return nil
        #endif
    }

    private static func validatedURL(_ value: String?, schemes: Set<String>) -> URL? {
        guard let value,
              let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(), schemes.contains(scheme),
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil else { return nil }
        return url
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
