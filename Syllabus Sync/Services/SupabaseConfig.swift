//
//  SupabaseConfig.swift
//  Syllabus Sync
//
//  Configuration for Supabase backend services
//

import Foundation

/// Supabase project configuration
/// Note: The anon key is safe to expose in client apps - it's intended for public use
/// Never expose the service_role key in client code
enum SupabaseConfig {
    /// Your Supabase project URL
    static let url = "https://wlxhikzgbrulmdxofheu.supabase.co"
    
    /// Public anon key (safe for client-side use)
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndseGhpa3pnYnJ1bG1keG9maGV1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcxODEzNzgsImV4cCI6MjA3Mjc1NzM3OH0.Cu0GznczmbpQ4q4Y22MIp7M7JV0KRc80-vyDHhFR9U0"
    
    /// Redirect URL for OAuth flows
    static var redirectURL: String {
        return "\(url)/auth/v1/callback"
    }
}
