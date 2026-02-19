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
    @State private var isSignInMode = true // Default to sign-in
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var username = ""
    @State private var usernameError: String?
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var passwordError: String?
    @State private var confirmPassword = ""
    @State private var confirmPasswordError: String?
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var showEmailVerification = false
    @State private var verificationEmail = ""
    @State private var showForgotPassword = false
    @FocusState private var focusedField: AuthField?
    
    enum AuthField {
        case username
        case fullName
        case email
        case password
        case confirmPassword
    }
    
    private let authService = SupabaseAuthService.shared
    
    
    var body: some View {
        ZStack {
            // Dark background
            Color(red: 0.129, green: 0.110, blue: 0.067) // #211c11
                .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    Spacer()
                        .frame(minHeight: 8, maxHeight: 24)
                    
                    // App Icon
                    Image("AppIconNewestBorders")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 125, height: 125)
                        .shadow(color: AuthPalette.primary.opacity(0.3), radius: 12, x: 0, y: 4)
                
                // Header
                VStack(spacing: 4) {
                    Text(isSignInMode ? "Welcome back" : "Create an account")
                        .font(.lexend(size: 26, weight: .bold))
                        .foregroundColor(AuthPalette.textPrimary)
                    
                    Text(isSignInMode ? "Please enter your email to sign in." : "Please enter your details to create an account.")
                        .font(.lexend(size: 14, weight: .regular))
                        .foregroundColor(AuthPalette.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                // Form Container
                VStack(spacing: 14) {
                    // Username Field (only in sign-up mode)
                    if !isSignInMode {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Username")
                                .font(.lexend(size: 13, weight: .medium))
                                .foregroundColor(AuthPalette.textSecondary)
                            
                            TextField("Choose a username", text: Binding(
                                get: { username },
                                set: { newValue in
                                    let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
                                    let filtered = newValue.filter { char in
                                        String(char).rangeOfCharacter(from: allowed) != nil
                                    }
                                    
                                    if filtered != username {
                                        username = filtered
                                        // Vibrate if characters were rejected (input length > filtered length) or just different
                                        if newValue.count > filtered.count {
                                            HapticFeedbackManager.shared.error()
                                        }
                                    }
                                    
                                    validateUsername(filtered)
                                }
                            ))
                                .font(.lexend(size: 15, weight: .regular))
                                .foregroundColor(AuthPalette.textPrimary)
                                .focused($focusedField, equals: .username)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(AuthPalette.inputBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(usernameError != nil ? Color.red.opacity(0.6) : Color.clear, lineWidth: 1)
                                        )
                                )
                            
                            // Error or hint text
                            if let error = usernameError {
                                Text(error)
                                    .font(.lexend(size: 12, weight: .regular))
                                    .foregroundColor(.red.opacity(0.9))
                            } else if !username.isEmpty {
                                Text("3-20 characters, letters, numbers, _ and - only")
                                    .font(.lexend(size: 12, weight: .regular))
                                    .foregroundColor(AuthPalette.textSecondary.opacity(0.7))
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    
                    // Full Name Field (only in sign-up mode)
                    if !isSignInMode {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Full Name")
                                .font(.lexend(size: 13, weight: .medium))
                                .foregroundColor(AuthPalette.textSecondary)
                            
                            TextField("Enter your full name", text: $fullName)
                                .font(.lexend(size: 15, weight: .regular))
                                .foregroundColor(AuthPalette.textPrimary)
                                .focused($focusedField, equals: .fullName)
                                .autocapitalization(.words)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(AuthPalette.inputBackground)
                                )
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // Email Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email")
                            .font(.lexend(size: 13, weight: .medium))
                            .foregroundColor(AuthPalette.textSecondary)
                        
                        TextField("Enter your Email", text: $email)
                            .font(.lexend(size: 15, weight: .regular))
                            .foregroundColor(AuthPalette.textPrimary)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(AuthPalette.inputBackground)
                            )
                    }
                    
                    // Password Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password")
                            .font(.lexend(size: 13, weight: .medium))
                            .foregroundColor(AuthPalette.textSecondary)
                        
                        HStack {
                            if showPassword {
                                TextField("Enter your password", text: Binding(
                                    get: { password },
                                    set: { newValue in
                                        password = newValue
                                        if !isSignInMode {
                                            validatePassword(newValue)
                                        }
                                    }
                                ))
                                    .font(.lexend(size: 15, weight: .regular))
                                    .foregroundColor(AuthPalette.textPrimary)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                            } else {
                                SecureField("Enter your password", text: Binding(
                                    get: { password },
                                    set: { newValue in
                                        password = newValue
                                        if !isSignInMode {
                                            validatePassword(newValue)
                                        }
                                    }
                                ))
                                    .font(.lexend(size: 15, weight: .regular))
                                    .foregroundColor(AuthPalette.textPrimary)
                            }
                            
                            Button {
                                showPassword.toggle()
                                HapticFeedbackManager.shared.lightImpact()
                            } label: {
                                Image(systemName: showPassword ? "eye.fill" : "eye.slash.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(AuthPalette.placeholderText)
                            }
                        }
                        .focused($focusedField, equals: .password)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(AuthPalette.inputBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(passwordError != nil && !isSignInMode ? Color.red.opacity(0.6) : Color.clear, lineWidth: 1)
                                )
                        )
                        
                        // Password requirements (sign-up only)
                        if !isSignInMode && !password.isEmpty {
                            if let error = passwordError {
                                Text(error)
                                    .font(.lexend(size: 12, weight: .regular))
                                    .foregroundColor(.red.opacity(0.9))
                            } else {
                                Text("✓ Password meets all requirements")
                                    .font(.lexend(size: 12, weight: .regular))
                                    .foregroundColor(.green.opacity(0.9))
                            }
                        }
                    }
                    
                    // Confirm Password Field (sign-up only)
                    if !isSignInMode {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Confirm Password")
                                .font(.lexend(size: 13, weight: .medium))
                                .foregroundColor(AuthPalette.textSecondary)
                            
                            HStack {
                                if showConfirmPassword {
                                    TextField("Confirm your password", text: Binding(
                                        get: { confirmPassword },
                                        set: { newValue in
                                            confirmPassword = newValue
                                            validateConfirmPassword(newValue)
                                        }
                                    ))
                                        .font(.lexend(size: 15, weight: .regular))
                                        .foregroundColor(AuthPalette.textPrimary)
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                } else {
                                    SecureField("Confirm your password", text: Binding(
                                        get: { confirmPassword },
                                        set: { newValue in
                                            confirmPassword = newValue
                                            validateConfirmPassword(newValue)
                                        }
                                    ))
                                        .font(.lexend(size: 15, weight: .regular))
                                        .foregroundColor(AuthPalette.textPrimary)
                                }
                                
                                Button {
                                    showConfirmPassword.toggle()
                                    HapticFeedbackManager.shared.lightImpact()
                                } label: {
                                    Image(systemName: showConfirmPassword ? "eye.fill" : "eye.slash.fill")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(AuthPalette.placeholderText)
                                }
                            }
                            .focused($focusedField, equals: .confirmPassword)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(AuthPalette.inputBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(confirmPasswordError != nil ? Color.red.opacity(0.6) : Color.clear, lineWidth: 1)
                                    )
                            )
                            
                            // Confirm password validation
                            if !confirmPassword.isEmpty {
                                if let error = confirmPasswordError {
                                    Text(error)
                                        .font(.lexend(size: 12, weight: .regular))
                                        .foregroundColor(.red.opacity(0.9))
                                } else if password == confirmPassword {
                                    Text("✓ Passwords match")
                                        .font(.lexend(size: 12, weight: .regular))
                                        .foregroundColor(.green.opacity(0.9))
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // Submit Button
                    Button {
                        HapticFeedbackManager.shared.mediumImpact()
                        handleSubmit()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text(isSignInMode ? "Sign In" : "Create Account")
                                    .font(.lexend(size: 15, weight: .bold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(isFormValid ? AuthPalette.primary : AuthPalette.formBackground)
                        )
                    }
                    .disabled(isLoading || !isFormValid)
                    .opacity(isFormValid ? 1.0 : 0.5)
                    
                    // Forgot Password (sign-in only)
                    if isSignInMode {
                        Button {
                            HapticFeedbackManager.shared.lightImpact()
                            showForgotPassword = true
                        } label: {
                            Text("Forgot Password?")
                                .font(.lexend(size: 13, weight: .regular))
                                .foregroundColor(AuthPalette.primary)
                                .underline()
                        }
                    }
                    
                    // OR Divider
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(AuthPalette.textSecondary.opacity(0.3))
                            .frame(height: 1)
                        
                        Text("OR")
                            .font(.lexend(size: 12, weight: .medium))
                            .foregroundColor(AuthPalette.textSecondary)
                        
                        Rectangle()
                            .fill(AuthPalette.textSecondary.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.vertical, 4)
                    
                    // Google Button
                    GoogleSignInButton {
                        handleGoogleTap()
                    }
                    
                    // Apple Button  
                    AppleSignInButton(isLoading: $isLoading) {
                        handleAppleTap()
                    }
                    
                    // Sign In / Sign Up Toggle
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSignInMode.toggle()
                        }
                        HapticFeedbackManager.shared.lightImpact()
                        
                        // Clear validation errors when switching modes
                        passwordError = nil
                        confirmPasswordError = nil
                        usernameError = nil
                        confirmPassword = ""
                    } label: {
                        HStack(spacing: 4) {
                            Text(isSignInMode ? "Don't have an account?" : "Already have an account?")
                                .font(.lexend(size: 13, weight: .regular))
                                .foregroundColor(AuthPalette.textSecondary)
                            
                            Text(isSignInMode ? "Sign up" : "Sign in")
                                .font(.lexend(size: 13, weight: .semibold))
                                .foregroundColor(AuthPalette.primary)
                                .underline()
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                
                Spacer()
                    .frame(minHeight: 8, maxHeight: 24)
            }
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
            }
        }
        .navigationBarHidden(true)
        .onTapGesture {
            // Dismiss keyboard when tapping outside
            focusedField = nil
        }
        .alert(isSignInMode ? "Sign In Failed" : "Sign Up Failed", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Something went wrong. Please try again.")
        }
        .sheet(isPresented: $showEmailVerification) {
            EmailVerificationView(
                email: verificationEmail,
                onVerified: {
                    showEmailVerification = false
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                        navigationManager.setRoot(to: .dashboard)
                    }
                },
                onDismiss: {
                    showEmailVerification = false
                }
            )
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(
                onDismiss: {
                    showForgotPassword = false
                }
            )
        }
    }
    
    private func handleAppleTap() {
        guard !isLoading else { return }
        
        isLoading = true
        HapticFeedbackManager.shared.mediumImpact()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isLoading = false
            HapticFeedbackManager.shared.success()
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                navigationManager.setRoot(to: .onboarding)
            }
        }
    }
    
    
    
    // MARK: - Form Validation
    
    private var isFormValid: Bool {
        guard !email.isEmpty, !password.isEmpty else { return false }
        
        if isSignInMode {
            return true
        } else {
            return !username.isEmpty &&
                   !fullName.isEmpty &&
                   usernameError == nil &&
                   passwordError == nil &&
                   confirmPasswordError == nil &&
                   password == confirmPassword
        }
    }
    
    // MARK: - Submit Handler
    
    private func handleSubmit() {
        guard !isLoading else { return }
        
        // Basic email format validation
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        if email.range(of: emailRegex, options: .regularExpression) == nil {
            errorMessage = "Please enter a valid email address"
            showError = true
            HapticFeedbackManager.shared.error()
            return
        }
        
        if isSignInMode {
            handleSignIn()
        } else {
            handleSignUp()
        }
    }
    
    // MARK: - Sign In (Password)
    
    private func handleSignIn() {
        isLoading = true
        
        Task {
            // Check if user signed up with OAuth
            let providerResult = await authService.checkUserProvider(email: email)
            if case .success(let info) = providerResult {
                if info.exists, let provider = info.provider, provider != .email {
                    await MainActor.run {
                        isLoading = false
                        HapticFeedbackManager.shared.error()
                        errorMessage = AuthError.oauthUserAttemptingEmail(provider: provider).localizedDescription
                        showError = true
                    }
                    return
                }
            }
            
            let result = await authService.signInWithPassword(email: email, password: password)
            
            await MainActor.run {
                isLoading = false
                
                switch result {
                case .success:
                    HapticFeedbackManager.shared.success()
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                        navigationManager.setRoot(to: .dashboard)
                    }
                    
                case .failure(let error):
                    HapticFeedbackManager.shared.error()
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    // MARK: - Sign Up (Password + OTP Confirmation)
    
    private func handleSignUp() {
        // Validate sign-up fields
        if username.isEmpty || fullName.isEmpty {
            errorMessage = "Please fill in all fields"
            showError = true
            HapticFeedbackManager.shared.error()
            return
        }
        
        if usernameError != nil {
            errorMessage = usernameError
            showError = true
            HapticFeedbackManager.shared.error()
            return
        }
        
        if passwordError != nil {
            errorMessage = passwordError
            showError = true
            HapticFeedbackManager.shared.error()
            return
        }
        
        if confirmPasswordError != nil {
            errorMessage = confirmPasswordError
            showError = true
            HapticFeedbackManager.shared.error()
            return
        }
        
        isLoading = true
        
        Task {
            // First check if user already exists
            print("🔍 Checking if email exists: \(email)")
            let providerResult = await authService.checkUserProvider(email: email)
            print("🔍 Provider check result: \(providerResult)")
            
            if case .success(let info) = providerResult {
                print("🔍 User exists: \(info.exists), Provider: \(String(describing: info.provider))")
                if info.exists {
                    print("⛔️ Email already exists - blocking signup")
                    await MainActor.run {
                        isLoading = false
                        HapticFeedbackManager.shared.error()
                        
                        // If user exists with OAuth, show specific message
                        if let provider = info.provider, provider != .email {
                            errorMessage = AuthError.oauthUserAttemptingEmail(provider: provider).localizedDescription
                        } else {
                            // User exists with email - show appropriate error
                            errorMessage = AuthError.emailAlreadyInUse.localizedDescription
                        }
                        showError = true
                    }
                    return
                }
            }
            
            print("✅ Email doesn't exist - proceeding with signup")
            
            // User doesn't exist, proceed with signup
            let result = await authService.signUpWithPassword(
                email: email,
                password: password,
                username: username,
                fullName: fullName
            )
            
            await MainActor.run {
                isLoading = false
                
                switch result {
                case .success:
                    HapticFeedbackManager.shared.success()
                    // Set email for verification screen
                    verificationEmail = email
                    // Show OTP verification sheet for email confirmation
                    showEmailVerification = true
                    
                case .failure(let error):
                    HapticFeedbackManager.shared.error()
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    

    
    private func handleGoogleTap() {
        guard !isLoading else { return }
        
        isLoading = true
        HapticFeedbackManager.shared.lightImpact()
        
        Task {
            let result = await authService.signInWithGoogle()
            
            await MainActor.run {
                isLoading = false
                
                switch result {
                case .success:
                    HapticFeedbackManager.shared.success()
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                        navigationManager.setRoot(to: .dashboard)
                    }
                    
                case .failure(let error):
                    HapticFeedbackManager.shared.error()
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Button Components

struct AppleSignInButton: View {
    @Binding var isLoading: Bool
    var action: () -> Void
    
    var body: some View {
        AuthButton(
            title: isLoading ? "Signing in..." : "Continue with Apple",
            textColor: .white,
            background: LinearGradient(
                colors: [AuthPalette.appleGoldLight, AuthPalette.appleGoldDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            borderColor: nil,
            shadowColor: AuthPalette.appleShadow,
            isLoading: isLoading,
            loadingTint: .white,
            action: action
        ) {
            Image(systemName: "applelogo")
                .font(.lexend(size: 20, weight: .semibold))
        }
        .disabled(isLoading)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isLoading)
    }
}

struct EmailSignInButton: View {
    var action: () -> Void
    
    var body: some View {
        AuthButton(
            title: "Continue with Email",
            textColor: AuthPalette.textPrimary,
            background: Color.white.opacity(0.1),
            borderColor: AuthPalette.creamBorder,
            shadowColor: AuthPalette.creamShadow,
            isLoading: false,
            loadingTint: AuthPalette.textPrimary,
            action: action
        ) {
            Image(systemName: "envelope.fill")
                .font(.lexend(size: 20, weight: .medium))
                .foregroundColor(AuthPalette.textSecondary)
        }
    }
}

struct GoogleSignInButton: View {
    var action: () -> Void
    
    var body: some View {
        AuthButton(
            title: "Continue with Google",
            textColor: AuthPalette.textPrimary,
            background: Color.white.opacity(0.1),
            borderColor: AuthPalette.creamBorder,
            shadowColor: AuthPalette.creamShadow,
            isLoading: false,
            loadingTint: AuthPalette.textPrimary,
            action: action
        ) {
            GoogleLogo()
                .frame(width: 24, height: 24)
        }
    }
}

struct AuthButton<Leading: View, Background: ShapeStyle>: View {
    let title: String
    let textColor: Color
    let background: Background
    let borderColor: Color?
    let shadowColor: Color
    var isLoading: Bool
    var loadingTint: Color
    var action: () -> Void
    @ViewBuilder var leading: () -> Leading
    @State private var isPressed = false
    
    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: Layout.Spacing.md) {
                Group {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: loadingTint))
                            .scaleEffect(0.8)
                    } else {
                        leading()
                    }
                }
                .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.lexend(size: 18, weight: .semibold))
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, Layout.Spacing.xxl)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(borderColor ?? .clear, lineWidth: borderColor == nil ? 0 : 1)
            )
            .shadow(color: shadowColor.opacity(0.28), radius: 18, x: 0, y: 14)
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
}

// MARK: - Decorative Elements (Legacy - Removed)

// MARK: - Decorative Elements

struct WarmGradientBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AuthPalette.backgroundTop,
                    AuthPalette.backgroundBottom
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

struct GrainOverlay: View {
    private static let samples: [NoiseSample] = {
        var generator = SeededGenerator(seed: 19712)
        return (0..<2600).map { _ in
            NoiseSample(
                x: CGFloat.random(in: 0...1, using: &generator),
                y: CGFloat.random(in: 0...1, using: &generator),
                opacity: Double.random(in: 0.04...0.12, using: &generator)
            )
        }
    }()
    
    var body: some View {
        Canvas { context, size in
            let pointSize = max(size.width, size.height) * 0.0045
            
            for sample in Self.samples {
                let rect = CGRect(
                    x: sample.x * size.width,
                    y: sample.y * size.height,
                    width: pointSize,
                    height: pointSize
                )
                
                context.fill(Path(rect), with: .color(Color.white.opacity(sample.opacity)))
            }
        }
        .blendMode(.overlay)
        .opacity(0.24)
        .allowsHitTesting(false)
    }
    
    private struct NoiseSample {
        let x: CGFloat
        let y: CGFloat
        let opacity: Double
    }
}

struct GoogleLogo: View {
    var body: some View {
        Image("GoogleLogo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 24, height: 24)
    }
}

// MARK: - Palette & Helpers

private enum AuthPalette {
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 0.85, green: 0.85, blue: 0.85)
    
    // Top: softened — was 0.235/0.188/0.078, now darker for a more subtle gradient
    static let backgroundTop = Color(red: 0.13, green: 0.105, blue: 0.045)
    // Bottom: 0.035    0.039    0.020
    static let backgroundBottom = Color(red: 0.035, green: 0.039, blue: 0.020)
    
    static let backgroundHighlight = Color(red: 1.0, green: 0.949, blue: 0.812)
    
    // Form-specific colors (from wireframe)
    static let formBackground = Color(red: 0.173, green: 0.153, blue: 0.118)    // #2c271e
    static let inputBackground = Color(red: 0.243, green: 0.216, blue: 0.169)   // #3e372b
    static let placeholderText = Color(red: 0.549, green: 0.510, blue: 0.451)   // #8c8273
    static let primary = Color(red: 0.824, green: 0.612, blue: 0.118)           // #d29c1e
    
    static let appleGoldLight = Color(red: 0.839, green: 0.690, blue: 0.215)   // #D6B157
    static let appleGoldDark = Color(red: 0.786, green: 0.612, blue: 0.200)    // #C89C38
    static let appleShadow = Color(red: 0.675, green: 0.525, blue: 0.157)
    
    static let creamBorder = Color.white.opacity(0.15)
    static let creamShadow = Color.clear
    
    static let shelfHighlight = Color.white.opacity(0.36)
    static let shelfShadow = Color(red: 0.478, green: 0.341, blue: 0.129)
    
}

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        self.state = seed
    }
    
    mutating func next() -> UInt64 {
        state = 6364136223846793005 &* state &+ 1
        return state
    }
}

// MARK: - Email Auth Form

enum AuthMode {
    case signUp
    case signIn
}

struct EmailAuthForm: View {
    @Binding var isSignUp: Bool
    @Binding var email: String
    @Binding var password: String
    @Binding var confirmPassword: String
    @Binding var firstName: String
    @Binding var lastName: String
    @Binding var isLoading: Bool
    @Binding var formError: String?
    @Binding var shakeAnimation: CGFloat
    let onBack: () -> Void
    let onSubmit: (AuthMode) async -> Void
    
    @FocusState private var focusedField: Field?
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    
    enum Field: Hashable {
        case email, password, confirmPassword
    }
    
    var body: some View {
        VStack(spacing: Layout.Spacing.lg) {
            // Header with title and back button
            HStack {
                Button {
                    HapticFeedbackManager.shared.lightImpact()
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.lexend(size: 18, weight: .semibold))
                        .foregroundColor(AuthPalette.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(AuthPalette.formBackground)
                        .clipShape(Circle())
                }
                
                Spacer()
            }
            
            // Title and subtitle
            VStack(spacing: Layout.Spacing.xs) {
                Text("Syllabus Sync")
                    .font(.lexend(size: 32, weight: .bold))
                    .foregroundColor(AuthPalette.textPrimary)
                
                Text("Your semester, simplified.")
                    .font(.lexend(size: 16, weight: .regular))
                    .foregroundColor(AuthPalette.textPrimary.opacity(0.9))
            }
            
            Spacer()
                .frame(height: Layout.Spacing.md)
            
            // Sign In / Sign Up Toggle - matches wireframe exactly
            HStack(spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isSignUp = false
                    }
                    HapticFeedbackManager.shared.lightImpact()
                } label: {
                    Text("Sign In")
                        .font(.lexend(size: 16, weight: .bold))
                        .foregroundColor(!isSignUp ? Color(red: 0.129, green: 0.110, blue: 0.067) : AuthPalette.textPrimary.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(!isSignUp ? AuthPalette.primary : Color.clear)
                        )
                }
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isSignUp = true
                    }
                    HapticFeedbackManager.shared.lightImpact()
                } label: {
                    Text("Sign Up")
                        .font(.lexend(size: 16, weight: .bold))
                        .foregroundColor(isSignUp ? Color(red: 0.129, green: 0.110, blue: 0.067) : AuthPalette.textPrimary.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(isSignUp ? AuthPalette.primary : Color.clear)
                        )
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(AuthPalette.formBackground)
                    .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
            )
            
            // Form Card
            VStack(spacing: Layout.Spacing.md) {
                // Error Message
                if let error = formError {
                    Text(error)
                        .font(.lexend(size: 13, weight: .medium))
                        .foregroundColor(Color(red: 0.851, green: 0.325, blue: 0.310))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(red: 0.851, green: 0.325, blue: 0.310).opacity(0.15))
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // Email Field
                TextField("Email Address", text: $email)
                    .font(.lexend(size: 16, weight: .regular))
                    .foregroundColor(AuthPalette.textPrimary)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(AuthPalette.inputBackground)
                    )
                
                // Password Field
                HStack {
                    if showPassword {
                        TextField("Password", text: $password)
                            .font(.lexend(size: 16, weight: .regular))
                            .foregroundColor(AuthPalette.textPrimary)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    } else {
                        SecureField("Password", text: $password)
                            .font(.lexend(size: 16, weight: .regular))
                            .foregroundColor(AuthPalette.textPrimary)
                    }
                    
                    Button {
                        showPassword.toggle()
                        HapticFeedbackManager.shared.lightImpact()
                    } label: {
                        Image(systemName: showPassword ? "eye.fill" : "eye.slash.fill")
                            .font(.lexend(size: 16, weight: .regular))
                            .foregroundColor(AuthPalette.placeholderText)
                    }
                }
                .focused($focusedField, equals: .password)
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(AuthPalette.inputBackground)
                )
                
                // Confirm Password (Sign Up only)
                if isSignUp {
                    HStack {
                        if showConfirmPassword {
                            TextField("Confirm Password", text: $confirmPassword)
                                .font(.lexend(size: 16, weight: .regular))
                                .foregroundColor(AuthPalette.textPrimary)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("Confirm Password", text: $confirmPassword)
                                .font(.lexend(size: 16, weight: .regular))
                                .foregroundColor(AuthPalette.textPrimary)
                        }
                        
                        Button {
                            showConfirmPassword.toggle()
                            HapticFeedbackManager.shared.lightImpact()
                        } label: {
                            Image(systemName: showConfirmPassword ? "eye.fill" : "eye.slash.fill")
                                .font(.lexend(size: 16, weight: .regular))
                                .foregroundColor(AuthPalette.placeholderText)
                        }
                    }
                    .focused($focusedField, equals: .confirmPassword)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(AuthPalette.inputBackground)
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // Submit Button
                Button {
                    HapticFeedbackManager.shared.mediumImpact()
                    Task {
                        await onSubmit(isSignUp ? .signUp : .signIn)
                    }
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.129, green: 0.110, blue: 0.067)))
                                .scaleEffect(0.8)
                        } else {
                            Text(isSignUp ? "Sign Up" : "Sign In")
                                .font(.lexend(size: 16, weight: .bold))
                        }
                    }
                    .foregroundColor(Color(red: 0.129, green: 0.110, blue: 0.067))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 32)
                            .fill(AuthPalette.primary)
                            .shadow(color: AuthPalette.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                }
                .disabled(isLoading || !isFormValid)
                .opacity(isFormValid ? 1.0 : 0.6)
                .padding(.top, Layout.Spacing.xs)
                
                // Forgot Password (Sign In only)
                if !isSignUp {
                    Button {
                        HapticFeedbackManager.shared.lightImpact()
                        // TODO: Implement forgot password flow
                    } label: {
                        Text("Forgot Password?")
                            .font(.lexend(size: 14, weight: .regular))
                            .foregroundColor(AuthPalette.primary)
                            .underline()
                    }
                    .padding(.top, Layout.Spacing.sm)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(AuthPalette.formBackground)
                    .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 6)
            )
            
            Spacer()
        }
        .padding(.horizontal, Layout.Spacing.lg)
        .offset(x: shakeAnimation)
        .animation(.easeInOut(duration: 0.2), value: isSignUp)
    }
    
    private var isFormValid: Bool {
        guard !email.isEmpty, !password.isEmpty else { return false }
        
        if isSignUp {
            return password.count >= 6 && password == confirmPassword
        } else {
            return true
        }
    }
}

struct EmailTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AuthPalette.creamBorder, lineWidth: 1)
            )
    }
}

// MARK: - Focused Text Field Style

struct FocusedTextFieldStyle: TextFieldStyle {
    let isFocused: Bool
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundColor(.white) // White text color for dark mode
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isFocused ? Color(red: 0.910, green: 0.769, blue: 0.424) : AuthPalette.creamBorder, // #E8C46C gold when focused
                        lineWidth: isFocused ? 2 : 1
                    )
                    .shadow(
                        color: isFocused ? Color(red: 0.910, green: 0.769, blue: 0.424).opacity(0.3) : .clear,
                        radius: isFocused ? 4 : 0
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Password Field With Toggle

struct PasswordFieldWithToggle: View {
    @Binding var text: String
    @Binding var isSecure: Bool
    let isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            if isSecure {
                SecureField("", text: $text)
                    .foregroundColor(.white)
            } else {
                TextField("", text: $text)
                    .foregroundColor(.white)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }
            
            Button {
                isSecure.toggle()
                HapticFeedbackManager.shared.lightImpact()
            } label: {
                Image(systemName: isSecure ? "eye.slash.fill" : "eye.fill")
                    .font(.lexend(size: 16, weight: .medium))
                    .foregroundColor(AuthPalette.textSecondary)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isFocused ? Color(red: 0.910, green: 0.769, blue: 0.424) : AuthPalette.creamBorder, // #E8C46C gold when focused
                    lineWidth: isFocused ? 2 : 1
                )
                .shadow(
                    color: isFocused ? Color(red: 0.910, green: 0.769, blue: 0.424).opacity(0.3) : .clear,
                    radius: isFocused ? 4 : 0
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Email Verification View

struct EmailVerificationView: View {
    let email: String
    let onVerified: () -> Void
    let onDismiss: () -> Void
    
    @State private var verificationCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var timeRemaining = 3000 // 50 minutes in seconds
    @State private var canResend = false
    @State private var isResending = false
    
    private let authService = SupabaseAuthService.shared
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationView {
            VStack(spacing: Layout.Spacing.xl) {
                Spacer()
                
                VStack(spacing: Layout.Spacing.lg) {
                    Image(systemName: "envelope.fill")
                        .font(.lexend(size: 60, weight: .regular))
                        .foregroundColor(AuthPalette.appleGoldDark)
                    
                    Text("Verify Your Email")
                        .font(.lexend(size: 28, weight: .bold))
                        .foregroundColor(AuthPalette.textPrimary)
                    
                    Text("We sent a 6-digit code to")
                        .font(.lexend(size: 16, weight: .regular))
                        .foregroundColor(AuthPalette.textSecondary)
                    
                    Text(email)
                        .font(.lexend(size: 16, weight: .semibold))
                        .foregroundColor(AuthPalette.textPrimary)
                    
                    // Countdown Timer
                    if timeRemaining > 0 {
                        Text("Code expires in \(formattedTime)")
                            .font(.lexend(size: 14, weight: .medium))
                            .foregroundColor(timeRemaining < 300 ? .red.opacity(0.9) : AuthPalette.textSecondary)
                            .padding(.top, 4)
                    } else {
                        Text("Code expired")
                            .font(.lexend(size: 14, weight: .medium))
                            .foregroundColor(.red.opacity(0.9))
                            .padding(.top, 4)
                    }
                    
                    // OTP Input
                    OTPInputView(code: $verificationCode)
                        .padding(.top, Layout.Spacing.lg)
                        .onChange(of: verificationCode) { oldValue, newValue in
                            if newValue.count == 6 {
                                Task {
                                    await verifyCode()
                                }
                            }
                        }
                    
                    // Resend OTP Button
                    Button {
                        HapticFeedbackManager.shared.lightImpact()
                        Task {
                            await resendOTP()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if isResending {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(AuthPalette.primary)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            Text(isResending ? "Sending..." : "Resend Code")
                                .font(.lexend(size: 14, weight: .semibold))
                        }
                        .foregroundColor(canResend ? AuthPalette.primary : AuthPalette.textSecondary.opacity(0.5))
                    }
                    .disabled(!canResend || isResending)
                    .padding(.top, 8)
                    
                    if isLoading {
                        ProgressView()
                            .padding(.top, Layout.Spacing.md)
                    }
                }
                .padding(.horizontal, Layout.Spacing.xxl)
                
                Spacer()
                
                Button {
                    Task {
                        await verifyCode()
                    }
                } label: {
                    Text("Verify")
                        .font(.lexend(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [AuthPalette.appleGoldLight, AuthPalette.appleGoldDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(28)
                        .shadow(color: AuthPalette.appleShadow.opacity(0.28), radius: 18, x: 0, y: 14)
                }
                .disabled(isLoading || verificationCode.count != 6 || timeRemaining <= 0)
                .opacity((verificationCode.count == 6 && timeRemaining > 0) ? 1.0 : 0.6)
                .padding(.horizontal, Layout.Spacing.xxl)
                .padding(.bottom, Layout.Spacing.xl)
            }
            .background(WarmGradientBackground().ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .foregroundColor(AuthPalette.textPrimary)
                }
            }
            .alert("Verification Failed", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Unable to verify code. Please try again.")
            }
            .onReceive(timer) { _ in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                }
                // Allow resending after 60 seconds
                if timeRemaining <= 2940 && !canResend {
                    canResend = true
                }
            }
            .onAppear {
                // Focus will be handled by OTPInputView
            }
        }
    }
    
    private var formattedTime: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func resendOTP() async {
        guard !isResending else { return }
        
        await MainActor.run {
            isResending = true
        }
        
        // Call resend OTP service
        let result = await authService.resendOTP(email: email)
        
        await MainActor.run {
            isResending = false
            
            switch result {
            case .success:
                HapticFeedbackManager.shared.success()
                // Reset timer
                timeRemaining = 3000
                canResend = false
                verificationCode = ""
                
            case .failure(let error):
                HapticFeedbackManager.shared.error()
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func verifyCode() async {
        guard verificationCode.count == 6 else { return }
        
        await MainActor.run {
            isLoading = true
        }
        
        // Use the authService verifyOTP method which handles username storage
        let result = await authService.verifyOTP(email: email, token: verificationCode)
        
        await MainActor.run {
            isLoading = false
            
            switch result {
            case .success:
                HapticFeedbackManager.shared.success()
                onVerified()
                
            case .failure(let error):
                HapticFeedbackManager.shared.error()
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - OTP Input View

struct OTPInputView: View {
    @Binding var code: String
    @FocusState private var isFocused: Bool
    
    private let digitCount = 6
    
    var body: some View {
        ZStack {
            // Hidden text field that captures all input
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .frame(width: 1, height: 1)
                .opacity(0.01) // Nearly invisible but still interactive
                .onChange(of: code) { oldValue, newValue in
                    // Only allow digits, max 6 characters
                    let filtered = String(newValue.filter { $0.isNumber }.prefix(digitCount))
                    if filtered != code {
                        code = filtered
                    }
                }
            
            // Visual digit boxes
            HStack(spacing: 12) {
                ForEach(0..<digitCount, id: \.self) { index in
                    DigitBox(
                        digit: digitAt(index),
                        isCurrent: isFocused && code.count == index,
                        isFilled: index < code.count
                    )
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = true
        }
        .onAppear {
            isFocused = true
        }
    }
    
    /// Returns the digit at the specified index, or empty string if not available
    private func digitAt(_ index: Int) -> String {
        guard index < code.count else { return "" }
        let stringIndex = code.index(code.startIndex, offsetBy: index)
        return String(code[stringIndex])
    }
}

/// Individual digit box component for OTP display
private struct DigitBox: View {
    let digit: String
    let isCurrent: Bool
    let isFilled: Bool
    
    var body: some View {
        ZStack {
            // Background box
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .frame(width: 50, height: 60)
            
            // Border
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: isCurrent ? 2 : 1)
                .frame(width: 50, height: 60)
            
            // Digit text
            Text(digit)
                .font(.lexend(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            // Cursor indicator when focused and empty
            if isCurrent && digit.isEmpty {
                Rectangle()
                    .fill(AuthPalette.appleGoldDark)
                    .frame(width: 2, height: 24)
                    .opacity(cursorOpacity)
            }
        }
    }
    
    private var borderColor: Color {
        if isCurrent {
            return AuthPalette.appleGoldDark
        } else if isFilled {
            return AuthPalette.appleGoldDark.opacity(0.5)
        } else {
            return AuthPalette.creamBorder
        }
    }
    
    @State private var cursorOpacity: Double = 1.0
}

// MARK: - Preview

#Preview {
    AuthView()
        .environmentObject(AppNavigationManager())
        .environmentObject(ThemeManager())
}

// MARK: - Forgot Password View

struct ForgotPasswordView: View {
    let onDismiss: () -> Void
    
    @State private var email = ""
    @State private var isLoading = false
    @State private var isSent = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    private let authService = SupabaseAuthService.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: Layout.Spacing.xl) {
                Spacer()
                
                VStack(spacing: Layout.Spacing.lg) {
                    Image(systemName: "lock.rotation")
                        .font(.system(size: 60, weight: .regular))
                        .foregroundColor(AuthPalette.appleGoldDark)
                    
                    Text("Reset Password")
                        .font(.lexend(size: 28, weight: .bold))
                        .foregroundColor(AuthPalette.textPrimary)
                    
                    if isSent {
                        // Success state
                        VStack(spacing: Layout.Spacing.md) {
                            Text("Check your email")
                                .font(.lexend(size: 16, weight: .medium))
                                .foregroundColor(AuthPalette.textPrimary)
                            
                            Text("We sent a password reset link to")
                                .font(.lexend(size: 14, weight: .regular))
                                .foregroundColor(AuthPalette.textSecondary)
                            
                            Text(email)
                                .font(.lexend(size: 14, weight: .semibold))
                                .foregroundColor(AuthPalette.primary)
                            
                            Text("Follow the link in the email to set a new password.")
                                .font(.lexend(size: 14, weight: .regular))
                                .foregroundColor(AuthPalette.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    } else {
                        // Input state
                        VStack(spacing: Layout.Spacing.md) {
                            Text("Enter the email address associated with your account and we'll send you a link to reset your password.")
                                .font(.lexend(size: 14, weight: .regular))
                                .foregroundColor(AuthPalette.textSecondary)
                                .multilineTextAlignment(.center)
                            
                            TextField("Email Address", text: $email)
                                .font(.lexend(size: 15, weight: .regular))
                                .foregroundColor(AuthPalette.textPrimary)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(AuthPalette.inputBackground)
                                )
                                .padding(.top, Layout.Spacing.sm)
                        }
                    }
                }
                .padding(.horizontal, Layout.Spacing.xxl)
                
                Spacer()
                
                if isSent {
                    Button {
                        onDismiss()
                    } label: {
                        Text("Back to Sign In")
                            .font(.lexend(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    colors: [AuthPalette.appleGoldLight, AuthPalette.appleGoldDark],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(28)
                            .shadow(color: AuthPalette.appleShadow.opacity(0.28), radius: 18, x: 0, y: 14)
                    }
                    .padding(.horizontal, Layout.Spacing.xxl)
                    .padding(.bottom, Layout.Spacing.xl)
                } else {
                    Button {
                        handleResetPassword()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("Send Reset Link")
                                    .font(.lexend(size: 18, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [AuthPalette.appleGoldLight, AuthPalette.appleGoldDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(28)
                        .shadow(color: AuthPalette.appleShadow.opacity(0.28), radius: 18, x: 0, y: 14)
                    }
                    .disabled(isLoading || email.isEmpty)
                    .opacity(email.isEmpty ? 0.6 : 1.0)
                    .padding(.horizontal, Layout.Spacing.xxl)
                    .padding(.bottom, Layout.Spacing.xl)
                }
            }
            .background(WarmGradientBackground().ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .foregroundColor(AuthPalette.textPrimary)
                }
            }
            .alert("Reset Failed", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Unable to send reset link. Please try again.")
            }
        }
    }
    
    private func handleResetPassword() {
        guard !isLoading else { return }
        
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        guard email.range(of: emailRegex, options: .regularExpression) != nil else {
            errorMessage = "Please enter a valid email address"
            showError = true
            HapticFeedbackManager.shared.error()
            return
        }
        
        isLoading = true
        
        Task {
            do {
                try await authService.resetPassword(email: email)
                await MainActor.run {
                    isLoading = false
                    HapticFeedbackManager.shared.success()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isSent = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    HapticFeedbackManager.shared.error()
                    errorMessage = "Failed to send reset email. Please try again."
                    showError = true
                }
            }
        }
    }
}

// Username validation function
extension AuthView {
    func validateUsername(_ value: String) {
        if value.isEmpty {
            usernameError = nil
            return
        }
        
        if value.count < 3 {
            usernameError = "Username must be at least 3 characters"
            return
        }
        
        if value.count > 20 {
            usernameError = "Username must be 20 characters or less"
            return
        }
        
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
        if value.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            usernameError = "Only letters, numbers, _ and - allowed"
            return
        }
        
        usernameError = nil
    }
    
    func validatePassword(_ value: String) {
        if value.isEmpty {
            passwordError = nil
            return
        }
        
        // Minimum 6 characters (as per Supabase config)
        if value.count < 6 {
            passwordError = "Password must be at least 6 characters"
            return
        }
        
        // Check for lowercase letter
        let hasLowercase = value.rangeOfCharacter(from: CharacterSet.lowercaseLetters) != nil
        if !hasLowercase {
            passwordError = "Password must contain a lowercase letter"
            return
        }
        
        // Check for uppercase letter
        let hasUppercase = value.rangeOfCharacter(from: CharacterSet.uppercaseLetters) != nil
        if !hasUppercase {
            passwordError = "Password must contain an uppercase letter"
            return
        }
        
        // Check for digit
        let hasDigit = value.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil
        if !hasDigit {
            passwordError = "Password must contain a digit"
            return
        }
        
        // All requirements met
        passwordError = nil
    }
    
    func validateConfirmPassword(_ value: String) {
        if value.isEmpty {
            confirmPasswordError = nil
            return
        }
        
        if value != password {
            confirmPasswordError = "Passwords do not match"
            return
        }
        
        confirmPasswordError = nil
    }
}
