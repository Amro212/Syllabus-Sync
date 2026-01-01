//
//  AppTypography.swift
//  Syllabus Sync
//
//  Created by Cursor on 2025-09-06.
//

import SwiftUI

/// Typography system for Syllabus Sync
/// Provides semantic font styles with proper scaling and accessibility support
struct AppTypography {
    
    // MARK: - Font Weights
    
    /// Font weights used throughout the app
    enum Weight: String, CaseIterable {
        case light = "light"
        case regular = "regular"
        case medium = "medium"
        case semibold = "semibold"
        case bold = "bold"
        
        var fontWeight: Font.Weight {
            switch self {
            case .light: return .light
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
            case .bold: return .bold
            }
        }
    }
    
    // MARK: - Typography Scale
    
    /// Extra large title - main app headings, welcome screens
    static let titleXL = Font.appFont(size: 34, weight: .bold, relativeTo: .largeTitle)
    
    /// Large title - section headers, primary content titles
    static let titleL = Font.appFont(size: 28, weight: .semibold, relativeTo: .title)
    
    /// Medium title - card titles, secondary headers
    static let titleM = Font.appFont(size: 22, weight: .semibold, relativeTo: .title2)
    
    /// Small title - subsection headers, tertiary titles
    static let titleS = Font.appFont(size: 18, weight: .medium, relativeTo: .title3)
    
    /// Large body - important body text, highlighted content
    static let bodyL = Font.appFont(size: 17, weight: .regular, relativeTo: .body)
    
    /// Regular body - main content, default text
    static let body = Font.appFont(size: 16, weight: .regular, relativeTo: .body)
    
    /// Small body - secondary content, metadata
    static let bodyS = Font.appFont(size: 14, weight: .regular, relativeTo: .subheadline)
    
    /// Large caption - button labels, important annotations
    static let captionL = Font.appFont(size: 13, weight: .medium, relativeTo: .caption)
    
    /// Regular caption - timestamps, descriptions, footnotes
    static let caption = Font.appFont(size: 12, weight: .regular, relativeTo: .caption)
    
    /// Small caption - legal text, fine print
    static let captionS = Font.appFont(size: 11, weight: .regular, relativeTo: .caption2)
    
    // MARK: - Specialized Fonts
    
    /// Monospace font for code, IDs, technical content
    static let code = Font.system(size: 14, weight: .regular, design: .monospaced)
    
    /// Large monospace for displaying course codes, important IDs
    static let codeL = Font.system(size: 16, weight: .medium, design: .monospaced)
    
    // MARK: - Button Typography
    
    /// Primary CTA button text
    static let buttonPrimary = Font.appFont(size: 17, weight: .semibold, relativeTo: .body)
    
    /// Secondary button text
    static let buttonSecondary = Font.appFont(size: 16, weight: .medium, relativeTo: .body)
    
    /// Small button text (chips, tags)
    static let buttonSmall = Font.appFont(size: 14, weight: .medium, relativeTo: .subheadline)
    
    // MARK: - Navigation Typography
    
    /// Navigation bar titles
    static let navTitle = Font.appFont(size: 17, weight: .semibold, relativeTo: .body)
    
    /// Tab bar labels
    static let tabLabel = Font.appFont(size: 10, weight: .medium, relativeTo: .caption2)
    
    /// Navigation link text
    static let navLink = Font.appFont(size: 17, weight: .regular, relativeTo: .body)
}

// MARK: - Font Extensions

extension Font {
    
    /// Creates a custom font with dynamic type support
    /// - Parameters:
    ///   - size: Base font size
    ///   - weight: Font weight
    ///   - design: Font design (default, serif, monospaced, rounded)
    ///   - relativeTo: Text style to scale relative to
    static func appFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        // Use "Lexend" family name. 
        // For variable fonts, usually "Lexend" covers all weights.
        // We apply the SwiftUI .weight() modifier which works well with variable fonts
        // if the custom font supports it.
        return Font.custom("Lexend", size: size, relativeTo: textStyle)
            .weight(weight)
    }
    
    /// Typography variants with semantic naming
    static var titleXL: Font { AppTypography.titleXL }
    static var titleL: Font { AppTypography.titleL }
    static var titleM: Font { AppTypography.titleM }
    static var titleS: Font { AppTypography.titleS }
    static var bodyL: Font { AppTypography.bodyL }
    static var bodyRegular: Font { AppTypography.body }
    static var bodyS: Font { AppTypography.bodyS }
    static var captionL: Font { AppTypography.captionL }
    static var captionRegular: Font { AppTypography.caption }
    static var captionS: Font { AppTypography.captionS }
    static var code: Font { AppTypography.code }
    static var codeL: Font { AppTypography.codeL }
    static var buttonPrimary: Font { AppTypography.buttonPrimary }
    static var buttonSecondary: Font { AppTypography.buttonSecondary }
    static var buttonSmall: Font { AppTypography.buttonSmall }
    static var navTitle: Font { AppTypography.navTitle }
    static var tabLabel: Font { AppTypography.tabLabel }
    static var navLink: Font { AppTypography.navLink }
}

// MARK: - Text Style Extensions

extension Text {
    
    /// Applies title XL styling with proper color
    func titleXL(color: Color = AppColors.textPrimary) -> some View {
        self.font(.titleXL)
            .foregroundColor(color)
    }
    
    /// Applies title L styling with proper color
    func titleL(color: Color = AppColors.textPrimary) -> some View {
        self.font(.titleL)
            .foregroundColor(color)
    }
    
    /// Applies title M styling with proper color
    func titleM(color: Color = AppColors.textPrimary) -> some View {
        self.font(.titleM)
            .foregroundColor(color)
    }
    
    /// Applies title S styling with proper color
    func titleS(color: Color = AppColors.textPrimary) -> some View {
        self.font(.titleS)
            .foregroundColor(color)
    }
    
    /// Applies body L styling with proper color
    func bodyL(color: Color = AppColors.textPrimary) -> some View {
        self.font(.bodyL)
            .foregroundColor(color)
    }
    
    /// Applies regular body styling with proper color
    func body(color: Color = AppColors.textPrimary) -> some View {
        self.font(.bodyRegular)
            .foregroundColor(color)
    }
    
    /// Applies body S styling with proper color
    func bodyS(color: Color = AppColors.textSecondary) -> some View {
        self.font(.bodyS)
            .foregroundColor(color)
    }
    
    /// Applies caption L styling with proper color
    func captionL(color: Color = AppColors.textSecondary) -> some View {
        self.font(.captionL)
            .foregroundColor(color)
    }
    
    /// Applies regular caption styling with proper color
    func caption(color: Color = AppColors.textSecondary) -> some View {
        self.font(.captionRegular)
            .foregroundColor(color)
    }
    
    /// Applies caption S styling with proper color
    func captionS(color: Color = AppColors.textTertiary) -> some View {
        self.font(.captionS)
            .foregroundColor(color)
    }
    
    /// Applies code styling with proper color and background
    func code(color: Color = AppColors.textPrimary, background: Color = AppColors.surfaceSecondary) -> some View {
        self.font(.code)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(background)
            .cornerRadius(4)
    }
}

// MARK: - Typography Preview Helpers

#if DEBUG
struct AppTypography_Previews: PreviewProvider {
    static var previews: some View {
        TypographyShowcase()
            .preferredColorScheme(.light)
            .previewDisplayName("Typography - Light")
        
        TypographyShowcase()
            .preferredColorScheme(.dark)
            .previewDisplayName("Typography - Dark")
        
        TypographyShowcase()
            .environment(\.dynamicTypeSize, .accessibility1)
            .previewDisplayName("Typography - Large Text")
    }
}

private struct TypographyShowcase: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Title Hierarchy
                TypographySection(title: "Title Hierarchy") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Title XL - Main Headings").titleXL()
                        Text("Title L - Section Headers").titleL()
                        Text("Title M - Card Titles").titleM()
                        Text("Title S - Subsection Headers").titleS()
                    }
                }
                
                // Body Text Hierarchy
                TypographySection(title: "Body Text") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Body L - Important content and highlighted text").bodyL()
                        Text("Body - Main content and default text for reading").body()
                        Text("Body S - Secondary content and metadata").bodyS()
                    }
                }
                
                // Caption Hierarchy
                TypographySection(title: "Captions & Labels") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Caption L - Button labels and important annotations").captionL()
                        Text("Caption - Timestamps, descriptions, and footnotes").caption()
                        Text("Caption S - Legal text and fine print").captionS()
                    }
                }
                
                // Specialized Typography
                TypographySection(title: "Specialized") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("CS101").code()
                        Text("COURSE-ID-12345").code()
                        
                        HStack(spacing: 12) {
                            Button("Primary CTA") {}
                                .font(.buttonPrimary)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(AppColors.accent)
                                .cornerRadius(8)
                            
                            Button("Secondary") {}
                                .font(.buttonSecondary)
                                .foregroundColor(AppColors.accent)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(AppColors.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(AppColors.accent, lineWidth: 1)
                                )
                        }
                    }
                }
                
                // Real-world Example
                TypographySection(title: "Real-world Example") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("CS101").code()
                            Spacer()
                            Text("Due Tomorrow").captionL(color: AppColors.warning)
                        }
                        
                        Text("Homework Assignment #3").titleM()
                        Text("Complete the binary tree implementation and submit via Canvas").body()
                        
                        HStack {
                            Text("Assigned: Sept 1, 2025").caption()
                            Spacer()
                            Text("100 points").captionL(color: AppColors.accent)
                        }
                    }
                    .padding(16)
                    .background(AppColors.surface)
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .background(AppColors.background)
    }
}

private struct TypographySection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).titleS(color: AppColors.accent)
            content
            
            Divider()
                .background(AppColors.separator)
        }
    }
}
#endif
