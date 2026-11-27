import Foundation
import Testing
@testable import Syllabus_Sync

@MainActor
struct AIScanUsageStoreTests {
    @Test func refreshLoadsUsageSnapshot() async throws {
        let apiClient = FakeAPIClient { request in
            #expect(request.path == "/ai-usage")
            return try testEncoder.encode(AIScanUsageEnvelope(
                usage: AIScanUsageSnapshot(
                    freeUsedCount: 1,
                    freeRemaining: 1,
                    freeAllowance: 2,
                    paidRemaining: 3,
                    totalRemaining: 4,
                    canScan: true,
                    productId: AIScanCommerceConfig.productID,
                    packCredits: AIScanCommerceConfig.packCredits
                )
            ))
        }
        let store = AIScanUsageStore(
            apiClient: apiClient,
            purchaseManager: FakePurchaseManager(),
            accountIDProvider: { testAccountID },
            accessTokenProvider: { "token" }
        )

        await store.refresh()

        #expect(store.snapshot?.totalRemaining == 4)
        #expect(store.snapshot?.paidRemaining == 3)
        #expect(store.lastErrorMessage == nil)
    }

    @Test func purchaseTopUpCreditsAndFinishesTransaction() async throws {
        let purchaseManager = FakePurchaseManager(
            purchaseRecord: AppStorePurchaseRecord(
                transactionID: "txn-1",
                originalTransactionID: "txn-1",
                appTransactionID: "app-txn-1",
                productID: AIScanCommerceConfig.productID,
                environment: "sandbox",
                signedTransactionInfo: "header.payload.signature",
                finishHandler: {}
            )
        )
        let apiClient = FakeAPIClient { request in
            #expect(request.path == "/iap/credit")
            return try testEncoder.encode(AIPurchaseCreditEnvelope(
                usage: AIScanUsageSnapshot(
                    freeUsedCount: 2,
                    freeRemaining: 0,
                    freeAllowance: 2,
                    paidRemaining: 5,
                    totalRemaining: 5,
                    canScan: true,
                    productId: AIScanCommerceConfig.productID,
                    packCredits: AIScanCommerceConfig.packCredits
                ),
                credited: true,
                duplicate: false
            ))
        }
        let store = AIScanUsageStore(
            apiClient: apiClient,
            purchaseManager: purchaseManager,
            accountIDProvider: { testAccountID },
            accessTokenProvider: { "token" }
        )

        let success = await store.purchaseTopUp()

        #expect(success)
        #expect(store.snapshot?.paidRemaining == 5)
        #expect(purchaseManager.finishedTransactionIDs == ["txn-1"])
    }

    @Test func failedCreditLeavesPurchaseUnfinished() async {
        let manager = FakePurchaseManager(purchaseRecord: AppStorePurchaseRecord(
            transactionID: "pending-transaction",
            originalTransactionID: "pending-transaction",
            appTransactionID: nil,
            productID: AIScanCommerceConfig.productID,
            environment: "sandbox",
            signedTransactionInfo: "fixture",
            finishHandler: {}
        ))
        let store = AIScanUsageStore(
            apiClient: FakeAPIClient { _ in throw APIClientError.timeout },
            purchaseManager: manager,
            accountIDProvider: { testAccountID },
            accessTokenProvider: { "token" }
        )

        #expect(await !store.purchaseTopUp())
        #expect(manager.finishedTransactionIDs.isEmpty)
        #expect(store.lastErrorMessage?.contains("Sync purchases") == true)
    }

    @Test func refreshClearsSnapshotWhenSignedOut() async throws {
        let store = AIScanUsageStore(
            apiClient: FakeAPIClient { _ in
                fatalError("Should not call API")
            },
            purchaseManager: FakePurchaseManager(),
            accountIDProvider: { nil },
            accessTokenProvider: { "token" }
        )

        await store.refresh()

        #expect(store.snapshot == nil)
    }
}

private final class FakeAPIClient: APIClient {
    private let handler: (APIRequest) throws -> Data
    private let decoder = JSONDecoder()

    init(handler: @escaping (APIRequest) throws -> Data) {
        self.handler = handler
    }

    func send<T>(_ request: APIRequest, as type: T.Type) async throws -> T where T : Decodable {
        let data = try handler(request)
        return try decoder.decode(type, from: data)
    }

    func sendWithRawResponse<T>(_ request: APIRequest, as type: T.Type) async throws -> (T, String) where T : Decodable {
        let data = try handler(request)
        let value: T = try await send(request, as: type)
        return (value, String(data: data, encoding: .utf8) ?? "")
    }
}

private final class FakePurchaseManager: AppStorePurchasing {
    let purchaseRecord: AppStorePurchaseRecord?
    private(set) var finishedTransactionIDs: [String] = []

    init(purchaseRecord: AppStorePurchaseRecord? = nil) {
        self.purchaseRecord = purchaseRecord
    }

    func displayPrice(productID: String) async throws -> String {
        "CA$5.99"
    }

    func purchase(productID: String, accountID: UUID) async throws -> AppStorePurchaseRecord {
        guard let purchaseRecord else {
            throw AppStorePurchaseError.productUnavailable
        }
        return AppStorePurchaseRecord(
            transactionID: purchaseRecord.transactionID,
            originalTransactionID: purchaseRecord.originalTransactionID,
            appTransactionID: purchaseRecord.appTransactionID,
            productID: purchaseRecord.productID,
            accountID: accountID,
            environment: purchaseRecord.environment,
            signedTransactionInfo: purchaseRecord.signedTransactionInfo,
            finishHandler: { [weak self] in
                self?.finishedTransactionIDs.append(purchaseRecord.transactionID)
            }
        )
    }

    func sync() async throws {}

    func unfinishedTransactions(productIDs: Set<String>) async -> [AppStorePurchaseRecord] { [] }

    func startListening(
        productIDs: Set<String>,
        handler: @escaping @Sendable (AppStorePurchaseRecord) async -> Void
    ) -> Task<Void, Never> {
        Task {}
    }
}

private let testAccountID = UUID()
private let testEncoder = JSONEncoder()
