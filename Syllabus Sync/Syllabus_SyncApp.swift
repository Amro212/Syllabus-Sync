//
//  Syllabus_SyncApp.swift
//  Syllabus Sync
//
//  Created by Amro Zabin on 2025-09-06.
//

import SwiftUI
import Supabase

@main
struct Syllabus_SyncApp: App {
    var body: some Scene {
        WindowGroup {
            AppRoot()
                .onOpenURL { url in
                    // Handle OAuth callback from Supabase
                    SupabaseAuthService.shared.supabase.auth.handle(url)
                }
        }
    }
}
