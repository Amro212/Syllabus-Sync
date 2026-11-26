//
//  AIScanUsageStore.swift
//  Syllabus Sync
//

import Foundation

@MainActor
final class AIScanUsageStore: ObservableObject {
    @Published private(set) var snapshot: AIScanUsageSnapshot?
    @Published private(set) var displayPrice: String?
    @Published private(set) var isLoadingProduct = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var lastErrorMessage: String?

    private let apiClient: APIClient
    private let purchaseManager: AppStorePurchasing
    private let accountIDProvider: @Sendable () -> UUID?
    private let accessTokenProvider: @Sendable () async throws -> String
    private var loadedAccountID: UUID?
    private var recoveredAccountID: UUID?
    private var refreshingAccountID: UUID?
    private var balanceRevision = 0
    private var creditTasks: [String: Task<Void, Error>] = [:]
    private var updatesTask: Task<Void, Never>?

    init(
        apiClient: APIClient,
        purchaseManager: AppStorePurchasing = AppStorePurchaseManager(),
        accountIDProvider: @escaping @Sendable () -> UUID? = {
            SupabaseAuthService.shared.currentUser.flatMap { UUID(uuidString: $0.id) }
        },
        accessTokenProvider: @escaping @Sendable () async throws -> String = {
            try await SupabaseAuthService.shared.supabase.auth.session.accessToken
        }
    ) {
        self.apiClient = apiClient
        self.purchaseManager = purchaseManager
        self.accountIDProvider = accountIDProvider
        self.accessTokenProvider = accessTokenProvider
        updatesTask = purchaseManager.startListening(
            productIDs: [AIScanCommerceConfig.productID]
        ) { [weak self] record in
            try? await self?.creditPurchase(record)
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    var canStartScan: Bool {
        snapshot?.canScan ?? true
    }

    var canPurchase: Bool {
        displayPrice != nil && snapshot?.productId == AIScanCommerceConfig.productID
    }

    func loadProduct() async {
        guard displayPrice == nil, !isLoadingProduct else { return }
        isLoadingProduct = true
        defer { isLoadingProduct = false }

        do {
            displayPrice = try await purchaseManager.displayPrice(productID: AIScanCommerceConfig.productID)
        } catch {
            displayPrice = nil
        }
    }

    func refresh(force: Bool = true) async {
        let accountID = accountIDProvider()
        if loadedAccountID != accountID {
            snapshot = nil
            lastErrorMessage = nil
            loadedAccountID = accountID
        }
        guard let accountID else {
            recoveredAccountID = nil
            return
        }
        guard refreshingAccountID != accountID, force || snapshot == nil || recoveredAccountID != accountID else { return }

        refreshingAccountID = accountID
        defer {
            if refreshingAccountID == accountID { refreshingAccountID = nil }
        }

        if recoveredAccountID != accountID {
            do {
                try await recoverPurchases()
                if accountIDProvider() == accountID { recoveredAccountID = accountID }
            } catch {
                // Keep the transaction unfinished so a later refresh or manual sync can retry it.
            }
        }

        do {
            try await loadBalance(for: accountID)
        } catch {
            if accountIDProvider() == accountID { lastErrorMessage = friendlyMessage(for: error) }
        }
    }

    func purchaseTopUp() async -> Bool {
        guard !isPurchasing, let accountID = accountIDProvider() else { return false }
        isPurchasing = true
        defer { isPurchasing = false }
        lastErrorMessage = nil

        do {
            let record = try await purchaseManager.purchase(
                productID: AIScanCommerceConfig.productID,
                accountID: accountID
            )
            try await creditPurchase(record)
            return true
        } catch {
            if accountIDProvider() == accountID { lastErrorMessage = friendlyMessage(for: error) }
            return false
        }
    }

    func syncPurchases() async -> Bool {
        guard !isPurchasing, let accountID = accountIDProvider() else { return false }
        isPurchasing = true
        defer { isPurchasing = false }
        lastErrorMessage = nil

        do {
            try await purchaseManager.sync()
            try await recoverPurchases()
            try await loadBalance(for: accountID)
            return accountIDProvider() == accountID
        } catch {
            if accountIDProvider() == accountID { lastErrorMessage = friendlyMessage(for: error) }
            return false
        }
    }

    private func recoverPurchases() async throws {
        let accountID = accountIDProvider()
        let records = await purchaseManager.unfinishedTransactions(productIDs: [AIScanCommerceConfig.productID])
        var recoveryError: Error?
        for record in records where record.accountID == nil || record.accountID == accountID {
            guard accountIDProvider() == accountID else { return }
            do {
                try await creditPurchase(record)
            } catch {
                recoveryError = error
            }
        }
        if let recoveryError { throw recoveryError }
    }

    private func loadBalance(for accountID: UUID) async throws {
        let revision = balanceRevision
        let token = try await accessTokenProvider()
        guard accountIDProvider() == accountID else { return }
        let request = APIRequest(path: "/ai-usage", method: .get, headers: ["Authorization": "Bearer \(token)"], body: nil, timeout: 30)
        let envelope: AIScanUsageEnvelope = try await apiClient.send(request, as: AIScanUsageEnvelope.self)

        guard accountIDProvider() == accountID, revision == balanceRevision else { return }
        loadedAccountID = accountID
        snapshot = envelope.usage
        lastErrorMessage = nil
    }

    private func creditPurchase(_ record: AppStorePurchaseRecord) async throws {
        if let existingTask = creditTasks[record.transactionID] {
            return try await existingTask.value
        }
        guard let accountID = accountIDProvider(), record.accountID == nil || record.accountID == accountID else {
            throw AppStorePurchaseError.accountChanged
        }

        let task = Task {
            let token = try await accessTokenProvider()
            guard accountIDProvider() == accountID else { throw AppStorePurchaseError.accountChanged }
            let payload = AIPurchaseCreditRequest(
                transactionId: record.transactionID,
                originalTransactionId: record.originalTransactionID,
                appTransactionId: record.appTransactionID,
                productId: record.productID,
                environment: record.environment,
                signedTransactionInfo: record.signedTransactionInfo
            )
            let request = APIRequest(
                path: "/iap/credit", method: .post,
                headers: ["Authorization": "Bearer \(token)", "Content-Type": "application/json"],
                body: try JSONEncoder().encode(payload), timeout: 30
            )
            let envelope: AIPurchaseCreditEnvelope
            do {
                envelope = try await apiClient.send(request, as: AIPurchaseCreditEnvelope.self)
            } catch {
                throw AppStorePurchaseError.creditPending
            }
            if accountIDProvider() == accountID {
                balanceRevision += 1
                loadedAccountID = accountID
                snapshot = envelope.usage
                lastErrorMessage = nil
            }
            await record.finish()
        }
        creditTasks[record.transactionID] = task
        defer { creditTasks[record.transactionID] = nil }
        try await task.value
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
