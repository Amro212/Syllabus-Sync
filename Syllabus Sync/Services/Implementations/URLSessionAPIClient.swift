//
//  URLSessionAPIClient.swift
//  Syllabus Sync
//

import Foundation

public protocol ClientIDProviding {
    var clientID: String { get }
}

private extension URLSessionAPIClient {
    static let primaryDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withFullTime, .withFractionalSeconds]
        // Don't set timeZone - let it parse the timezone from the string
        return formatter
    }()

    static let fallbackDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withFullTime]
        // Don't set timeZone - let it parse the timezone from the string
        return formatter
    }()

    static let localISOWithMillis = try! NSRegularExpression(pattern: "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{3}$")
    static let localISONoMillis = try! NSRegularExpression(pattern: "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}$")
    static let isoDateOnly = try! NSRegularExpression(pattern: "^\\d{4}-\\d{2}-\\d{2}$")

    static let localFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        return formatter
    }()

    static func normalizeISOIfNeeded(_ string: String) -> String {
        return string
    }
}

public final class DefaultClientIDProvider: ClientIDProviding {
    static let shared = DefaultClientIDProvider()

    public let clientID: String

    private init() {
        let defaults = UserDefaults.standard
        let key = "com.syllabussync.client-id"
        if let existing = defaults.string(forKey: key) {
            clientID = existing
        } else {
            let generated = UUID().uuidString
            defaults.set(generated, forKey: key)
            clientID = generated
        }
    }
}

/// Concrete API client backed by URLSession.
final class URLSessionAPIClient: APIClient {
    struct Configuration {
        let baseURL: URL
        var defaultHeaders: [String: String]
        var requestTimeout: TimeInterval
        var maxRetryCount: Int

        init(baseURL: URL,
             defaultHeaders: [String: String] = [:],
             requestTimeout: TimeInterval = 30,
             maxRetryCount: Int = 1) {
            self.baseURL = baseURL
            self.defaultHeaders = defaultHeaders
            self.requestTimeout = requestTimeout
            self.maxRetryCount = max(0, maxRetryCount)
        }
    }

    private let configuration: Configuration
    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    private let clientIDProvider: ClientIDProviding

    public init(configuration: Configuration,
         session: URLSession? = nil,
         clientIDProvider: ClientIDProviding = DefaultClientIDProvider.shared) {
        self.configuration = configuration
        self.clientIDProvider = clientIDProvider

        let urlSession: URLSession
        if let session {
            urlSession = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = configuration.requestTimeout
            config.timeoutIntervalForResource = configuration.requestTimeout
            config.waitsForConnectivity = true
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            urlSession = URLSession(configuration: config)
        }
        self.session = urlSession

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let normalized = Self.normalizeISOIfNeeded(string)
            let range = NSRange(location: 0, length: normalized.utf16.count)

            if Self.localISOWithMillis.firstMatch(in: normalized, options: [], range: range) != nil {
                if let date = Self.localFormatter.date(from: normalized) {
                    return date
                }
            }

            if Self.localISONoMillis.firstMatch(in: normalized, options: [], range: range) != nil {
                let augmented = normalized + ".000"
                if let date = Self.localFormatter.date(from: augmented) {
                    return date
                }
            }

            if Self.isoDateOnly.firstMatch(in: normalized, options: [], range: range) != nil {
                let augmented = normalized + "T00:00:00.000"
                if let date = Self.localFormatter.date(from: augmented) {
                    return date
                }
            }

            if let date = Self.primaryDateFormatter.date(from: normalized) {
                return date
            }
            if let fallback = Self.fallbackDateFormatter.date(from: normalized) {
                return fallback
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date string: \(string)")
        }
        jsonDecoder = decoder

    }

    func send<T>(_ request: APIRequest, as type: T.Type) async throws -> T where T: Decodable {
        guard let endpoint = URL(string: request.path, relativeTo: configuration.baseURL)?.absoluteURL else {
            throw APIClientError.invalidURL
        }

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        urlRequest.timeoutInterval = request.timeout ?? configuration.requestTimeout

        var headers = configuration.defaultHeaders
        headers["Content-Type"] = headers["Content-Type"] ?? "application/json"
        headers["Accept"] = headers["Accept"] ?? "application/json"
        headers["x-client-id"] = clientIDProvider.clientID
        for (key, value) in request.headers { headers[key] = value }
        for (key, value) in headers { urlRequest.setValue(value, forHTTPHeaderField: key) }

        let attempts = configuration.maxRetryCount + 1

        var lastError: Error?
        for attempt in 0..<attempts {
            do {
                let (data, response) = try await session.data(for: urlRequest)
                guard let http = response as? HTTPURLResponse else {
                    throw APIClientError.requestFailed(underlying: URLError(.badServerResponse))
                }

                switch http.statusCode {
                case 200..<300:
                    do {
                        return try jsonDecoder.decode(T.self, from: data)
                    } catch {
                        throw APIClientError.decoding
                    }
                case 401:
                    let message = try decodeServerMessage(from: data)
                    throw APIClientError.server(status: http.statusCode, message: message, retryAfter: nil)
                case 408, 500..<600:
                    let message = try decodeServerMessage(from: data)
                    if attempt < attempts - 1 {
                        lastError = APIClientError.server(status: http.statusCode, message: message, retryAfter: parseRetryAfter(from: http))
                        try await Task.sleep(nanoseconds: UInt64(0.8 * 1_000_000_000))
                        continue
                    }
                    throw APIClientError.server(status: http.statusCode, message: message, retryAfter: parseRetryAfter(from: http))
                case 429:
                    let message = try decodeServerMessage(from: data)
                    throw APIClientError.server(status: http.statusCode, message: message, retryAfter: parseRetryAfter(from: http))
                default:
                    let message = try decodeServerMessage(from: data)
                    throw APIClientError.server(status: http.statusCode, message: message, retryAfter: parseRetryAfter(from: http))
                }
            } catch {
                if let apiError = error as? APIClientError {
                    if case .server = apiError, attempt < attempts - 1 {
                        lastError = apiError
                        continue
                    }
                    throw apiError
                }

                if let urlError = error as? URLError {
                    if urlError.code == .timedOut {
                        if attempt < attempts - 1 {
                            lastError = APIClientError.timeout
                            continue
                        } else {
                            throw APIClientError.timeout
                        }
                    }
                    if attempt < attempts - 1 && shouldRetry(urlError: urlError) {
                        lastError = urlError
                        try await Task.sleep(nanoseconds: UInt64(0.5 * 1_000_000_000))
                        continue
                    }
                    throw APIClientError.requestFailed(underlying: urlError)
                }

                throw APIClientError.requestFailed(underlying: error)
            }
        }

        if let lastError = lastError {
            if let apiError = lastError as? APIClientError {
                throw apiError
            }
            throw APIClientError.requestFailed(underlying: lastError)
        }

        throw APIClientError.requestFailed(underlying: URLError(.unknown))
    }
    
    func sendWithRawResponse<T>(_ request: APIRequest, as type: T.Type) async throws -> (T, String) where T: Decodable {
        guard let endpoint = URL(string: request.path, relativeTo: configuration.baseURL)?.absoluteURL else {
            throw APIClientError.invalidURL
        }

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        urlRequest.timeoutInterval = request.timeout ?? configuration.requestTimeout

        var headers = configuration.defaultHeaders
        headers["Content-Type"] = headers["Content-Type"] ?? "application/json"
        headers["Accept"] = headers["Accept"] ?? "application/json"
        headers["x-client-id"] = clientIDProvider.clientID
        for (key, value) in request.headers { headers[key] = value }
        for (key, value) in headers { urlRequest.setValue(value, forHTTPHeaderField: key) }

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.requestFailed(underlying: URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 200..<300:
            let rawString = String(data: data, encoding: .utf8) ?? "<binary data>"
            do {
                let decoded = try jsonDecoder.decode(T.self, from: data)
                return (decoded, rawString)
            } catch {
                throw APIClientError.decoding
            }
        case 401:
            let message = try decodeServerMessage(from: data)
            throw APIClientError.server(status: http.statusCode, message: message, retryAfter: nil)
        default:
            let message = try decodeServerMessage(from: data)
            throw APIClientError.server(status: http.statusCode, message: message, retryAfter: parseRetryAfter(from: http))
        }
    }

    private func decodeServerMessage(from data: Data) throws -> String? {
        guard !data.isEmpty else { return nil }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = json["error"] as? String {
                return message
            }
            if let message = json["message"] as? String {
                return message
            }
        }
        return nil
    }

    private func parseRetryAfter(from response: HTTPURLResponse) -> Int? {
        guard let header = response.value(forHTTPHeaderField: "Retry-After"), let value = Int(header) else {
            return nil
        }
        return value
    }

    private func shouldRetry(urlError: URLError) -> Bool {
        switch urlError.code {
        case .networkConnectionLost, .notConnectedToInternet, .timedOut, .cannotConnectToHost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }
}
