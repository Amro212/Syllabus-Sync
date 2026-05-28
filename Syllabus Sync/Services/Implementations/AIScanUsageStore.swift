//
//  AIScanUsageStore.swift
//  Syllabus Sync
//

import Foundation

@MainActor
final class AIScanUsageStore: ObservableObject {
    @Published private(set) var snapshot: AIScanUsageSnapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var isPurchasing = false
    @Published var lastErrorMessage: String?

    private let apiClient: APIClient
    private let purchaseManager: AppStorePurchasing
    private let isAuthenticatedProvider: @Sendable () -> Bool
    private let accessTokenProvider: @Sendable () async throws -> String
    private let encoder = JSONEncoder()
    private var didLoadOnce = false
    private var didProcessPendingTransactions = false
    private var processingTransactionIDs: Set<String> = []
    private var updatesTask: Task<Void, Never>?

    init(
        apiClient: APIClient,
        purchaseManager: AppStorePurchasing = AppStorePurchaseManager(),
        isAuthenticatedProvider: @escaping @Sendable () -> Bool = { SupabaseAuthService.shared.isAuthenticated },
        accessTokenProvider: @escaping @Sendable () async throws -> String = {
            try await SupabaseAuthService.shared.supabase.auth.session.accessToken
        }
    ) {
        self.apiClient = apiClient
        self.purchaseManager = purchaseManager
        self.isAuthenticatedProvider = isAuthenticatedProvider
        self.accessTokenProvider = accessTokenProvider
        updatesTask = purchaseManager.startListening(
            productIDs: [AIScanCommerceConfig.productID]
        ) { [weak self] record in
            _ = await self?.applyPurchasedRecord(record, exposeErrors: false)
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    var canStartScan: Bool {
        snapshot?.canScan ?? true
    }

    var currentProductID: String {
        snapshot?.productId ?? AIScanCommerceConfig.productID
    }

    func refresh(force: Bool = true) async {
        guard isAuthenticatedProvider() else {
            snapshot = nil
            didLoadOnce = false
            return
        }

        if !force, didLoadOnce {
            return
        }

        if !didProcessPendingTransactions {
            didProcessPendingTransactions = true
            await purchaseManager.consumeUnfinishedTransactions(productIDs: Set([AIScanCommerceConfig.productID])) { [weak self] record in
                _ = await self?.applyPurchasedRecord(record, exposeErrors: false)
            }
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let token = try await accessToken()
            var request = APIRequest(path: "/ai-usage", method: .get, headers: [:], body: nil, timeout: 30)
            request.headers["Authorization"] = "Bearer \(token)"

            let envelope: AIScanUsageEnvelope = try await apiClient.send(request, as: AIScanUsageEnvelope.self)
            snapshot = envelope.usage
            lastErrorMessage = nil
            didLoadOnce = true
        } catch {
            lastErrorMessage = friendlyMessage(for: error)
        }
    }

    func purchaseTopUp() async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        lastErrorMessage = nil

        do {
            let record = try await purchaseManager.purchase(productID: currentProductID)
            return await applyPurchasedRecord(record, exposeErrors: true)
        } catch {
            let message = friendlyMessage(for: error)
            if let message {
                lastErrorMessage = message
            }
            return false
        }
    }

    func syncPurchases() async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        lastErrorMessage = nil

        do {
            try await purchaseManager.sync()
            await purchaseManager.consumeUnfinishedTransactions(productIDs: Set([AIScanCommerceConfig.productID])) { [weak self] record in
                _ = await self?.applyPurchasedRecord(record, exposeErrors: false)
            }
            await refresh()
            return true
        } catch {
            let message = friendlyMessage(for: error)
            if let message {
                lastErrorMessage = message
            }
            return false
        }
    }

    private func applyPurchasedRecord(_ record: AppStorePurchaseRecord, exposeErrors: Bool) async -> Bool {
        guard !processingTransactionIDs.contains(record.transactionID) else { return true }
        processingTransactionIDs.insert(record.transactionID)
        defer { processingTransactionIDs.remove(record.transactionID) }

        do {
            let token = try await accessToken()
            let payload = AIPurchaseCreditRequest(
                transactionId: record.transactionID,
                originalTransactionId: record.originalTransactionID,
                appTransactionId: record.appTransactionID,
                productId: record.productID,
                environment: record.environment,
                signedTransactionInfo: record.signedTransactionInfo
            )
            let body = try encoder.encode(payload)
            var request = APIRequest(path: "/iap/credit", method: .post, headers: [:], body: body, timeout: 30)
            request.headers["Authorization"] = "Bearer \(token)"
            request.headers["Content-Type"] = "application/json"

            let envelope: AIPurchaseCreditEnvelope = try await apiClient.send(request, as: AIPurchaseCreditEnvelope.self)
            snapshot = envelope.usage
            didLoadOnce = true
            lastErrorMessage = nil
            await record.finish()
            return true
        } catch {
            if exposeErrors, let message = friendlyMessage(for: error) {
                lastErrorMessage = message
            }
            return false
        }
    }

    private func accessToken() async throws -> String {
        try await accessTokenProvider()
    }

    private func friendlyMessage(for error: Error) -> String? {
        if let purchaseError = error as? AppStorePurchaseError {
            return purchaseError.errorDescription
        }

        if let parserError = error as? SyllabusParserError {
            return parserError.errorDescription
        }

        if let apiError = error as? APIClientError {
            switch apiError {
            case .invalidURL:
                return "Billing service is unavailable right now."
            case .requestFailed(let underlying):
                return underlying.localizedDescription
            case .timeout:
                return "Billing request timed out. Try again."
            case .decoding:
                return "Billing service returned an unexpected response."
            case .server(_, let message, _, _):
                return message ?? "Billing service returned an error."
            }
        }

        return error.localizedDescription
    }
}
