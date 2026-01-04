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
    @State private var isSignInMode = false // Toggle between sign-up and sign-in
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var username = ""
    @State private var usernameError: String?
    @State private var fullName = ""
    @State private var email = ""
    @State private var showEmailVerification = false
    @State private var verificationEmail = ""
    @FocusState private var focusedField: AuthField?
    
    enum AuthField {
        case username
        case fullName
        case email
    }
    
    private let authService = SupabaseAuthService.shared
    
    
    var body: some View {
        ZStack {
            // Dark background
            Color(red: 0.129, green: 0.110, blue: 0.067) // #211c11
                .ignoresSafeArea()
            
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
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(AuthPalette.textPrimary)
                    
                    Text(isSignInMode ? "Please enter your email to sign in." : "Please enter your details to create an account.")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(AuthPalette.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                // Form Container
                VStack(spacing: 14) {
                    // Username Field (only in sign-up mode)
                    if !isSignInMode {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Username")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
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
                                .font(.system(size: 15, design: .rounded))
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
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(.red.opacity(0.9))
                            } else if !username.isEmpty {
                                Text("3-20 characters, letters, numbers, _ and - only")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(AuthPalette.textSecondary.opacity(0.7))
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    
                    // Full Name Field (only in sign-up mode)
                    if !isSignInMode {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Full Name")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(AuthPalette.textSecondary)
                            
                            TextField("Enter your full name", text: $fullName)
                                .font(.system(size: 15, design: .rounded))
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
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(AuthPalette.textSecondary)
                        
                        TextField("Enter your Email", text: $email)
                            .font(.system(size: 15, design: .rounded))
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
                    
                    // Send Email Code Button
                    Button {
                        HapticFeedbackManager.shared.mediumImpact()
                        handleSendEmailCode()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text(isSignInMode ? "Send sign in code" : "Send email code")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(AuthPalette.formBackground)
                        )
                    }
                    .disabled(isLoading || email.isEmpty || (!isSignInMode && (username.isEmpty || fullName.isEmpty)))
                    .opacity((email.isEmpty || (!isSignInMode && (username.isEmpty || fullName.isEmpty))) ? 0.5 : 1.0)
                    
                    // OR Divider
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(AuthPalette.textSecondary.opacity(0.3))
                            .frame(height: 1)
                        
                        Text("OR")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
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
                    } label: {
                        HStack(spacing: 4) {
                            Text(isSignInMode ? "Don't have an account?" : "Already have an account?")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(AuthPalette.textSecondary)
                            
                            Text(isSignInMode ? "Sign up" : "Sign in")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
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
        .navigationBarHidden(true)
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
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
    
    
    
    private func handleSendEmailCode() {
        guard !isLoading else { return }
        
        // Validate inputs
        if !isSignInMode && (username.isEmpty || fullName.isEmpty) {
            errorMessage = "Please fill in all fields"
            showError = true
            HapticFeedbackManager.shared.error()
            return
        }
        
        // Check username validity
        if !isSignInMode && usernameError != nil {
            errorMessage = usernameError
            showError = true
            HapticFeedbackManager.shared.error()
            return
        }
        
        if email.isEmpty {
            errorMessage = "Please enter your email"
            showError = true
            HapticFeedbackManager.shared.error()
            return
        }
        
        // Basic email format validation
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        if email.range(of: emailRegex, options: .regularExpression) == nil {
            errorMessage = "Please enter a valid email address"
            showError = true
            HapticFeedbackManager.shared.error()
            return
        }
        
        isLoading = true
        verificationEmail = email
        
        Task {
            // For sign-in mode, check if user exists and their auth provider
            if isSignInMode {
                let providerResult = await authService.checkUserProvider(email: email)
                if case .success(let info) = providerResult {
                    // If user exists and used OAuth (Google/Apple), prompt them to use that method
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
            }
            
            let result = await authService.sendOTP(
                email: email,
                shouldCreateUser: !isSignInMode,
                username: isSignInMode ? nil : username,
                fullName: isSignInMode ? nil : fullName
            )
            
            await MainActor.run {
                isLoading = false
                
                switch result {
                case .success:
                    HapticFeedbackManager.shared.success()
                    showEmailVerification = true
                    
                case .failure(let error):
                    HapticFeedbackManager.shared.error()
                    // Error is already mapped to user-friendly message via AuthErrorHandler
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
                .font(.system(size: 20, weight: .semibold))
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
                .font(.system(size: 20, weight: .medium))
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
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
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
    
    // Top: 0.235    0.188    0.078
    static let backgroundTop = Color(red: 0.235, green: 0.188, blue: 0.078)
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
                        .font(.system(size: 18, weight: .semibold))
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
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(AuthPalette.textPrimary)
                
                Text("Your semester, simplified.")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
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
                        .font(.system(size: 16, weight: .bold, design: .rounded))
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
                        .font(.system(size: 16, weight: .bold, design: .rounded))
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
                        .font(.system(size: 13, weight: .medium, design: .rounded))
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
                    .font(.system(size: 16, design: .rounded))
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
                            .font(.system(size: 16, design: .rounded))
                            .foregroundColor(AuthPalette.textPrimary)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    } else {
                        SecureField("Password", text: $password)
                            .font(.system(size: 16, design: .rounded))
                            .foregroundColor(AuthPalette.textPrimary)
                    }
                    
                    Button {
                        showPassword.toggle()
                        HapticFeedbackManager.shared.lightImpact()
                    } label: {
                        Image(systemName: showPassword ? "eye.fill" : "eye.slash.fill")
                            .font(.system(size: 16))
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
                                .font(.system(size: 16, design: .rounded))
                                .foregroundColor(AuthPalette.textPrimary)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("Confirm Password", text: $confirmPassword)
                                .font(.system(size: 16, design: .rounded))
                                .foregroundColor(AuthPalette.textPrimary)
                        }
                        
                        Button {
                            showConfirmPassword.toggle()
                            HapticFeedbackManager.shared.lightImpact()
                        } label: {
                            Image(systemName: showConfirmPassword ? "eye.fill" : "eye.slash.fill")
                                .font(.system(size: 16))
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
                                .font(.system(size: 16, weight: .bold, design: .rounded))
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
                            .font(.system(size: 14, weight: .regular, design: .rounded))
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
                    .font(.system(size: 16, weight: .medium))
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
    
    private let authService = SupabaseAuthService.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: Layout.Spacing.xl) {
                Spacer()
                
                VStack(spacing: Layout.Spacing.lg) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 60))
                        .foregroundColor(AuthPalette.appleGoldDark)
                    
                    Text("Verify Your Email")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(AuthPalette.textPrimary)
                    
                    Text("We sent a 6-digit code to")
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(AuthPalette.textSecondary)
                    
                    Text(email)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(AuthPalette.textPrimary)
                    
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
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
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
                .disabled(isLoading || verificationCode.count != 6)
                .opacity(verificationCode.count == 6 ? 1.0 : 0.6)
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
            .alert("Verification Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Invalid verification code")
            }
            .onAppear {
                // Focus will be handled by OTPInputView
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
                .font(.system(size: 24, weight: .bold, design: .rounded))
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
}
