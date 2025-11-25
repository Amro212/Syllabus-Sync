//
//  ErrorHandler.swift
//  Syllabus Sync
//
//  Error handling utility for displaying user-friendly error messages
//

import SwiftUI

@MainActor
class ErrorHandler: ObservableObject {
    @Published var showError = false
    @Published var errorMessage = ""
    
    func handle(_ error: DataError) {
        errorMessage = error.localizedDescription ?? "Unknown error"
        showError = true
    }
    
    func handle(_ error: Error) {
        if let dataError = error as? DataError {
            handle(dataError)
        } else {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

