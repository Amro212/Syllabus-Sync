//
//  AppStorePurchaseManager.swift
//  Syllabus Sync
//

import Foundation
import StoreKit

struct AppStorePurchaseRecord: Sendable {
    let transactionID: String
    let originalTransactionID: String
    let appTransactionID: String?
    let productID: String
    let environment: String
    let signedTransactionInfo: String
    private let finishHandler: @Sendable () async -> Void

    init(
        transactionID: String,
        originalTransactionID: String,
        appTransactionID: String?,
        productID: String,
        environment: String,
        signedTransactionInfo: String,
        finishHandler: @escaping @Sendable () async -> Void
    ) {
        self.transactionID = transactionID
        self.originalTransactionID = originalTransactionID
        self.appTransactionID = appTransactionID
        self.productID = productID
        self.environment = environment
        self.signedTransactionInfo = signedTransactionInfo
        self.finishHandler = finishHandler
    }

    func finish() async {
        await finishHandler()
    }
}

enum AppStorePurchaseError: LocalizedError {
    case productUnavailable
    case cancelled
    case pending
    case unverified

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return "AI scan top-up is unavailable right now."
        case .cancelled:
            return nil
        case .pending:
            return "Purchase is pending approval."
        case .unverified:
            return "StoreKit could not verify this purchase."
        }
    }
}

protocol AppStorePurchasing {
    func purchase(productID: String) async throws -> AppStorePurchaseRecord
    func sync() async throws
    func consumeUnfinishedTransactions(
        productIDs: Set<String>,
        handler: @escaping @Sendable (AppStorePurchaseRecord) async -> Void
    ) async
    func startListening(
        productIDs: Set<String>,
        handler: @escaping @Sendable (AppStorePurchaseRecord) async -> Void
    ) -> Task<Void, Never>
}

struct AppStorePurchaseManager: AppStorePurchasing {
    func purchase(productID: String) async throws -> AppStorePurchaseRecord {
        let products = try await Product.products(for: [productID])
        guard let product = products.first else {
            throw AppStorePurchaseError.productUnavailable
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            return try makeRecord(from: verification)
        case .userCancelled:
            throw AppStorePurchaseError.cancelled
        case .pending:
            throw AppStorePurchaseError.pending
        @unknown default:
            throw AppStorePurchaseError.productUnavailable
        }
    }

    func sync() async throws {
        try await AppStore.sync()
    }

    func consumeUnfinishedTransactions(
        productIDs: Set<String>,
        handler: @escaping @Sendable (AppStorePurchaseRecord) async -> Void
    ) async {
        for await verification in Transaction.unfinished {
            guard case .verified(let transaction) = verification else { continue }
            guard productIDs.contains(transaction.productID) else { continue }
            await handler(makeRecord(from: transaction))
        }
    }

    func startListening(
        productIDs: Set<String>,
        handler: @escaping @Sendable (AppStorePurchaseRecord) async -> Void
    ) -> Task<Void, Never> {
        Task.detached {
            for await verification in Transaction.updates {
                guard case .verified(let transaction) = verification else { continue }
                guard productIDs.contains(transaction.productID) else { continue }
                await handler(makeRecord(from: transaction))
            }
        }
    }

    private func makeRecord(from verification: VerificationResult<Transaction>) throws -> AppStorePurchaseRecord {
        switch verification {
        case .verified(let transaction):
            return makeRecord(from: transaction)
        case .unverified:
            throw AppStorePurchaseError.unverified
        }
    }

    private func makeRecord(from transaction: Transaction) -> AppStorePurchaseRecord {
        AppStorePurchaseRecord(
            transactionID: String(transaction.id),
            originalTransactionID: String(transaction.originalID),
            appTransactionID: transaction.appTransactionID,
            productID: transaction.productID,
            environment: environmentString(for: transaction.environment),
            signedTransactionInfo: String(data: transaction.jsonRepresentation, encoding: .utf8) ?? "",
            finishHandler: {
                await transaction.finish()
            }
        )
    }

    private func environmentString(for environment: AppStore.Environment) -> String {
        if environment == .sandbox {
            return "sandbox"
        }
        if environment == .xcode {
            return "xcode"
        }
        return "production"
    }
}
