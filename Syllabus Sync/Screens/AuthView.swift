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
    @State private var contentAppeared = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showEmailForm = false
    @State private var isSignUp = true // Toggle between sign up and sign in
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var showEmailVerification = false
    @State private var verificationCode = ""
    @State private var verificationEmail = ""
    @State private var formError: String? = nil
    @State private var shakeAnimation: CGFloat = 0
    
    private let authService = SupabaseAuthService.shared
    
    var body: some View {
        GeometryReader { proxy in
            let safeBottom = proxy.safeAreaInsets.bottom
            let shelfHeight = proxy.size.height * 0.23   // Adjust independently
            let shelfOffset = safeBottom * 0.3           // Control vertical placement of shelf
            let booksHeight = proxy.size.height * 0.35   // Separate height for books
            let booksOffset = shelfHeight * 0.10          // Adjust how far above the shelf books appear

            
            ZStack(alignment: .bottom) {
                WarmGradientBackground()
                    .ignoresSafeArea()
                    .overlay(
                        GrainOverlay()
                            .ignoresSafeArea()
                    )
                
                // ShelfSurface: snug at bottom, slightly lower for perfect fit
                ShelfSurface()
                    .frame(height: shelfHeight)
                    .frame(maxWidth: .infinity)
                    .ignoresSafeArea(edges: .bottom)
                    .allowsHitTesting(false)
                    .offset(y: safeBottom * 1.0) // lower shelf slightly for snug bottom fit
                
                VStack(spacing: 0) {
                    if showEmailForm {
                        // Email form at the top - maximize space
                        Spacer()
                            .frame(height: Layout.Spacing.xl)
                        
                        EmailAuthForm(
                            isSignUp: $isSignUp,
                            email: $email,
                            password: $password,
                            confirmPassword: $confirmPassword,
                            firstName: $firstName,
                            lastName: $lastName,
                            isLoading: $isLoading,
                            formError: $formError,
                            shakeAnimation: $shakeAnimation,
                            onBack: {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    showEmailForm = false
                                }
                            },
                            onSubmit: { mode in
                                formError = nil
                                if mode == .signUp {
                                    await handleSignUp()
                                } else {
                                    await handleSignIn()
                                }
                            }
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        
                        Spacer()
                    } else {
                        // Original layout for main auth screen
                        Spacer()
                            .frame(height: Layout.Spacing.massive + Layout.Spacing.lg)
                        
                        VStack(spacing: Layout.Spacing.md) {
                            Text("Welcome to Syllabus Sync")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundColor(AuthPalette.textPrimary)
                                .multilineTextAlignment(.center)
                            
                            Text("Your courses, labs, and deadlines — all synced in one place")
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(AuthPalette.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.horizontal, Layout.Spacing.xxl)
                        }
                        .opacity(showEmailForm ? 0.0 : (contentAppeared ? 1.0 : 0.0))
                        .offset(y: contentAppeared ? 0 : 24)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showEmailForm)
                        
                        Spacer()
                            .frame(height: Layout.Spacing.xxxl)
                        
                        VStack(spacing: Layout.Spacing.md) {
                            AppleSignInButton(isLoading: $isLoading) {
                                handleAppleTap()
                            }
                            
                            EmailSignInButton {
                                handleEmailTap()
                            }
                            
                            GoogleSignInButton {
                                handleGoogleTap()
                            }
                        }
                        .opacity(showEmailForm ? 0.0 : (contentAppeared ? 1.0 : 0.0))
                        .offset(y: contentAppeared ? 0 : 28)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showEmailForm)
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, Layout.Spacing.xxl)
                
                // BooksIllustrationView: sits flush with shelf, with shadow and animation
                // Visible for Sign In, fade out for Sign Up
                BooksIllustrationView(height: booksHeight)
                    .padding(.horizontal, Layout.Spacing.lg)
                    .offset(y: -booksOffset) // Move up independently from shelf
                    .opacity(showEmailForm && isSignUp ? 0.0 : (contentAppeared ? 1.0 : 0.0))
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    .animation(.spring(response: 0.8, dampingFraction: 0.9), value: contentAppeared)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isSignUp)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
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
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
                contentAppeared = true
            }
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
    
    private func handleEmailTap() {
        HapticFeedbackManager.shared.lightImpact()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isSignUp = false // Force Sign In tab
            showEmailForm = true
        }
    }
    
    private func handleSignUp() async {
        // Validate password requirements
        guard validatePassword(password) else {
            await MainActor.run {
                errorMessage = "Password must be at least 6 characters and contain uppercase, lowercase letters, and digits"
                showError = true
            }
            return
        }
        
        guard password == confirmPassword else {
            await MainActor.run {
                errorMessage = "Passwords do not match"
                showError = true
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        let result = await authService.signUpWithEmail(
            email: email,
            password: password,
            firstName: firstName.isEmpty ? nil : firstName,
            lastName: lastName.isEmpty ? nil : lastName
        )
        
        await MainActor.run {
            isLoading = false
            
            switch result {
            case .success:
                HapticFeedbackManager.shared.success()
                // Show email verification screen
                verificationEmail = email
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showEmailVerification = true
                }
                
            case .failure(let error):
                HapticFeedbackManager.shared.error()
                errorMessage = error.localizedDescription
                showError = true
                formError = error.localizedDescription
                triggerShakeAnimation()
            }
        }
    }
    
    private func handleSignIn() async {
        await MainActor.run {
            isLoading = true
        }
        
        let result = await authService.signInWithEmail(email: email, password: password)
        
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
                    formError = error.localizedDescription
                    triggerShakeAnimation()
            }
        }
    }
    
    private func triggerShakeAnimation() {
        withAnimation(.linear(duration: 0.05).repeatCount(4, autoreverses: true)) {
            shakeAnimation = 10
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            shakeAnimation = 0
        }
    }
    
    private func validatePassword(_ password: String) -> Bool {
        // Minimum 6 characters
        guard password.count >= 6 else { return false }
        
        // Must contain lowercase, uppercase, and digits
        let hasLowercase = password.rangeOfCharacter(from: CharacterSet.lowercaseLetters) != nil
        let hasUppercase = password.rangeOfCharacter(from: CharacterSet.uppercaseLetters) != nil
        let hasDigits = password.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil
        
        return hasLowercase && hasUppercase && hasDigits
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

// MARK: - Illustration

struct BooksIllustrationView: View {
    let height: CGFloat
    
    var body: some View {
        Image("BooksIllustration")
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .shadow(color: Color.black.opacity(0.16), radius: 26, x: 0, y: 20)
    }
}

struct ShelfSurface: View {
    var body: some View {
        Rectangle()
            .fill(Color(red: 0.786, green: 0.612, blue: 0.200))
            .overlay(
                Rectangle()
                    .stroke(AuthPalette.shelfHighlight, lineWidth: 1)
                    .blendMode(.screen)
                    .opacity(0.45)
            )
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(.vertical, 2)
            )
            .shadow(color: AuthPalette.shelfShadow.opacity(0.25), radius: 20, x: 0, y: 8)
    }
}

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
        case email, password, confirmPassword, firstName, lastName
    }
    
    var body: some View {
        VStack(spacing: Layout.Spacing.md) {
            // Back button
            HStack {
                Button {
                    HapticFeedbackManager.shared.lightImpact()
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AuthPalette.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.3))
                        .clipShape(Circle())
                }
                Spacer()
            }
            
            // Title
            Text(isSignUp ? "Create Account" : "Sign In")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(AuthPalette.textPrimary)
            
            // Toggle between sign up and sign in
            HStack(spacing: 6) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isSignUp = true
                    }
                    HapticFeedbackManager.shared.lightImpact()
                } label: {
                    Text("Sign Up")
                        .font(.system(size: 17, weight: isSignUp ? .bold : .medium, design: .rounded))
                        .foregroundColor(isSignUp ? Color.black : AuthPalette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSignUp ? Color.white.opacity(0.8) : Color.clear)
                                .shadow(color: isSignUp ? Color.black.opacity(0.1) : .clear, radius: 4, x: 0, y: 2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSignUp ? AuthPalette.appleGoldDark.opacity(0.5) : Color.clear, lineWidth: isSignUp ? 1.5 : 0)
                        )
                }
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isSignUp = false
                    }
                    HapticFeedbackManager.shared.lightImpact()
                } label: {
                    Text("Sign In")
                        .font(.system(size: 17, weight: !isSignUp ? .bold : .medium, design: .rounded))
                        .foregroundColor(!isSignUp ? Color.black : AuthPalette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(!isSignUp ? Color.white.opacity(0.8) : Color.clear)
                                .shadow(color: !isSignUp ? Color.black.opacity(0.1) : .clear, radius: 4, x: 0, y: 2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(!isSignUp ? AuthPalette.appleGoldDark.opacity(0.5) : Color.clear, lineWidth: !isSignUp ? 1.5 : 0)
                        )
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AuthPalette.creamBorder.opacity(0.6), lineWidth: 1)
                    )
            )
            
            ScrollView {
                VStack(spacing: Layout.Spacing.sm) {
                    // Error Message
                    if let error = formError {
                        Text(error)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(Color(red: 0.851, green: 0.325, blue: 0.310)) // #D9534F
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(red: 0.851, green: 0.325, blue: 0.310).opacity(0.1))
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // First Name & Last Name (Sign Up only)
                    if isSignUp {
                        HStack(spacing: Layout.Spacing.md) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("First Name")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(AuthPalette.textSecondary)
                                TextField("", text: $firstName)
                                    .textFieldStyle(FocusedTextFieldStyle(isFocused: focusedField == .firstName))
                                    .focused($focusedField, equals: .firstName)
                                    .autocapitalization(.words)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Last Name")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(AuthPalette.textSecondary)
                                TextField("", text: $lastName)
                                    .textFieldStyle(FocusedTextFieldStyle(isFocused: focusedField == .lastName))
                                    .focused($focusedField, equals: .lastName)
                                    .autocapitalization(.words)
                            }
                        }
                    }
                    
                    // Email
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(AuthPalette.textSecondary)
                        TextField("", text: $email)
                            .textFieldStyle(FocusedTextFieldStyle(isFocused: focusedField == .email))
                            .focused($focusedField, equals: .email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                    
                    // Password
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(AuthPalette.textSecondary)
                        
                        PasswordFieldWithToggle(
                            text: $password,
                            isSecure: $showPassword,
                            isFocused: focusedField == .password
                        )
                        .focused($focusedField, equals: .password)
                        
                        if isSignUp {
                            Text("At least 6 characters with uppercase, lowercase, and digits")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(AuthPalette.textSecondary.opacity(0.7))
                                .padding(.top, 2)
                        }
                    }
                    
                    // Confirm Password (Sign Up only)
                    if isSignUp {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Confirm Password")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(AuthPalette.textSecondary)
                            
                            PasswordFieldWithToggle(
                                text: $confirmPassword,
                                isSecure: $showConfirmPassword,
                                isFocused: focusedField == .confirmPassword
                            )
                            .focused($focusedField, equals: .confirmPassword)
                        }
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
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text(isSignUp ? "Create Account" : "Sign In")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
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
                    .disabled(isLoading || !isFormValid)
                    .opacity(isFormValid ? 1.0 : 0.6)
                    .padding(.top, Layout.Spacing.sm)
                    .padding(.bottom, Layout.Spacing.xxl)
                }
                .padding(.top, Layout.Spacing.xs)
            }
        }
        .padding(.horizontal, Layout.Spacing.xxl)
        .offset(x: shakeAnimation)
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
        
        // Verify OTP with Supabase
        do {
            let session = try await authService.supabase.auth.verifyOTP(
                email: email,
                token: verificationCode,
                type: .email
            )
            
            await MainActor.run {
                isLoading = false
                
                if session.user != nil {
                    // Update auth service user
                    let user = AuthUser(
                        id: session.user.id.uuidString,
                        email: session.user.email,
                        displayName: session.user.userMetadata["full_name"]?.value as? String,
                        photoURL: nil,
                        provider: .email
                    )
                    authService.currentUser = user
                    
                    HapticFeedbackManager.shared.success()
                    onVerified()
                } else {
                    errorMessage = "Verification failed. Please try again."
                    showError = true
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - OTP Input View

struct OTPInputView: View {
    @Binding var code: String
    
    @State private var digits: [String] = Array(repeating: "", count: 6)
    @FocusState private var focusedIndex: Int?
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<6, id: \.self) { index in
                TextField("", text: $digits[index])
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .frame(width: 50, height: 60)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(focusedIndex == index ? AuthPalette.appleGoldDark : AuthPalette.creamBorder, lineWidth: focusedIndex == index ? 2 : 1)
                    )
                    .focused($focusedIndex, equals: index)
                    .onChange(of: digits[index]) { oldValue, newValue in
                        // Only allow digits, max 1 character
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered.count > 1 {
                            digits[index] = String(filtered.prefix(1))
                        } else {
                            digits[index] = filtered
                        }
                        
                        // Update code string
                        code = digits.joined()
                        
                        // Move to next field if digit entered
                        if !digits[index].isEmpty && index < 5 {
                            focusedIndex = index + 1
                        }
                    }
            }
        }
        .onAppear {
            focusedIndex = 0
        }
        .onChange(of: code) { newCode in
            // Sync code back to digits array
            for (index, char) in newCode.enumerated() {
                if index < 6 {
                    digits[index] = String(char)
                }
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
