//
//  AuthView.swift
//  Syllabus Sync
//
//  Created by Assistant on 2024-01-01.
//

import SwiftUI

struct AuthView: View {
    @EnvironmentObject var navigationManager: AppNavigationManager
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            VStack(spacing: Layout.Spacing.massive) {
                Spacer()
                
                // Header with App Icon
                VStack(spacing: Layout.Spacing.xl) {
                    // App Icon with subtle animation
                    Image("SyllabusIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .scaleEffect(isLoading ? 0.95 : 1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isLoading)
                    
                    VStack(spacing: Layout.Spacing.md) {
                        Text("Welcome to Syllabus Sync")
                            .font(.titleL)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                        
                        Text("Sign in securely with your iCloud account to sync your academic life")
                            .font(.body)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Layout.Spacing.lg)
                    }
                }
                
                Spacer()
                
                // Apple Sign In Button
                AppleSignInButton(isLoading: $isLoading)
                    .padding(.horizontal, Layout.Spacing.lg)
                
                Spacer()
            }
            .padding(.vertical, Layout.Spacing.xxl)
        }
        .navigationBarHidden(true)
        .disabled(isLoading)
    }
}


// MARK: - Apple Sign In Button

struct AppleSignInButton: View {
    @EnvironmentObject var navigationManager: AppNavigationManager
    @Binding var isLoading: Bool
    @State private var isPressed = false
    
    var body: some View {
        Button(action: appleSignInAction) {
            HStack(spacing: Layout.Spacing.md) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "applelogo")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Text(isLoading ? "Signing in..." : "Continue with Apple")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.black)
            .cornerRadius(Layout.CornerRadius.lg)
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .disabled(isLoading)
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLoading)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
    
    private func appleSignInAction() {
        isLoading = true
        HapticFeedbackManager.shared.mediumImpact()
        
        // Simulate Apple Sign In
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLoading = false
            HapticFeedbackManager.shared.success()
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                navigationManager.setRoot(to: .dashboard)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AuthView()
        .environmentObject(AppNavigationManager())
        .environmentObject(ThemeManager())
}
