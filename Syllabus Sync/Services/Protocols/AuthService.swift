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
    case weakPassword
    case emailAlreadyInUse
    case emailNotConfirmed
    
    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Authentication was cancelled"
        case .invalidCredentials:
            return "Incorrect email or password. Please try again."
        case .networkError:
            return "Unable to connect. Please check your internet connection."
        case .unknownError(let message):
            return message
        case .notAuthenticated:
            return "You are not signed in. Please sign in to continue."
        case .tokenExpired:
            return "Your session has expired. Please sign in again."
        case .userNotFound:
            return "No account found with this email. Please sign up first."
        case .invalidOTP:
            return "Incorrect verification code. Please check and try again."
        case .otpExpired:
            return "This verification code has expired. Please request a new one."
        case .rateLimitExceeded:
            return "Too many attempts. Please wait a moment and try again."
        case .oauthUserAttemptingEmail(let provider):
            let providerName = provider.rawValue.capitalized
            return "This email uses \(providerName) Sign In. Please tap 'Continue with \(providerName)' below."
        case .weakPassword:
            return "Password must be at least 6 characters and contain uppercase, lowercase, and digits."
        case .emailAlreadyInUse:
            return "An account with this email already exists. Please sign in instead."
        case .emailNotConfirmed:
            return "Please verify your email before signing in."
        }
    }
}

/// Information about a user's auth provider
struct UserProviderInfo {
    let exists: Bool
    let provider: AuthProvider?
    /// False when the account was registered but the OTP was never verified.
    /// Defaults to true so that fallback/error paths conservatively treat users as verified
    /// and avoid wrongly re-opening the OTP screen for fully confirmed accounts.
    var isEmailConfirmed: Bool = true
}

/// Utility for mapping raw Supabase errors to user-friendly AuthError types
enum AuthErrorHandler {
    /// Maps a raw error message from Supabase to an appropriate AuthError
    /// Based on Supabase's documented error messages:
    /// - Invalid OTP: "The code you provided is invalid" or "Invalid OTP"
    /// - Expired OTP: "The token has expired"
    static func mapError(_ rawMessage: String) -> AuthError {
        let lowercased = rawMessage.lowercased()
        
        // Check for invalid credentials FIRST (password auth)
        // Supabase returns: "Invalid login credentials", "Invalid password", "Email not confirmed"
        if lowercased.contains("invalid login") ||
           lowercased.contains("invalid credentials") ||
           lowercased.contains("invalid password") ||
           lowercased.contains("invalid email or password") {
            return .invalidCredentials
        }
        
        // User doesn't exist
        if lowercased.contains("signups not allowed") ||
           lowercased.contains("user not found") ||
           lowercased.contains("no user found") {
            return .userNotFound
        }
        
        // Email not confirmed
        if lowercased.contains("email not confirmed") ||
           lowercased.contains("confirm your email") {
            return .emailNotConfirmed
        }
        
        // Check for invalid/wrong OTP (for verification codes)
        // This must come AFTER invalid credentials check
        if (lowercased.contains("invalid") && (lowercased.contains("code") || lowercased.contains("otp") || lowercased.contains("token"))) ||
           lowercased.contains("wrong code") ||
           lowercased.contains("incorrect code") {
            return .invalidOTP
        }
        
        // Check for expired OTP/token
        if lowercased.contains("expired") && (lowercased.contains("token") || lowercased.contains("code") || lowercased.contains("otp")) {
            return .otpExpired
        }
        
        // Rate limiting
        if lowercased.contains("rate limit") ||
           lowercased.contains("too many requests") ||
           lowercased.contains("email rate limit") ||
           lowercased.contains("you can only request") ||
           lowercased.contains("over_email_send_rate_limit") {
            return .rateLimitExceeded
        }
        
        // Network errors
        if lowercased.contains("network") ||
           lowercased.contains("connection") ||
           lowercased.contains("timeout") ||
           lowercased.contains("offline") {
            return .networkError
        }
        
        // Weak password
        if lowercased.contains("weak password") ||
           lowercased.contains("password should be") ||
           (lowercased.contains("password") && lowercased.contains("at least") && lowercased.contains("characters")) {
            return .weakPassword
        }
        
        // Email already registered
        if lowercased.contains("already registered") ||
           lowercased.contains("already been registered") ||
           lowercased.contains("user already registered") ||
           lowercased.contains("already exists") {
            return .emailAlreadyInUse
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
    
    /// Sign up with email and password (triggers email confirmation OTP)
    func signUpWithPassword(email: String, password: String, username: String, fullName: String) async -> Result<Void, AuthError>
    
    /// Sign in with email and password (direct login, no OTP)
    func signInWithPassword(email: String, password: String) async -> AuthResult
    
    /// Send OTP code to email for passwordless authentication
    func sendOTP(email: String, shouldCreateUser: Bool, username: String?, fullName: String?) async -> Result<Void, AuthError>
    
    /// Verify OTP code and complete sign-up authentication
    func verifyOTP(email: String, token: String) async -> AuthResult
    
    /// Sign out current user
    func signOut() async throws
    
    /// Reset password
    func resetPassword(email: String) async throws
    
    /// Refresh current session
    func refreshSession() async throws
}
