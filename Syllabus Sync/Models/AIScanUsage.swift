//
//  AIScanUsage.swift
//  Syllabus Sync
//

import Foundation

struct AIScanUsageSnapshot: Codable, Equatable {
    let freeUsedCount: Int
    let freeRemaining: Int
    let freeAllowance: Int
    let paidRemaining: Int
    let totalRemaining: Int
    let canScan: Bool
    let productId: String
    let packCredits: Int
}

struct AIScanUsageEnvelope: Codable {
    let usage: AIScanUsageSnapshot
}

struct AIPurchaseCreditRequest: Encodable {
    let transactionId: String
    let originalTransactionId: String?
    let appTransactionId: String?
    let productId: String
    let environment: String
    let signedTransactionInfo: String
}

struct AIPurchaseCreditEnvelope: Codable {
    let usage: AIScanUsageSnapshot
    let credited: Bool
    let duplicate: Bool
}

enum AIScanCommerceConfig {
    static let productID = "syllabussync.ai_scans_5"
    static let packCredits = 5
    static let salePrice = "$5.99"
    static let compareAtPrice = "$10.99"
}

extension AIScanUsageSnapshot {
    var heroLine: String {
        if totalRemaining > 0 {
            return totalRemaining == 1 ? "1 AI scan left" : "\(totalRemaining) AI scans left"
        }
        return "No AI scans left"
    }

    var freeLine: String {
        if freeRemaining > 0 {
            return "\(freeRemaining) of \(freeAllowance) free left"
        }
        return "\(freeAllowance) free scans used"
    }
}
