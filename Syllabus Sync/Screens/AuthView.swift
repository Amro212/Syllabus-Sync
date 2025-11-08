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
                    .opacity(contentAppeared ? 1.0 : 0.0)
                    .offset(y: contentAppeared ? 0 : 24)
                    
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
                    .opacity(contentAppeared ? 1.0 : 0.0)
                    .offset(y: contentAppeared ? 0 : 28)
                    
                    Spacer()
                }
                .padding(.horizontal, Layout.Spacing.xxl)
                
                // BooksIllustrationView: sits flush with shelf, with shadow and animation
                
                BooksIllustrationView(height: booksHeight)
                    .padding(.horizontal, Layout.Spacing.lg)
                    .offset(y: -booksOffset) // Move up independently from shelf
                    .opacity(contentAppeared ? 1.0 : 0.0)
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    .animation(.spring(response: 0.8, dampingFraction: 0.9), value: contentAppeared)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .navigationBarHidden(true)
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
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
        // TODO: Navigate to email/password form
        // For now, navigate to onboarding
        withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
            navigationManager.setRoot(to: .onboarding)
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
            background: Color.white.opacity(0.72),
            borderColor: AuthPalette.creamBorder,
            shadowColor: AuthPalette.creamShadow,
            isLoading: false,
            loadingTint: AuthPalette.textPrimary,
            action: action
        ) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(AuthPalette.textPrimary)
        }
    }
}

struct GoogleSignInButton: View {
    var action: () -> Void
    
    var body: some View {
        AuthButton(
            title: "Continue with Google",
            textColor: AuthPalette.textPrimary,
            background: Color.white.opacity(0.75),
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
                    AuthPalette.backgroundMid,
                    AuthPalette.backgroundBottom
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            RadialGradient(
                gradient: Gradient(colors: [AuthPalette.backgroundHighlight.opacity(0.35), .clear]),
                center: .topLeading,
                startRadius: 0,
                endRadius: 420
            )
            .blendMode(.plusLighter)
            
            RadialGradient(
                gradient: Gradient(colors: [AuthPalette.backgroundHighlight.opacity(0.28), .clear]),
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 480
            )
            .blendMode(.screen)
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
    static let textPrimary = Color(red: 0.353, green: 0.266, blue: 0.133)      // Deep brown
    static let textSecondary = Color(red: 0.522, green: 0.413, blue: 0.220)    // Warm taupe
    
    static let backgroundTop = Color(red: 0.996, green: 0.972, blue: 0.927)
    static let backgroundMid = Color(red: 0.975, green: 0.922, blue: 0.784)
    static let backgroundBottom = Color(red: 0.945, green: 0.823, blue: 0.533)
    static let backgroundHighlight = Color(red: 1.0, green: 0.949, blue: 0.812)
    
    static let appleGoldLight = Color(red: 0.839, green: 0.690, blue: 0.215)   // #D6B157
    static let appleGoldDark = Color(red: 0.786, green: 0.612, blue: 0.200)    // #C89C38
    static let appleShadow = Color(red: 0.675, green: 0.525, blue: 0.157)
    
    static let creamBorder = Color(red: 0.894, green: 0.800, blue: 0.612)
    static let creamShadow = Color(red: 0.757, green: 0.597, blue: 0.327)
    
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

// MARK: - Preview

#Preview {
    AuthView()
        .environmentObject(AppNavigationManager())
        .environmentObject(ThemeManager())
}
