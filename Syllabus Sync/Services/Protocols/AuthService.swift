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
    case userNotFound
    case invalidOTP
    case otpExpired
    case rateLimitExceeded
    case oauthUserAttemptingEmail(provider: AuthProvider)
    
    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Authentication was cancelled"
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError:
            return "Unable to connect. Please check your internet connection."
        case .unknownError(let message):
            return message
        case .notAuthenticated:
            return "User is not authenticated"
        case .tokenExpired:
            return "Session expired. Please sign in again."
        case .userNotFound:
            return "No account found with this email. Please sign up first."
        case .invalidOTP:
            return "Incorrect code. Please check and try again."
        case .otpExpired:
            return "This code has expired. Please request a new one."
        case .rateLimitExceeded:
            return "Too many attempts. Please wait a moment and try again."
        case .oauthUserAttemptingEmail(let provider):
            let providerName = provider.rawValue.capitalized
            return "This email uses \(providerName) Sign In. Please tap 'Continue with \(providerName)' below."
        }
    }
}

/// Information about a user's auth provider
struct UserProviderInfo {
    let exists: Bool
    let provider: AuthProvider?
}

/// Utility for mapping raw Supabase errors to user-friendly AuthError types
enum AuthErrorHandler {
    /// Maps a raw error message from Supabase to an appropriate AuthError
    /// Based on Supabase's documented error messages:
    /// - Invalid OTP: "The code you provided is invalid" or "Invalid OTP"
    /// - Expired OTP: "The token has expired"
    static func mapError(_ rawMessage: String) -> AuthError {
        let lowercased = rawMessage.lowercased()
        
        // Check for invalid/wrong OTP FIRST (before expired)
        // Supabase returns: "The code you provided is invalid" or "Invalid OTP"
        if lowercased.contains("invalid") ||
           lowercased.contains("wrong") ||
           lowercased.contains("incorrect") {
            return .invalidOTP
        }
        
        // Check for expired OTP SECOND
        // Supabase returns: "The token has expired"
        if lowercased.contains("expired") {
            return .otpExpired
        }
        
        // User doesn't exist
        if lowercased.contains("signups not allowed") ||
           lowercased.contains("user not found") ||
           lowercased.contains("no user found") {
            return .userNotFound
        }
        
        // Rate limiting
        if lowercased.contains("rate limit") ||
           lowercased.contains("too many requests") ||
           lowercased.contains("email rate limit") {
            return .rateLimitExceeded
        }
        
        // Network errors
        if lowercased.contains("network") ||
           lowercased.contains("connection") ||
           lowercased.contains("timeout") ||
           lowercased.contains("offline") {
            return .networkError
        }
        
        // Invalid credentials (for password auth)
        if lowercased.contains("invalid login") ||
           lowercased.contains("invalid credentials") ||
           lowercased.contains("invalid password") {
            return .invalidCredentials
        }
        
        // Fallback - use a generic user-friendly message instead of raw error
        return .unknownError("Something went wrong. Please try again.")
    }
    
    /// Convenience method for user-friendly message display
    static func userFriendlyMessage(for error: AuthError) -> String {
        return error.localizedDescription
    }
}

/// Protocol defining authentication service capabilities
protocol AuthService {
    /// Current authenticated user
    var currentUser: AuthUser? { get }
    
    /// Check if user is authenticated
    var isAuthenticated: Bool { get }
    
    /// Check if a user exists and their auth provider
    func checkUserProvider(email: String) async -> Result<UserProviderInfo, AuthError>
    
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
