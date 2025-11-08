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
    // Initialize Core Data stack with optional CloudKit support
    // CloudKit requires a paid Apple Developer account
    // For development with Personal Team, CloudKit is disabled (local-only Core Data)
    private let coreDataStack: CoreDataStack = {
        #if targetEnvironment(simulator)
        // Simulator: Use local-only Core Data (CloudKit requires iCloud account sign-in)
        let configuration = CoreDataStack.Configuration(
            storeType: .persistent,
            cloudKitContainerIdentifier: nil  // nil = local-only
        )
        #else
        // Device: Enable CloudKit (requires paid developer account)
        let configuration = CoreDataStack.Configuration(
            storeType: .persistent,
            cloudKitContainerIdentifier: "iCloud.SylSyn.Syllabus-Sync"
        )
        #endif
        return CoreDataStack(configuration: configuration)
    }()
    
    var body: some Scene {
        WindowGroup {
            AppRoot()
                .environment(\.managedObjectContext, coreDataStack.container.viewContext)
                .onOpenURL { url in
                    // Handle OAuth callback from Supabase
                    SupabaseAuthService.shared.supabase.auth.handle(url)
                }
        }
    }
}
