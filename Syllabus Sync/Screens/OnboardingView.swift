//
//  OnboardingView.swift
//  Syllabus Sync
//
//  Created by Assistant on 2024-01-01.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var navigationManager: AppNavigationManager
    @State private var currentPage = 0
    @State private var dragOffset: CGFloat = 0
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "calendar.badge.plus",
            iconColor: AppColors.accent,
            title: "Welcome to Syllabus Sync",
            subtitle: "Transform your academic life",
            description: "Import syllabi, track deadlines, and never miss an important date again. Your complete academic companion."
        ),
        OnboardingPage(
            icon: "doc.text.magnifyingglass",
            iconColor: AppColors.success,
            title: "Smart Syllabus Parsing",
            subtitle: "AI-powered extraction",
            description: "Upload PDFs and watch as AI intelligently extracts assignments, exams, and important dates automatically."
        ),
        OnboardingPage(
            icon: "bell.badge",
            iconColor: AppColors.warning,
            title: "Never Miss a Deadline",
            subtitle: "Intelligent reminders",
            description: "Get personalized notifications and reminders tailored to your schedule and study habits."
        ),
        OnboardingPage(
            icon: "sparkles",
            iconColor: AppColors.accent,
            title: "Ready to Get Started?",
            subtitle: "Let's sync your success",
            description: "Join thousands of students who've transformed their academic organization with Syllabus Sync."
        )
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Page indicator
                    HStack(spacing: Layout.Spacing.sm) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? AppColors.accent : AppColors.separator)
                                .frame(width: 8, height: 8)
                                .scaleEffect(index == currentPage ? 1.2 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentPage)
                        }
                    }
                    .padding(.top, Layout.Spacing.lg)
                    .padding(.bottom, Layout.Spacing.xl)
                    
                    // Swipeable pages
                    ZStack {
                        ForEach(0..<pages.count, id: \.self) { index in
                            OnboardingPageView(page: pages[index])
                                .offset(x: CGFloat(index - currentPage) * geometry.size.width + dragOffset)
                                .opacity(index == currentPage ? 1.0 : 0.6)
                                .scaleEffect(index == currentPage ? 1.0 : 0.95)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentPage)
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation.width
                            }
                            .onEnded { value in
                                let threshold: CGFloat = 50
                                
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    if value.translation.width > threshold && currentPage > 0 {
                                        currentPage -= 1
                                        HapticFeedbackManager.shared.lightImpact()
                                    } else if value.translation.width < -threshold && currentPage < pages.count - 1 {
                                        currentPage += 1
                                        HapticFeedbackManager.shared.lightImpact()
                                    }
                                    dragOffset = 0
                                }
                            }
                    )
                    
                    Spacer()
                    
                    // Navigation buttons
                    VStack(spacing: Layout.Spacing.md) {
                        if currentPage < pages.count - 1 {
                            HStack {
                                SecondaryButton("Skip") {
                                    HapticFeedbackManager.shared.lightImpact()
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        currentPage = pages.count - 1
                                    }
                                }
                                
                                Spacer()
                                
                                PrimaryCTAButton("Next") {
                                    HapticFeedbackManager.shared.lightImpact()
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        currentPage += 1
                                    }
                                }
                            }
                        } else {
                            PrimaryCTAButton("Get Started") {
                                HapticFeedbackManager.shared.success()
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    navigationManager.setRoot(to: .auth)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Layout.Spacing.lg)
                    .padding(.bottom, Layout.Spacing.xl)
                }
            }
        }
    }
}

// MARK: - Supporting Types

struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let description: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: Layout.Spacing.xl) {
            Spacer()
            
            // Icon with animated background
            ZStack {
                Circle()
                    .fill(page.iconColor.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Circle()
                    .fill(page.iconColor.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                AppIcon(page.icon, size: .xlarge, style: .filled)
                    .foregroundColor(page.iconColor)
            }
            .shadow(color: page.iconColor.opacity(0.3), radius: 20, x: 0, y: 10)
            
            VStack(spacing: Layout.Spacing.lg) {
                VStack(spacing: Layout.Spacing.sm) {
                    Text(page.title)
                        .font(.titleXL)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text(page.subtitle)
                        .font(.title)
                        .fontWeight(.medium)
                        .foregroundColor(page.iconColor)
                        .multilineTextAlignment(.center)
                }
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, Layout.Spacing.lg)
            }
            
            Spacer()
        }
        .padding(.horizontal, Layout.Spacing.lg)
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .environmentObject(AppNavigationManager())
        .environmentObject(ThemeManager())
}
