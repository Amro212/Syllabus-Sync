//
//  AuthService.swift
//  Syllabus Sync
//
//  Protocol defining authentication service capabilities
//

import Foundation

/// Result type for authentication operations
enum AuthResult {
    case success(user: AuthUser)
    case failure(error: AuthError)
}

/// Authentication user model
struct AuthUser {
    let id: String
    let email: String?
    let displayName: String?
    let photoURL: URL?
    let provider: AuthProvider
}

/// Authentication provider types
enum AuthProvider: String {
    case google = "google"
    case apple = "apple"
    case email = "email"
    case anonymous = "anonymous"
}

/// Authentication errors
enum AuthError: LocalizedError {
    case cancelled
    case invalidCredentials
    case networkError
    case unknownError(String)
    case notAuthenticated
    case tokenExpired
    
    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Authentication was cancelled"
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError:
            return "Network connection error"
        case .unknownError(let message):
            return message
        case .notAuthenticated:
            return "User is not authenticated"
        case .tokenExpired:
            return "Session expired. Please sign in again."
        }
    }
}

/// Protocol defining authentication service capabilities
protocol AuthService {
    /// Current authenticated user
    var currentUser: AuthUser? { get }
    
    /// Check if user is authenticated
    var isAuthenticated: Bool { get }
    
    /// Sign in with Google OAuth
    func signInWithGoogle() async -> AuthResult
    
    /// Sign in with Apple
    func signInWithApple() async -> AuthResult
    
    /// Send OTP code to email for passwordless authentication
    func sendOTP(email: String, shouldCreateUser: Bool, username: String?, fullName: String?) async -> Result<Void, AuthError>
    
    /// Verify OTP code and complete authentication
    func verifyOTP(email: String, token: String) async -> AuthResult
    
    /// Sign out current user
    func signOut() async throws
    
    /// Reset password
    func resetPassword(email: String) async throws
    
    /// Refresh current session
    func refreshSession() async throws
}
