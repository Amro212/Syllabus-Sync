//
//  SocialHubModels.swift
//  Syllabus Sync
//
//  Data models for the Social Hub friend system.
//  Maps to Supabase tables: users, friend_requests, friends
//

import Foundation

// MARK: - User Profile (maps to "users" table)

struct UserProfile: Identifiable, Codable, Equatable {
    let id: String
    let username: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case updatedAt = "updated_at"
    }
}

// MARK: - Friend Request

enum FriendRequestStatus: String, Codable {
    case pending
    case accepted
    case declined
    case cancelled
}

/// Row from the friend_requests table
struct FriendRequest: Identifiable, Codable, Equatable {
    let id: String
    let fromUserId: String
    let toUserId: String
    let status: FriendRequestStatus
    let createdAt: String
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fromUserId  = "from_user_id"
        case toUserId    = "to_user_id"
        case status
        case createdAt   = "created_at"
        case updatedAt   = "updated_at"
    }
}

/// Insert DTO – only the fields the client sends
struct FriendRequestInsert: Codable {
    let id: String
    let fromUserId: String
    let toUserId: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case fromUserId  = "from_user_id"
        case toUserId    = "to_user_id"
        case status
    }
}

// MARK: - Friendship (maps to "friends" table)

struct Friendship: Identifiable, Codable, Equatable {
    let id: String
    let userAId: String
    let userBId: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userAId   = "user_a_id"
        case userBId   = "user_b_id"
        case createdAt = "created_at"
    }
}

struct FriendshipInsert: Codable {
    let id: String
    let userAId: String
    let userBId: String

    enum CodingKeys: String, CodingKey {
        case id
        case userAId  = "user_a_id"
        case userBId  = "user_b_id"
    }
}

// MARK: - View-level display models

/// A pending request enriched with the sender's profile info
struct PendingRequestDisplay: Identifiable, Equatable {
    let id: String           // request id
    let fromUserId: String
    let username: String
    let displayName: String? // from auth metadata if available
    let contextLine: String  // e.g. "WANTS TO CONNECT"
}

/// A confirmed friend for the "My Connections" grid
struct FriendDisplay: Identifiable, Equatable {
    let id: String           // friendship id
    let userId: String       // the friend's user id
    let username: String
    let displayName: String?
    let courseName: String?  // top shared course, placeholder if none
}

/// A user found via search in the Discover tab
struct DiscoverUserDisplay: Identifiable, Equatable {
    let id: String           // the user's id
    let username: String
    let displayName: String?
    let mutualFriendsCount: Int
    let coursesText: String? // e.g. "CS 101, MATH 221"
    let requestState: DiscoverRequestState
}

enum DiscoverRequestState: Equatable {
    case none
    case requested  // outgoing pending
    case friends    // already friends
}

// MARK: - Avatar Color Helper

/// Deterministic avatar background color based on user id
enum AvatarColor {
    static let palette: [String] = [
        "#D2691E", // orange-brown
        "#4CAF50", // green
        "#9C27B0", // purple
        "#E91E63", // pink
        "#FF9800", // orange
        "#00BCD4", // teal
        "#3F51B5", // indigo
        "#F44336"  // red
    ]

    static func hex(for userId: String) -> String {
        let hash = userId.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return palette[abs(hash) % palette.count]
    }

    static func initials(from username: String) -> String {
        let parts = username.split(separator: "_")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(username.prefix(2)).uppercased()
    }
}
