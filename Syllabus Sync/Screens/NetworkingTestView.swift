//
//  NetworkingTestView.swift
//  Syllabus Sync
//

import SwiftUI

struct HealthResponse: Codable {
    let ok: Bool
    let timestamp: String
}

struct NetworkingTestView: View {
    @State private var testResults: [String] = []
    @State private var isRunning = false
    @State private var serverStatus = "Unknown"
    
    private let apiClient: APIClient = {
        let config = URLSessionAPIClient.Configuration(
            baseURL: URL(string: "http://localhost:8787")!,
            defaultHeaders: ["Content-Type": "application/json"],
            requestTimeout: 10,
            maxRetryCount: 1
        )
        return URLSessionAPIClient(configuration: config)
    }()
    
    private let parser: SyllabusParser = {
        let config = URLSessionAPIClient.Configuration(
            baseURL: URL(string: "http://localhost:8787")!,
            defaultHeaders: ["Content-Type": "application/json"],
            requestTimeout: 10,
            maxRetryCount: 1
        )
        let client = URLSessionAPIClient(configuration: config)
        return SyllabusParserRemote(apiClient: client)
    }()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Layout.Spacing.lg) {
                    // Header
                    VStack(spacing: Layout.Spacing.md) {
                        Text("Networking Test")
                            .font(.titleL)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("Test the API client and parsing functionality")
                            .font(.body)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, Layout.Spacing.lg)
                    
                    // Server Status
                    HStack {
                        Circle()
                            .fill(serverStatus == "Online" ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                        Text("Server: \(serverStatus)")
                            .font(.body)
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .padding(.horizontal, Layout.Spacing.md)
                    .padding(.vertical, Layout.Spacing.sm)
                    .background(AppColors.surface)
                    .cornerRadius(Layout.CornerRadius.sm)
                    
                    // Test Buttons
                    VStack(spacing: Layout.Spacing.md) {
                        Button("Test Health Endpoint") {
                            testHealthEndpoint()
                        }
                        .disabled(isRunning)
                        .padding()
                        .background(AppColors.accent)
                        .foregroundColor(.white)
                        .cornerRadius(Layout.CornerRadius.md)
                        
                        Button("Test Parse Endpoint") {
                            testParseEndpoint()
                        }
                        .disabled(isRunning)
                        .padding()
                        .background(AppColors.surface)
                        .foregroundColor(AppColors.textPrimary)
                        .cornerRadius(Layout.CornerRadius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                                .stroke(AppColors.border, lineWidth: 1)
                        )
                        
                        Button("Run All Tests") {
                            runAllTests()
                        }
                        .disabled(isRunning)
                        .padding()
                        .background(AppColors.accent)
                        .foregroundColor(.white)
                        .cornerRadius(Layout.CornerRadius.md)
                    }
                    
                    // Results
                    if !testResults.isEmpty {
                        VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
                            Text("Test Results")
                                .font(.headline)
                                .foregroundColor(AppColors.textPrimary)
                            
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                                    ForEach(testResults.indices, id: \.self) { index in
                                        Text(testResults[index])
                                            .font(.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                            .padding(.vertical, 2)
                                    }
                                }
                            }
                            .frame(maxHeight: 200)
                            .padding(Layout.Spacing.sm)
                            .background(AppColors.surface)
                            .cornerRadius(Layout.CornerRadius.sm)
                        }
                    }
                    
                    Spacer()
                }
                .padding(Layout.Spacing.lg)
            }
            .background(AppColors.background)
            .navigationTitle("Networking Test")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                checkServerStatus()
            }
        }
    }
    
    private func checkServerStatus() {
        Task {
            do {
                let request = APIRequest(path: "/health", method: .get)
                let _: HealthResponse = try await apiClient.send(request, as: HealthResponse.self)
                await MainActor.run {
                    serverStatus = "Online"
                }
            } catch {
                await MainActor.run {
                    serverStatus = "Offline"
                }
            }
        }
    }
    
    private func testHealthEndpoint() {
        isRunning = true
        testResults.append("🔍 Testing Health Endpoint...")
        
        Task {
            do {
                let request = APIRequest(path: "/health", method: .get)
                let response: HealthResponse = try await apiClient.send(request, as: HealthResponse.self)
                
                await MainActor.run {
                    testResults.append("✅ Health endpoint successful")
                    testResults.append("📄 Response: \(response)")
                    isRunning = false
                }
            } catch {
                await MainActor.run {
                    testResults.append("❌ Health endpoint failed: \(error.localizedDescription)")
                    isRunning = false
                }
            }
        }
    }
    
    private func testParseEndpoint() {
        isRunning = true
        testResults.append("🔍 Testing Parse Endpoint...")
        
        Task {
            do {
                let sampleText = """
                Course: CS 101 - Introduction to Computer Science
                
                Important Dates:
                - Midterm Exam: October 15, 2024 at 2:00 PM
                - Final Exam: December 10, 2024 at 3:00 PM
                - Assignment 1 Due: September 20, 2024
                - Assignment 2 Due: October 5, 2024
                """
                
                let result = try await parser.parse(text: sampleText)
                
                await MainActor.run {
                    testResults.append("✅ Parse endpoint successful")
                    testResults.append("📊 Found \(result.count) events")
                    
                    for (index, event) in result.enumerated() {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .short
                        formatter.timeStyle = .short
                        testResults.append("📅 Event \(index + 1): \(event.title) - \(formatter.string(from: event.start))")
                    }
                    
                    isRunning = false
                }
            } catch {
                await MainActor.run {
                    testResults.append("❌ Parse endpoint failed: \(error.localizedDescription)")
                    isRunning = false
                }
            }
        }
    }
    
    private func runAllTests() {
        testResults.removeAll()
        testHealthEndpoint()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            testParseEndpoint()
        }
    }
}

#Preview {
    NetworkingTestView()
}
