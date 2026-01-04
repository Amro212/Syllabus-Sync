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
            print("🔵 Starting Google Sign-In...")
            print("🔵 Supabase URL: \(SupabaseConfig.url)")
            print("🔵 Redirect URL: syllabussync://auth/callback")
            
            // Use Supabase SDK's OAuth method with redirect URL
            let session = try await supabase.auth.signInWithOAuth(
                provider: .google,
                redirectTo: URL(string: "syllabussync://auth/callback")
            ) { session in
                // Use ephemeral session so user can choose a different account each time
                // (doesn't share cookies with Safari)
                session.prefersEphemeralWebBrowserSession = true
            }
            
            print("🟢 Google Sign-In successful!")
            
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
            
            return .success(user: user)
            
        } catch {
            print("🔴 Google Sign-In Error: \(error)")
            
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
    
    // MARK: - Email/Password Sign In
    
    func signInWithEmail(email: String, password: String) async -> AuthResult {
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
            return .failure(error: .invalidCredentials)
        }
    }
    
    // MARK: - User Provider Check
    
    /// Check if a user exists and what auth provider they use
    /// Uses Supabase client to check user's auth provider from app_metadata
    func checkUserProvider(email: String) async -> Result<UserProviderInfo, AuthError> {
        do {
            // Try to sign in with a magic link to trigger user lookup
            // This will fail if user doesn't exist, but we can catch the error
            // Note: We're not actually sending an OTP, just checking if user exists
            
            // Alternative approach: Use the admin API through Supabase client
            // Since we can't access admin API from client, we'll use a different strategy:
            // Try to send OTP with shouldCreateUser: false
            // If user doesn't exist, Supabase will return an error
            // If user exists but used OAuth, we can't detect it this way
            
            // Best approach: Check via server endpoint (current implementation)
            guard let serverURL = URL(string: "http://localhost:8787/auth/check-provider") else {
                return .success(UserProviderInfo(exists: false, provider: nil))
            }
            
            var request = URLRequest(url: serverURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONEncoder().encode(["email": email])
            request.timeoutInterval = 10
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    return .success(UserProviderInfo(exists: false, provider: nil))
                }
                
                // If server endpoint doesn't exist (404), fall back to allowing OTP
                if httpResponse.statusCode == 404 {
                    return .success(UserProviderInfo(exists: false, provider: nil))
                }
                
                guard httpResponse.statusCode == 200 else {
                    return .success(UserProviderInfo(exists: false, provider: nil))
                }
                
                // Parse response
                struct ProviderResponse: Decodable {
                    let exists: Bool
                    let provider: String?
                }
                
                let result = try JSONDecoder().decode(ProviderResponse.self, from: data)
                let authProvider: AuthProvider? = result.provider.flatMap { AuthProvider(rawValue: $0) }
                
                return .success(UserProviderInfo(exists: result.exists, provider: authProvider))
                
            } catch {
                // On network error, allow the flow to continue (fail open)
                print("⚠️ Provider check failed, continuing: \(error)")
                return .success(UserProviderInfo(exists: false, provider: nil))
            }
            
        } catch {
            print("⚠️ Provider check error: \(error)")
            return .success(UserProviderInfo(exists: false, provider: nil))
        }
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
            
            print("✅ OTP code sent to \(email)")
            return .success(())
            
        } catch {
            print("❌ Failed to send OTP: \(error)")
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
            
            print("✅ OTP verified for \(email)")
            
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
            print("❌ OTP verification failed: \(error)")
            // Map verification errors to user-friendly messages
            let mappedError = AuthErrorHandler.mapError(error.localizedDescription)
            return .failure(error: mappedError)
        }
    }
    
    /// Store username in profiles table for uniqueness and querying
    private func storeUsernameInDatabase(userId: String, username: String) async {
        do {
            // Insert or update username in profiles table
            try await supabase
                .from("profiles")
                .upsert([
                    "id": userId,
                    "username": username,
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .execute()
            
            print("✅ Username '\(username)' stored in database")
        } catch {
            print("⚠️ Failed to store username in database: \(error)")
            // Don't fail auth if database storage fails - username is in metadata
        }
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
        do {
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
            }
        } catch {
            // No session to restore
            self.currentUser = nil
        }
    }
}
