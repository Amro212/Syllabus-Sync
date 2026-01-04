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
    /// Light: #f8f7f6, Dark: #211c11
    static let background = Color.adaptive(
        light: Color(hex: "f8f7f6"),
        dark: Color(hex: "211c11")
    )
    
    /// Secondary background color - cards, sheets, elevated surfaces
    /// Using slightly lighter/darker variations for surface separation
    static let surface = Color.adaptive(
        light: Color.white, // Standard white for cards on light mode
        dark: Color(hex: "2c2619") // Slightly lighter than background-dark
    )
    
    /// Tertiary background color - subtle elements, disabled states
    static let surfaceSecondary = Color.adaptive(
        light: Color(hex: "f0efeb"),
        dark: Color(hex: "3a3425")
    )
    
    // MARK: - Text Colors
    
    /// Primary text color - main content, headlines
    static let textPrimary = Color.adaptive(
        light: Color(hex: "18181b"), // zinc-900
        dark: Color.white
    )
    
    /// Secondary text color - subtitles, descriptions, metadata
    static let textSecondary = Color.adaptive(
        light: Color(hex: "71717a"), // zinc-500
        dark: Color(hex: "c6b795")  // Custom gold-ish/beige text for dark mode
    )
    
    /// Tertiary text color - captions, disabled text
    static let textTertiary = Color.adaptive(
        light: Color(hex: "a1a1aa"),
        dark: Color(hex: "8f856d")
    )
    
    // MARK: - Accent & Brand Colors
    
    /// Primary accent color - CTAs, selections, brand elements
    /// #d29c1e
    static let accent = Color(hex: "d29c1e")
    
    /// Secondary accent color - highlights, secondary actions
    static let accentSecondary = Color(hex: "e2b646")
    
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
        Color(UIColor { traitCollection in
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
    
    /// Initialize with Hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
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
