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
    let accountID: UUID?
    let environment: String
    let signedTransactionInfo: String
    private let finishHandler: @Sendable () async -> Void

    init(
        transactionID: String,
        originalTransactionID: String,
        appTransactionID: String?,
        productID: String,
        accountID: UUID? = nil,
        environment: String,
        signedTransactionInfo: String,
        finishHandler: @escaping @Sendable () async -> Void
    ) {
        self.transactionID = transactionID
        self.originalTransactionID = originalTransactionID
        self.appTransactionID = appTransactionID
        self.productID = productID
        self.accountID = accountID
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
    case accountChanged
    case creditPending

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
        case .accountChanged:
            return "Sign in to the Syllabus Sync account used for this purchase."
        case .creditPending:
            return "Your purchase is awaiting credit. Tap Sync purchases to try again."
        }
    }
}

protocol AppStorePurchasing {
    func displayPrice(productID: String) async throws -> String
    func purchase(productID: String, accountID: UUID) async throws -> AppStorePurchaseRecord
    func sync() async throws
    func unfinishedTransactions(productIDs: Set<String>) async -> [AppStorePurchaseRecord]
    func startListening(
        productIDs: Set<String>,
        handler: @escaping @Sendable (AppStorePurchaseRecord) async -> Void
    ) -> Task<Void, Never>
}

struct AppStorePurchaseManager: AppStorePurchasing {
    func displayPrice(productID: String) async throws -> String {
        try await product(for: productID).displayPrice
    }

    func purchase(productID: String, accountID: UUID) async throws -> AppStorePurchaseRecord {
        let product = try await product(for: productID)
        let result = try await product.purchase(options: [.appAccountToken(accountID)])
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

    private func product(for productID: String) async throws -> Product {
        let products = try await Product.products(for: [productID])
        guard let product = products.first, product.type == .consumable else {
            throw AppStorePurchaseError.productUnavailable
        }
        return product
    }

    func unfinishedTransactions(productIDs: Set<String>) async -> [AppStorePurchaseRecord] {
        var records: [AppStorePurchaseRecord] = []
        for await verification in Transaction.unfinished {
            guard case .verified(let transaction) = verification else { continue }
            guard productIDs.contains(transaction.productID) else { continue }
            records.append(makeRecord(from: transaction))
        }
        return records
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
        let appTransactionID: String?
        if #available(iOS 18.4, *) {
            appTransactionID = transaction.appTransactionID
        } else {
            appTransactionID = nil
        }

        return AppStorePurchaseRecord(
            transactionID: String(transaction.id),
            originalTransactionID: String(transaction.originalID),
            appTransactionID: appTransactionID,
            productID: transaction.productID,
            accountID: transaction.appAccountToken,
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
