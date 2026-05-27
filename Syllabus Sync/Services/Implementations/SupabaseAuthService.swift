//
//  SupabaseAuthService.swift
//  Syllabus Sync
//
//  Supabase implementation of AuthService
//

import Foundation
import Supabase
import AuthenticationServices

/// Supabase authentication service implementation
class SupabaseAuthService: NSObject, AuthService {
    
    // MARK: - Properties
    
    static let shared = SupabaseAuthService()
    
    let supabase: SupabaseClient
    
    var currentUser: AuthUser?
    
    var isAuthenticated: Bool {
        return currentUser != nil
    }
    
    // MARK: - Initialization
    
    private override init() {
        guard let url = URL(string: SupabaseConfig.url) else {
            fatalError("Invalid Supabase URL")
        }
        
        self.supabase = SupabaseClient(
            supabaseURL: url,
            supabaseKey: SupabaseConfig.anonKey
        )
        
        super.init()
        
        // Try to restore session
        Task {
            await restoreSession()
        }
    }
    
    // MARK: - Google Sign In
    
    func signInWithGoogle() async -> AuthResult {
        do {
            AppLog.debug("Starting Google Sign-In")
            
            // Use Supabase SDK's OAuth method with redirect URL
            let session = try await supabase.auth.signInWithOAuth(
                provider: .google,
                redirectTo: URL(string: "syllabussync://auth/callback")
            ) { session in
                // Use ephemeral session so user can choose a different account each time
                // (doesn't share cookies with Safari)
                session.prefersEphemeralWebBrowserSession = true
            }
            
            AppLog.debug("Google Sign-In successful")
            
            // Convert Supabase session to our AuthUser
            let user = AuthUser(
                id: session.user.id.uuidString,
                email: session.user.email,
                displayName: session.user.userMetadata["full_name"]?.value as? String,
                photoURL: {
                    if let urlString = session.user.userMetadata["avatar_url"]?.value as? String {
                        return URL(string: urlString)
                    }
                    return nil
                }(),
                provider: .google
            )
            
            self.currentUser = user

            // Auto-generate username for OAuth users if they don't have one
            let existingUsername = await fetchUsername(userId: session.user.id.uuidString)
            if existingUsername == nil || existingUsername?.isEmpty == true {
                let generated = generateUsername(from: user.displayName, email: user.email)
                await storeUsernameInDatabase(userId: session.user.id.uuidString, username: generated)
            }

            return .success(user: user)

        } catch {
            AppLog.debug("Google Sign-In error: \(error)")
            
            // Handle user cancellation specifically
            if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                return .failure(error: .cancelled)
            }
            
            // Handle Supabase Auth errors
            if let authError = error as? AuthError {
                return .failure(error: authError)
            }
            
            // Handle other errors with a user-friendly message
            // Clean up the error message if it's the raw NSError description
            let message = error.localizedDescription
            if message.contains("ASWebAuthenticationSession") {
                return .failure(error: .unknownError("Unable to start sign in session. Please try again."))
            }
            
            return .failure(error: .unknownError("Sign in failed: \(message)"))
        }
    }
    
    // MARK: - Apple Sign In (Not used - handled by CloudKit)
    
    func signInWithApple() async -> AuthResult {
        // Apple Sign-In is handled separately via CloudKit
        // This is just a stub to satisfy the protocol
        return .failure(error: .unknownError("Use native Apple Sign-In"))
    }
    
    // MARK: - Email/Password Sign Up
    
    /// Creates a new account with email + password. Supabase will send a confirmation OTP
    /// because email confirmations are enabled in the Supabase dashboard.
    func signUpWithPassword(email: String, password: String, username: String, fullName: String) async -> Result<Void, AuthError> {
        do {
            let metadata: [String: AnyJSON] = [
                "username": .string(username),
                "full_name": .string(fullName)
            ]
            
            let response = try await supabase.auth.signUp(
                email: email,
                password: password,
                data: metadata
            )
            
            AppLog.debug("Sign-up initiated; confirmation email sent")
            return .success(())
            
        } catch {
            AppLog.debug("Sign-up failed: \(error)")
            let mappedError = AuthErrorHandler.mapError(error.localizedDescription)
            return .failure(mappedError)
        }
    }
    
    // MARK: - Email/Password Sign In
    
    /// Direct sign-in with email + password. No OTP required.
    func signInWithPassword(email: String, password: String) async -> AuthResult {
        do {
            let session = try await supabase.auth.signIn(email: email, password: password)
            
            let user = AuthUser(
                id: session.user.id.uuidString,
                email: session.user.email,
                displayName: session.user.userMetadata["full_name"]?.value as? String,
                photoURL: nil,
                provider: .email
            )
            
            self.currentUser = user
            
            return .success(user: user)
            
        } catch {
            AppLog.debug("Sign-in failed: \(error)")
            let mappedError = AuthErrorHandler.mapError(error.localizedDescription)
            return .failure(error: mappedError)
        }
    }
    
    /// Legacy email/password method — delegates to signInWithPassword
    func signInWithEmail(email: String, password: String) async -> AuthResult {
        return await signInWithPassword(email: email, password: password)
    }
    
    // MARK: - User Provider Check
    
    /// Provider lookup is intentionally disabled to avoid account enumeration.
    /// Supabase remains the source of truth for sign-up/sign-in errors.
    func checkUserProvider(email: String) async -> Result<UserProviderInfo, AuthError> {
        return .success(UserProviderInfo(exists: false, provider: nil, isEmailConfirmed: false))
    }
    
    // MARK: - OTP Authentication
    
    /// Send OTP code to email for passwordless authentication
    /// Note: Supabase "Confirm email" setting must be DISABLED for OTP codes to work
    /// Otherwise, it sends magic links instead of 6-digit codes
    func sendOTP(
        email: String,
        shouldCreateUser: Bool,
        username: String? = nil,
        fullName: String? = nil
    ) async -> Result<Void, AuthError> {
        do {
            var metadata: [String: AnyJSON] = [:]
            if let username = username {
                metadata["username"] = .string(username)
            }
            if let fullName = fullName {
                metadata["full_name"] = .string(fullName)
            }
            
            // Send OTP - User is created on first OTP verification
            try await supabase.auth.signInWithOTP(
                email: email,
                redirectTo: nil,
                shouldCreateUser: shouldCreateUser,
                data: metadata.isEmpty ? nil : metadata
            )
            
            AppLog.debug("OTP code sent")
            return .success(())
            
        } catch {
            AppLog.debug("Failed to send OTP: \(error)")
            // Use AuthErrorHandler to map raw error to user-friendly message
            let mappedError = AuthErrorHandler.mapError(error.localizedDescription)
            return .failure(mappedError)
        }
    }
    
    /// Verify OTP code and complete authentication
    func verifyOTP(email: String, token: String) async -> AuthResult {
        do {
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: token,
                type: .email
            )
            
            AppLog.debug("OTP verified")
            
            let user = AuthUser(
                id: session.user.id.uuidString,
                email: session.user.email,
                displayName: session.user.userMetadata["full_name"]?.value as? String,
                photoURL: nil,
                provider: .email
            )
            
            self.currentUser = user
            
            // Store username in database if it exists in metadata
            if let username = session.user.userMetadata["username"]?.value as? String {
                await storeUsernameInDatabase(userId: session.user.id.uuidString, username: username)
            }
            
            return .success(user: user)
            
        } catch {
            AppLog.debug("OTP verification failed: \(error)")
            // Map verification errors to user-friendly messages
            let mappedError = AuthErrorHandler.mapError(error.localizedDescription)
            AppLog.debug("Mapped OTP error: \(mappedError)")
            return .failure(error: mappedError)
        }
    }
    
    /// Resend OTP code to the user's email
    func resendOTP(email: String) async -> AuthResult {
        do {
            // Supabase doesn't have a dedicated resend endpoint
            // We need to trigger a new sign-in flow which will send a new OTP
            let _ = try await supabase.auth.signInWithOTP(
                email: email
            )
            
            AppLog.debug("New OTP sent")
            
            // Return success (no user object yet since they haven't verified)
            let dummyUser = AuthUser(
                id: "",
                email: email,
                displayName: nil,
                photoURL: nil,
                provider: .email
            )
            return .success(user: dummyUser)
            
        } catch {
            AppLog.debug("Failed to resend OTP: \(error)")
            let mappedError = AuthErrorHandler.mapError(error.localizedDescription)
            return .failure(error: mappedError)
        }
    }
    
    /// Store username in users table for uniqueness and querying
    func storeUsernameInDatabase(userId: String, username: String) async {
        do {
            try await supabase
                .from("users")
                .upsert([
                    "id": userId,
                    "username": username,
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .execute()
            AppLog.debug("Username stored in database")
        } catch {
            AppLog.debug("Failed to store username in database: \(error)")
        }
    }

    /// Fetch the current user's username from the users table
    func fetchUsername(userId: String) async -> String? {
        do {
            struct UserRow: Decodable {
                let username: String?
            }
            let rows: [UserRow] = try await supabase
                .from("users")
                .select("username")
                .eq("id", value: userId)
                .limit(1)
                .execute()
                .value
            return rows.first?.username
        } catch {
            AppLog.debug("Failed to fetch username: \(error)")
            return nil
        }
    }

    /// Generate a unique username from display name or email
    func generateUsername(from displayName: String?, email: String?) -> String {
        let base: String
        if let name = displayName, !name.isEmpty {
            base = name
                .lowercased()
                .components(separatedBy: .whitespaces)
                .joined()
                .filter { $0.isLetter || $0.isNumber || $0 == "_" }
        } else if let email = email, let local = email.split(separator: "@").first {
            base = String(local)
                .lowercased()
                .filter { $0.isLetter || $0.isNumber || $0 == "_" }
        } else {
            base = "user"
        }
        let trimmed = String(base.prefix(14))
        let suffix = String(Int.random(in: 100...9999))
        return "\(trimmed)_\(suffix)"
    }
    
    // MARK: - Sign Out
    
    func signOut() async throws {
        try await supabase.auth.signOut()
        self.currentUser = nil
    }
    
    // MARK: - Password Reset
    
    func resetPassword(email: String) async throws {
        try await supabase.auth.resetPasswordForEmail(email)
    }
    
    // MARK: - Refresh Session
    
    func refreshSession() async throws {
        let session = try await supabase.auth.refreshSession()
        
        // Update current user from refreshed session
        if let user = try? await supabase.auth.user() {
            self.currentUser = AuthUser(
                id: user.id.uuidString,
                email: user.email,
                displayName: user.userMetadata["full_name"]?.value as? String,
                photoURL: {
                    if let urlString = user.userMetadata["avatar_url"]?.value as? String {
                        return URL(string: urlString)
                    }
                    return nil
                }(),
                provider: .google
            )
        }
    }
    
    // MARK: - Session Persistence
    
    private func restoreSession() async {
        // Supabase SDK automatically handles session restoration
        // Just check if there's a current session and update our user
        if let session = try? await supabase.auth.session {
            let user = AuthUser(
                id: session.user.id.uuidString,
                email: session.user.email,
                displayName: session.user.userMetadata["full_name"]?.value as? String,
                photoURL: {
                    if let urlString = session.user.userMetadata["avatar_url"]?.value as? String {
                        return URL(string: urlString)
                    }
                    return nil
                }(),
                provider: session.user.appMetadata["provider"]?.value as? String == "google" ? .google : .email
            )
            self.currentUser = user
        } else {
            // No session to restore
            self.currentUser = nil
        }
    }
}
