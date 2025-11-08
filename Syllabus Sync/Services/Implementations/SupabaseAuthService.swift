//
//  SupabaseAuthService.swift
//  Syllabus Sync
//
//  Supabase implementation of AuthService
//

import Foundation
import Supabase

/// Supabase authentication service implementation
class SupabaseAuthService: NSObject, AuthService {
    
    // MARK: - Properties
    
    static let shared = SupabaseAuthService()
    
    let supabase: SupabaseClient
    
    private(set) var currentUser: AuthUser?
    
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
            // Use Supabase SDK's OAuth method with redirect URL
            let session = try await supabase.auth.signInWithOAuth(
                provider: .google,
                redirectTo: URL(string: "syllabussync://auth/callback")
            ) { session in
                // Optional: customize the ASWebAuthenticationSession
                session.prefersEphemeralWebBrowserSession = false
            }
            
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
            if let authError = error as? AuthError {
                return .failure(error: authError)
            }
            return .failure(error: .unknownError(error.localizedDescription))
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
    
    // MARK: - Email/Password Sign Up
    
    func signUpWithEmail(email: String, password: String, firstName: String?, lastName: String?) async -> AuthResult {
        do {
            var metadata: [String: AnyJSON] = [:]
            if let firstName = firstName, let lastName = lastName {
                metadata["full_name"] = .string("\(firstName) \(lastName)")
            }
            
            let session = try await supabase.auth.signUp(
                email: email,
                password: password,
                data: metadata
            )
            
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
            return .failure(error: .unknownError(error.localizedDescription))
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
