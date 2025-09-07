//
//  AppColors.swift
//  Syllabus Sync
//
//  Created by Cursor on 2025-09-06.
//

import SwiftUI

/// Semantic color tokens for Syllabus Sync
/// Supports both light and dark appearance with automatic adaptation
struct AppColors {
    
    // MARK: - Background Colors
    
    /// Primary background color - main app background
    static let background = Color("Background", bundle: nil)
    
    /// Secondary background color - cards, sheets, elevated surfaces
    static let surface = Color("Surface", bundle: nil)
    
    /// Tertiary background color - subtle elements, disabled states
    static let surfaceSecondary = Color("SurfaceSecondary", bundle: nil)
    
    // MARK: - Text Colors
    
    /// Primary text color - main content, headlines
    static let textPrimary = Color("TextPrimary", bundle: nil)
    
    /// Secondary text color - subtitles, descriptions, metadata
    static let textSecondary = Color("TextSecondary", bundle: nil)
    
    /// Tertiary text color - captions, disabled text
    static let textTertiary = Color("TextTertiary", bundle: nil)
    
    // MARK: - Accent & Brand Colors
    
    /// Primary accent color - CTAs, selections, brand elements
    static let accent = Color("Accent", bundle: nil)
    
    /// Secondary accent color - highlights, secondary actions
    static let accentSecondary = Color("AccentSecondary", bundle: nil)
    
    // MARK: - Semantic Colors
    
    /// Success color - completed tasks, positive feedback
    static let success = Color("Success", bundle: nil)
    
    /// Warning color - important alerts, pending states  
    static let warning = Color("Warning", bundle: nil)
    
    /// Error color - validation errors, destructive actions
    static let error = Color("Error", bundle: nil)
    
    /// Info color - informational messages, neutral highlights
    static let info = Color("Info", bundle: nil)
    
    // MARK: - UI Element Colors
    
    /// Border color for inputs, cards, dividers
    static let border = Color("Border", bundle: nil)
    
    /// Separator color for lists, sections
    static let separator = Color("Separator", bundle: nil)
    
    /// Shadow color for elevated elements
    static let shadow = Color("Shadow", bundle: nil)
    
    // MARK: - Event Type Colors (for calendar events)
    
    /// Assignment events
    static let eventAssignment = Color("EventAssignment", bundle: nil)
    
    /// Quiz events  
    static let eventQuiz = Color("EventQuiz", bundle: nil)
    
    /// Exam events (midterms, finals)
    static let eventExam = Color("EventExam", bundle: nil)
    
    /// Lab events
    static let eventLab = Color("EventLab", bundle: nil)
    
    /// Lecture events
    static let eventLecture = Color("EventLecture", bundle: nil)
}

// MARK: - Color Extensions

extension Color {
    
    /// Creates a color that adapts to light/dark mode
    /// - Parameters:
    ///   - light: Color for light appearance
    ///   - dark: Color for dark appearance
    static func adaptive(light: Color, dark: Color) -> Color {
        Color(.init { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
    
    /// Creates a color with custom opacity
    /// - Parameter value: Opacity value (0.0 - 1.0)
    func withOpacity(_ value: Double) -> Color {
        self.opacity(value)
    }
}

// MARK: - Preview Helpers

#if DEBUG
struct AppColors_Previews: PreviewProvider {
    static var previews: some View {
        ColorPalettePreview()
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode")
        
        ColorPalettePreview()
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
    }
}

private struct ColorPalettePreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Background Colors
                ColorSection(title: "Background Colors") {
                    ColorSwatch("Background", color: AppColors.background)
                    ColorSwatch("Surface", color: AppColors.surface)
                    ColorSwatch("Surface Secondary", color: AppColors.surfaceSecondary)
                }
                
                // Text Colors
                ColorSection(title: "Text Colors") {
                    ColorSwatch("Text Primary", color: AppColors.textPrimary)
                    ColorSwatch("Text Secondary", color: AppColors.textSecondary)
                    ColorSwatch("Text Tertiary", color: AppColors.textTertiary)
                }
                
                // Accent Colors
                ColorSection(title: "Accent Colors") {
                    ColorSwatch("Accent", color: AppColors.accent)
                    ColorSwatch("Accent Secondary", color: AppColors.accentSecondary)
                }
                
                // Semantic Colors
                ColorSection(title: "Semantic Colors") {
                    ColorSwatch("Success", color: AppColors.success)
                    ColorSwatch("Warning", color: AppColors.warning)
                    ColorSwatch("Error", color: AppColors.error)
                    ColorSwatch("Info", color: AppColors.info)
                }
                
                // Event Colors
                ColorSection(title: "Event Type Colors") {
                    ColorSwatch("Assignment", color: AppColors.eventAssignment)
                    ColorSwatch("Quiz", color: AppColors.eventQuiz)
                    ColorSwatch("Exam", color: AppColors.eventExam)
                    ColorSwatch("Lab", color: AppColors.eventLab)
                    ColorSwatch("Lecture", color: AppColors.eventLecture)
                }
            }
            .padding()
        }
        .background(AppColors.background)
    }
}

private struct ColorSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                content
            }
        }
    }
}

private struct ColorSwatch: View {
    let name: String
    let color: Color
    
    init(_ name: String, color: Color) {
        self.name = name
        self.color = color
    }
    
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppColors.border, lineWidth: 1)
                )
            
            Text(name)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
}
#endif
