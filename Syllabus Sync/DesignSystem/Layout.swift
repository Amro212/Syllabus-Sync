//
//  Layout.swift
//  Syllabus Sync
//
//  Created by Cursor on 2025-09-06.
//

import SwiftUI

/// Layout tokens for consistent spacing, corner radii, and shadows
/// Provides a systematic approach to visual hierarchy and spacing
struct Layout {
    
    // MARK: - Spacing Tokens
    
    /// Spacing scale for consistent layout
    struct Spacing {
        /// Extra small spacing - 4pt (tight elements, internal padding)
        static let xs: CGFloat = 4
        
        /// Small spacing - 8pt (compact layouts, close elements)
        static let sm: CGFloat = 8
        
        /// Medium spacing - 12pt (default spacing, comfortable layouts)
        static let md: CGFloat = 12
        
        /// Large spacing - 16pt (section spacing, card padding)
        static let lg: CGFloat = 16
        
        /// Extra large spacing - 20pt (prominent spacing, major sections)
        static let xl: CGFloat = 20
        
        /// Double extra large spacing - 24pt (page margins, major separations)
        static let xxl: CGFloat = 24
        
        /// Triple extra large spacing - 32pt (hero sections, major breaks)
        static let xxxl: CGFloat = 32
        
        /// Massive spacing - 48pt (page breaks, major layout sections)
        static let massive: CGFloat = 48
    }
    
    // MARK: - Corner Radius Tokens
    
    /// Corner radius scale for consistent rounded corners
    struct CornerRadius {
        /// No radius - 0pt (sharp corners)
        static let none: CGFloat = 0
        
        /// Extra small radius - 4pt (subtle rounding, small elements)
        static let xs: CGFloat = 4
        
        /// Small radius - 6pt (buttons, chips, minor elements)
        static let sm: CGFloat = 6
        
        /// Medium radius - 8pt (cards, input fields, standard elements)
        static let md: CGFloat = 8
        
        /// Large radius - 12pt (prominent cards, major elements)
        static let lg: CGFloat = 12
        
        /// Extra large radius - 16pt (hero cards, major sections)
        static let xl: CGFloat = 16
        
        /// Double extra large radius - 20pt (special cards, unique elements)
        static let xxl: CGFloat = 20
        
        /// Circle radius - creates perfect circles
        static let circle: CGFloat = 999
    }
    
    // MARK: - Shadow Tokens
    
    /// Shadow definitions for depth and elevation
    struct Shadow {
        
        /// No shadow - flat appearance
        static let none = ShadowStyle(
            color: .clear,
            radius: 0,
            x: 0,
            y: 0
        )
        
        /// Subtle shadow - minimal elevation (1dp)
        static let subtle = ShadowStyle(
            color: AppColors.shadow.opacity(0.08),
            radius: 2,
            x: 0,
            y: 1
        )
        
        /// Small shadow - low elevation (2dp)
        static let small = ShadowStyle(
            color: AppColors.shadow.opacity(0.12),
            radius: 4,
            x: 0,
            y: 2
        )
        
        /// Medium shadow - standard elevation (4dp)
        static let medium = ShadowStyle(
            color: AppColors.shadow.opacity(0.16),
            radius: 8,
            x: 0,
            y: 4
        )
        
        /// Large shadow - high elevation (8dp)
        static let large = ShadowStyle(
            color: AppColors.shadow.opacity(0.20),
            radius: 16,
            x: 0,
            y: 8
        )
        
        /// Extra large shadow - prominent elevation (16dp)
        static let xl = ShadowStyle(
            color: AppColors.shadow.opacity(0.24),
            radius: 24,
            x: 0,
            y: 12
        )
    }
    
    // MARK: - Border Tokens
    
    /// Border width scale
    struct BorderWidth {
        /// Hair-thin border - 0.5pt
        static let hairline: CGFloat = 0.5
        
        /// Thin border - 1pt (default borders)
        static let thin: CGFloat = 1
        
        /// Medium border - 2pt (emphasis borders)
        static let medium: CGFloat = 2
        
        /// Thick border - 3pt (strong emphasis)
        static let thick: CGFloat = 3
    }
    
    // MARK: - Layout Constants
    
    /// Standard layout measurements
    struct Constants {
        /// Screen edge margins
        static let screenMargin: CGFloat = Spacing.lg
        
        /// Card content padding
        static let cardPadding: CGFloat = Spacing.lg
        
        /// Button height
        static let buttonHeight: CGFloat = 48
        
        /// Input field height
        static let inputHeight: CGFloat = 44
        
        /// Tab bar height
        static let tabBarHeight: CGFloat = 80
        
        /// Navigation bar height
        static let navBarHeight: CGFloat = 44
        
        /// Minimum touch target size
        static let minTouchTarget: CGFloat = 44
    }
}

// MARK: - Shadow Style Helper

/// Helper struct for shadow definitions
struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Extensions

extension View {
    
    // MARK: - Padding Extensions
    
    /// Applies extra small padding (4pt)
    func paddingXS() -> some View {
        self.padding(Layout.Spacing.xs)
    }
    
    /// Applies small padding (8pt)
    func paddingSM() -> some View {
        self.padding(Layout.Spacing.sm)
    }
    
    /// Applies medium padding (12pt)
    func paddingMD() -> some View {
        self.padding(Layout.Spacing.md)
    }
    
    /// Applies large padding (16pt)
    func paddingLG() -> some View {
        self.padding(Layout.Spacing.lg)
    }
    
    /// Applies extra large padding (20pt)
    func paddingXL() -> some View {
        self.padding(Layout.Spacing.xl)
    }
    
    /// Applies double extra large padding (24pt)
    func paddingXXL() -> some View {
        self.padding(Layout.Spacing.xxl)
    }
    
    // MARK: - Corner Radius Extensions
    
    /// Applies small corner radius (6pt)
    func cornerRadiusSM() -> some View {
        self.cornerRadius(Layout.CornerRadius.sm)
    }
    
    /// Applies medium corner radius (8pt)
    func cornerRadiusMD() -> some View {
        self.cornerRadius(Layout.CornerRadius.md)
    }
    
    /// Applies large corner radius (12pt)
    func cornerRadiusLG() -> some View {
        self.cornerRadius(Layout.CornerRadius.lg)
    }
    
    /// Applies extra large corner radius (16pt)
    func cornerRadiusXL() -> some View {
        self.cornerRadius(Layout.CornerRadius.xl)
    }
    
    // MARK: - Shadow Extensions
    
    /// Applies subtle shadow
    func shadowSubtle() -> some View {
        let shadow = Layout.Shadow.subtle
        return self.shadow(
            color: shadow.color,
            radius: shadow.radius,
            x: shadow.x,
            y: shadow.y
        )
    }
    
    /// Applies small shadow
    func shadowSmall() -> some View {
        let shadow = Layout.Shadow.small
        return self.shadow(
            color: shadow.color,
            radius: shadow.radius,
            x: shadow.x,
            y: shadow.y
        )
    }
    
    /// Applies medium shadow
    func shadowMedium() -> some View {
        let shadow = Layout.Shadow.medium
        return self.shadow(
            color: shadow.color,
            radius: shadow.radius,
            x: shadow.x,
            y: shadow.y
        )
    }
    
    /// Applies large shadow
    func shadowLarge() -> some View {
        let shadow = Layout.Shadow.large
        return self.shadow(
            color: shadow.color,
            radius: shadow.radius,
            x: shadow.x,
            y: shadow.y
        )
    }
    
    /// Applies extra large shadow
    func shadowXL() -> some View {
        let shadow = Layout.Shadow.xl
        return self.shadow(
            color: shadow.color,
            radius: shadow.radius,
            x: shadow.x,
            y: shadow.y
        )
    }
}

// MARK: - Preview Components

#if DEBUG
struct Layout_Previews: PreviewProvider {
    static var previews: some View {
        LayoutShowcase()
            .preferredColorScheme(.light)
            .previewDisplayName("Layout Tokens - Light")
        
        LayoutShowcase()
            .preferredColorScheme(.dark)
            .previewDisplayName("Layout Tokens - Dark")
    }
}

private struct LayoutShowcase: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Layout.Spacing.xxl) {
                
                // Spacing Showcase
                SpacingShowcase()
                
                // Corner Radius Showcase
                CornerRadiusShowcase()
                
                // Shadow Showcase
                ShadowShowcase()
                
                // Sample Card Component
                SampleCardComponent()
            }
            .paddingLG()
        }
        .background(AppColors.background)
    }
}

private struct SpacingShowcase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.lg) {
            Text("Spacing Tokens").titleM(color: AppColors.accent)
            
            VStack(spacing: Layout.Spacing.sm) {
                SpacingRow(name: "XS (4pt)", spacing: Layout.Spacing.xs)
                SpacingRow(name: "SM (8pt)", spacing: Layout.Spacing.sm)
                SpacingRow(name: "MD (12pt)", spacing: Layout.Spacing.md)
                SpacingRow(name: "LG (16pt)", spacing: Layout.Spacing.lg)
                SpacingRow(name: "XL (20pt)", spacing: Layout.Spacing.xl)
                SpacingRow(name: "XXL (24pt)", spacing: Layout.Spacing.xxl)
            }
        }
    }
}

private struct SpacingRow: View {
    let name: String
    let spacing: CGFloat
    
    var body: some View {
        HStack {
            Text(name).captionL()
            Spacer()
            Rectangle()
                .fill(AppColors.accent)
                .frame(width: spacing, height: 16)
        }
    }
}

private struct CornerRadiusShowcase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.lg) {
            Text("Corner Radius Tokens").titleM(color: AppColors.accent)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: Layout.Spacing.md) {
                CornerRadiusCard(name: "XS", radius: Layout.CornerRadius.xs)
                CornerRadiusCard(name: "SM", radius: Layout.CornerRadius.sm)
                CornerRadiusCard(name: "MD", radius: Layout.CornerRadius.md)
                CornerRadiusCard(name: "LG", radius: Layout.CornerRadius.lg)
                CornerRadiusCard(name: "XL", radius: Layout.CornerRadius.xl)
                CornerRadiusCard(name: "XXL", radius: Layout.CornerRadius.xxl)
                CornerRadiusCard(name: "Circle", radius: Layout.CornerRadius.circle)
                CornerRadiusCard(name: "None", radius: Layout.CornerRadius.none)
            }
        }
    }
}

private struct CornerRadiusCard: View {
    let name: String
    let radius: CGFloat
    
    var body: some View {
        VStack(spacing: Layout.Spacing.xs) {
            Rectangle()
                .fill(AppColors.accent)
                .frame(height: 40)
                .cornerRadius(radius)
            
            Text(name).captionS()
        }
    }
}

private struct ShadowShowcase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.lg) {
            Text("Shadow Tokens").titleM(color: AppColors.accent)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: Layout.Spacing.lg) {
                ShadowCard(name: "Subtle", shadow: Layout.Shadow.subtle)
                ShadowCard(name: "Small", shadow: Layout.Shadow.small)
                ShadowCard(name: "Medium", shadow: Layout.Shadow.medium)
                ShadowCard(name: "Large", shadow: Layout.Shadow.large)
                ShadowCard(name: "XL", shadow: Layout.Shadow.xl)
                ShadowCard(name: "None", shadow: Layout.Shadow.none)
            }
        }
    }
}

private struct ShadowCard: View {
    let name: String
    let shadow: ShadowStyle
    
    var body: some View {
        VStack(spacing: Layout.Spacing.sm) {
            Rectangle()
                .fill(AppColors.surface)
                .frame(height: 60)
                .cornerRadiusMD()
                .shadow(
                    color: shadow.color,
                    radius: shadow.radius,
                    x: shadow.x,
                    y: shadow.y
                )
            
            Text(name).captionL()
        }
    }
}

private struct SampleCardComponent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.lg) {
            Text("Sample Card Component").titleM(color: AppColors.accent)
            
            // Assignment Card Example
            VStack(alignment: .leading, spacing: Layout.Spacing.md) {
                HStack {
                    Text("CS101").code()
                    Spacer()
                    Text("Due Tomorrow").captionL(color: AppColors.warning)
                }
                
                Text("Binary Tree Implementation").titleS()
                Text("Complete the binary search tree implementation with insert, delete, and search operations. Submit via Canvas.").body()
                
                HStack {
                    Text("Assigned: Sept 1, 2025").caption()
                    Spacer()
                    Text("100 points").captionL(color: AppColors.accent)
                }
                
                HStack(spacing: Layout.Spacing.sm) {
                    Button("Start Assignment") {}
                        .font(.buttonSecondary)
                        .foregroundColor(AppColors.accent)
                        .paddingSM()
                        .background(AppColors.surfaceSecondary)
                        .cornerRadiusSM()
                    
                    Spacer()
                    
                    Button("Add to Calendar") {}
                        .font(.buttonSecondary)
                        .foregroundColor(.white)
                        .paddingSM()
                        .background(AppColors.accent)
                        .cornerRadiusSM()
                }
            }
            .paddingLG()
            .background(AppColors.surface)
            .cornerRadiusLG()
            .shadowMedium()
        }
    }
}
#endif
