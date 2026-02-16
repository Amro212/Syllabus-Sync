//
//  ProfileModels.swift
//  Syllabus Sync
//
//  Data models for user profile management, schedule visibility, and blocking.
//

import Foundation

// MARK: - Schedule Visibility

enum ScheduleVisibility: String, Codable, CaseIterable {
    case publicAccess = "public"
    case friendsOnly = "friends_only"
    case privateAccess = "private"

    var displayName: String {
        switch self {
        case .publicAccess: return "Public"
        case .friendsOnly: return "Friends Only"
        case .privateAccess: return "Private"
        }
    }

    var description: String {
        switch self {
        case .publicAccess: return "Anyone can view your schedule"
        case .friendsOnly: return "Only friends can view your schedule"
        case .privateAccess: return "Only you can view your schedule"
        }
    }

    var icon: String {
        switch self {
        case .publicAccess: return "globe"
        case .friendsOnly: return "person.2.fill"
        case .privateAccess: return "lock.fill"
        }
    }
}

// MARK: - Blocked User

struct BlockedUser: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let username: String
    let blockedAt: Date
}

// MARK: - User Preferences

struct UserPreferences: Codable {
    var userId: String
    var notificationsEnabled: Bool
    var hapticFeedbackEnabled: Bool
    var friendRequestNotifications: Bool
    var themePreference: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case notificationsEnabled = "notifications_enabled"
        case hapticFeedbackEnabled = "haptic_feedback_enabled"
        case friendRequestNotifications = "friend_request_notifications"
        case themePreference = "theme_preference"
    }
}

// MARK: - Helper Structs for Supabase Queries

struct BlockRow: Codable {
    let id: String
    let blockedId: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case blockedId = "blocked_id"
        case createdAt = "created_at"
    }
}

struct BlockInsert: Codable {
    let id: String
    let blockerId: String
    let blockedId: String

    enum CodingKeys: String, CodingKey {
        case id
        case blockerId = "blocker_id"
        case blockedId = "blocked_id"
    }
}
