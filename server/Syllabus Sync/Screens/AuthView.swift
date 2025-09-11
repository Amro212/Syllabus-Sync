//
//  AuthView.swift
//  Syllabus Sync
//
//  Created by Assistant on 2024-01-01.
//

import SwiftUI

struct AuthView: View {
    @EnvironmentObject var navigationManager: AppNavigationManager
    @State private var selectedTab: AuthTab = .login
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                AuthHeaderView()
                
                // Tab Selector
                AuthTabSelector(selectedTab: $selectedTab)
                    .padding(.horizontal, Layout.Spacing.lg)
                
                // Content
                TabView(selection: $selectedTab) {
                    LoginView(isLoading: $isLoading)
                        .tag(AuthTab.login)
                    
                    SignUpView(isLoading: $isLoading)
                        .tag(AuthTab.signUp)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: selectedTab)
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .disabled(isLoading)
    }
}

// MARK: - Supporting Types

enum AuthTab: CaseIterable {
    case login
    case signUp
    
    var title: String {
        switch self {
        case .login: return "Login"
        case .signUp: return "Sign Up"
        }
    }
}

// MARK: - Auth Header

struct AuthHeaderView: View {
    var body: some View {
        VStack(spacing: Layout.Spacing.lg) {
            // App Icon
            Image("SyllabusIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
            
            VStack(spacing: Layout.Spacing.sm) {
                Text("Welcome to Syllabus Sync")
                    .font(.titleL)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Sign in to sync your academic life")
                    .font(.body)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, Layout.Spacing.xxl)
        .padding(.bottom, Layout.Spacing.xl)
        .padding(.horizontal, Layout.Spacing.lg)
    }
}

// MARK: - Tab Selector

struct AuthTabSelector: View {
    @Binding var selectedTab: AuthTab
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(AuthTab.allCases, id: \.self) { tab in
                Button(action: {
                    HapticFeedbackManager.shared.lightImpact()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: Layout.Spacing.sm) {
                        Text(tab.title)
                            .font(.body)
                            .fontWeight(selectedTab == tab ? .semibold : .medium)
                            .foregroundColor(selectedTab == tab ? AppColors.accent : AppColors.textSecondary)
                        
                        Rectangle()
                            .fill(selectedTab == tab ? AppColors.accent : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(
            Rectangle()
                .fill(AppColors.separator)
                .frame(height: 1)
                .offset(y: 20)
        )
        .padding(.bottom, Layout.Spacing.lg)
    }
}

// MARK: - Login View

struct LoginView: View {
    @EnvironmentObject var navigationManager: AppNavigationManager
    @Binding var isLoading: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var emailError: String?
    @State private var passwordError: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: Layout.Spacing.xl) {
                VStack(spacing: Layout.Spacing.lg) {
                    // Apple Sign In Button (Mock)
                    AppleSignInButton(isLoading: $isLoading)
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .fill(AppColors.separator)
                            .frame(height: 1)
                        
                        Text("or")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                            .padding(.horizontal, Layout.Spacing.md)
                        
                        Rectangle()
                            .fill(AppColors.separator)
                            .frame(height: 1)
                    }
                }
                
                // Form Fields
                VStack(spacing: Layout.Spacing.lg) {
                    AuthTextField(
                        title: "Email",
                        text: $email,
                        placeholder: "Enter your email",
                        keyboardType: .emailAddress,
                        autocapitalization: .never,
                        error: emailError
                    )
                    .onChange(of: email) { _ in
                        validateEmail()
                    }
                    
                    AuthTextField(
                        title: "Password",
                        text: $password,
                        placeholder: "Enter your password",
                        isSecure: true,
                        error: passwordError
                    )
                    .onChange(of: password) { _ in
                        validatePassword()
                    }
                }
                
                // Forgot Password
                HStack {
                    Spacer()
                    Button("Forgot Password?") {
                        HapticFeedbackManager.shared.lightImpact()
                        // Mock forgot password action
                    }
                    .font(.caption)
                    .foregroundColor(AppColors.accent)
                }
                
                // Login Button
                VStack(spacing: Layout.Spacing.md) {
                    PrimaryCTAButton(isLoading ? "Logging in..." : "Log In") {
                        loginAction()
                    }
                    .disabled(!isValidForm || isLoading)
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                            .scaleEffect(0.8)
                    }
                }
            }
            .padding(.horizontal, Layout.Spacing.lg)
            .padding(.vertical, Layout.Spacing.xl)
        }
    }
    
    private var isValidForm: Bool {
        !email.isEmpty && !password.isEmpty && emailError == nil && passwordError == nil
    }
    
    private func validateEmail() {
        if email.isEmpty {
            emailError = nil
        } else if !email.contains("@") || !email.contains(".") {
            emailError = "Please enter a valid email address"
        } else {
            emailError = nil
        }
    }
    
    private func validatePassword() {
        if password.isEmpty {
            passwordError = nil
        } else if password.count < 6 {
            passwordError = "Password must be at least 6 characters"
        } else {
            passwordError = nil
        }
    }
    
    private func loginAction() {
        // Final validation
        validateEmail()
        validatePassword()
        
        guard isValidForm else { return }
        
        isLoading = true
        HapticFeedbackManager.shared.lightImpact()
        
        // Simulate login process
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isLoading = false
            HapticFeedbackManager.shared.success()
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                navigationManager.setRoot(to: .dashboard)
            }
        }
    }
}

// MARK: - Sign Up View

struct SignUpView: View {
    @EnvironmentObject var navigationManager: AppNavigationManager
    @Binding var isLoading: Bool
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var emailError: String?
    @State private var passwordError: String?
    @State private var confirmPasswordError: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: Layout.Spacing.xl) {
                VStack(spacing: Layout.Spacing.lg) {
                    // Apple Sign In Button (Mock)
                    AppleSignInButton(isLoading: $isLoading)
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .fill(AppColors.separator)
                            .frame(height: 1)
                        
                        Text("or create account")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                            .padding(.horizontal, Layout.Spacing.md)
                        
                        Rectangle()
                            .fill(AppColors.separator)
                            .frame(height: 1)
                    }
                }
                
                // Form Fields
                VStack(spacing: Layout.Spacing.lg) {
                    HStack(spacing: Layout.Spacing.md) {
                        AuthTextField(
                            title: "First Name",
                            text: $firstName,
                            placeholder: "First"
                        )
                        
                        AuthTextField(
                            title: "Last Name",
                            text: $lastName,
                            placeholder: "Last"
                        )
                    }
                    
                    AuthTextField(
                        title: "Email",
                        text: $email,
                        placeholder: "Enter your email",
                        keyboardType: .emailAddress,
                        autocapitalization: .never,
                        error: emailError
                    )
                    .onChange(of: email) { _ in
                        validateEmail()
                    }
                    
                    AuthTextField(
                        title: "Password",
                        text: $password,
                        placeholder: "Create a password",
                        isSecure: true,
                        error: passwordError
                    )
                    .onChange(of: password) { _ in
                        validatePassword()
                        validateConfirmPassword()
                    }
                    
                    AuthTextField(
                        title: "Confirm Password",
                        text: $confirmPassword,
                        placeholder: "Confirm your password",
                        isSecure: true,
                        error: confirmPasswordError
                    )
                    .onChange(of: confirmPassword) { _ in
                        validateConfirmPassword()
                    }
                }
                
                // Terms and Conditions
                VStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        Text("By signing up, you agree to our ")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                        
                        Button("Terms of Service") {
                            // Mock terms action
                        }
                        .font(.caption)
                        .foregroundColor(AppColors.accent)
                        
                        Text(" and ")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                        
                        Button("Privacy Policy") {
                            // Mock privacy action
                        }
                        .font(.caption)
                        .foregroundColor(AppColors.accent)
                    }
                }
                
                // Sign Up Button
                VStack(spacing: Layout.Spacing.md) {
                    PrimaryCTAButton(isLoading ? "Creating Account..." : "Create Account") {
                        signUpAction()
                    }
                    .disabled(!isValidForm || isLoading)
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                            .scaleEffect(0.8)
                    }
                }
            }
            .padding(.horizontal, Layout.Spacing.lg)
            .padding(.vertical, Layout.Spacing.xl)
        }
    }
    
    private var isValidForm: Bool {
        !firstName.isEmpty && !lastName.isEmpty && !email.isEmpty && 
        !password.isEmpty && !confirmPassword.isEmpty && 
        emailError == nil && passwordError == nil && confirmPasswordError == nil
    }
    
    private func validateEmail() {
        if email.isEmpty {
            emailError = nil
        } else if !email.contains("@") || !email.contains(".") {
            emailError = "Please enter a valid email address"
        } else {
            emailError = nil
        }
    }
    
    private func validatePassword() {
        if password.isEmpty {
            passwordError = nil
        } else if password.count < 8 {
            passwordError = "Password must be at least 8 characters"
        } else {
            passwordError = nil
        }
    }
    
    private func validateConfirmPassword() {
        if confirmPassword.isEmpty {
            confirmPasswordError = nil
        } else if confirmPassword != password {
            confirmPasswordError = "Passwords do not match"
        } else {
            confirmPasswordError = nil
        }
    }
    
    private func signUpAction() {
        // Final validation
        validateEmail()
        validatePassword()
        validateConfirmPassword()
        
        guard isValidForm else { return }
        
        isLoading = true
        HapticFeedbackManager.shared.lightImpact()
        
        // Simulate sign up process
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            isLoading = false
            HapticFeedbackManager.shared.success()
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                navigationManager.setRoot(to: .dashboard)
            }
        }
    }
}

// MARK: - Apple Sign In Button

struct AppleSignInButton: View {
    @EnvironmentObject var navigationManager: AppNavigationManager
    @Binding var isLoading: Bool
    
    var body: some View {
        Button(action: appleSignInAction) {
            HStack(spacing: Layout.Spacing.md) {
                Image(systemName: "applelogo")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                
                Text("Continue with Apple")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.black)
            .cornerRadius(Layout.CornerRadius.md)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.7 : 1.0)
    }
    
    private func appleSignInAction() {
        isLoading = true
        HapticFeedbackManager.shared.lightImpact()
        
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

// MARK: - Auth Text Field

struct AuthTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .words
    var isSecure: Bool = false
    var error: String?
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)
            
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .focused($isFocused)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(autocapitalization)
                        .focused($isFocused)
                }
            }
            .font(.body)
            .foregroundColor(AppColors.textPrimary)
            .padding(Layout.Spacing.md)
            .background(AppColors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.CornerRadius.sm)
                    .stroke(
                        error != nil ? AppColors.error : 
                        (isFocused ? AppColors.accent : AppColors.border),
                        lineWidth: error != nil ? 2 : 1
                    )
            )
            .cornerRadius(Layout.CornerRadius.sm)
            
            if let error = error {
                HStack(spacing: Layout.Spacing.xs) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(AppColors.error)
                    
                    Text(error)
                        .font(.caption)
                        .foregroundColor(AppColors.error)
                }
                .transition(.slide.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: error)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFocused)
    }
}

// MARK: - Preview

#Preview {
    AuthView()
        .environmentObject(AppNavigationManager())
        .environmentObject(ThemeManager())
}
