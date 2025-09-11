//
//  HapticFeedbackManager.swift
//  Syllabus Sync
//
//  Created by Cursor on 2025-09-06.
//

import UIKit
import SwiftUI

/// Centralized haptic feedback management for consistent user experience
class HapticFeedbackManager {
    
    // MARK: - Singleton
    
    static let shared = HapticFeedbackManager()
    
    private init() {}
    
    // MARK: - Feedback Types
    
    enum FeedbackType {
        case success
        case warning
        case error
        case selection
        case lightImpact
        case mediumImpact
        case heavyImpact
        case softImpact
        case rigidImpact
        
        var generator: UIFeedbackGenerator {
            switch self {
            case .success:
                let generator = UINotificationFeedbackGenerator()
                generator.prepare()
                return generator
                
            case .warning:
                let generator = UINotificationFeedbackGenerator()
                generator.prepare()
                return generator
                
            case .error:
                let generator = UINotificationFeedbackGenerator()
                generator.prepare()
                return generator
                
            case .selection:
                let generator = UISelectionFeedbackGenerator()
                generator.prepare()
                return generator
                
            case .lightImpact:
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.prepare()
                return generator
                
            case .mediumImpact:
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.prepare()
                return generator
                
            case .heavyImpact:
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.prepare()
                return generator
                
            case .softImpact:
                if #available(iOS 13.0, *) {
                    let generator = UIImpactFeedbackGenerator(style: .soft)
                    generator.prepare()
                    return generator
                } else {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.prepare()
                    return generator
                }
                
            case .rigidImpact:
                if #available(iOS 13.0, *) {
                    let generator = UIImpactFeedbackGenerator(style: .rigid)
                    generator.prepare()
                    return generator
                } else {
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.prepare()
                    return generator
                }
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Triggers haptic feedback based on the specified type
    /// - Parameter type: The type of feedback to trigger
    func trigger(_ type: FeedbackType) {
        DispatchQueue.main.async {
            switch type {
            case .success:
                if let generator = type.generator as? UINotificationFeedbackGenerator {
                    generator.notificationOccurred(.success)
                }
                
            case .warning:
                if let generator = type.generator as? UINotificationFeedbackGenerator {
                    generator.notificationOccurred(.warning)
                }
                
            case .error:
                if let generator = type.generator as? UINotificationFeedbackGenerator {
                    generator.notificationOccurred(.error)
                }
                
            case .selection:
                if let generator = type.generator as? UISelectionFeedbackGenerator {
                    generator.selectionChanged()
                }
                
            case .lightImpact, .mediumImpact, .heavyImpact, .softImpact, .rigidImpact:
                if let generator = type.generator as? UIImpactFeedbackGenerator {
                    generator.impactOccurred()
                }
            }
        }
    }
    
    /// Convenience method for success feedback
    func success() {
        trigger(.success)
    }
    
    /// Convenience method for warning feedback
    func warning() {
        trigger(.warning)
    }
    
    /// Convenience method for error feedback
    func error() {
        trigger(.error)
    }
    
    /// Convenience method for selection feedback
    func selection() {
        trigger(.selection)
    }
    
    /// Convenience method for light impact feedback
    func lightImpact() {
        trigger(.lightImpact)
    }
    
    /// Convenience method for medium impact feedback
    func mediumImpact() {
        trigger(.mediumImpact)
    }
    
    /// Convenience method for heavy impact feedback
    func heavyImpact() {
        trigger(.heavyImpact)
    }
    
    /// Convenience method for soft impact feedback (iOS 13+)
    func softImpact() {
        trigger(.softImpact)
    }
    
    /// Convenience method for rigid impact feedback (iOS 13+)
    func rigidImpact() {
        trigger(.rigidImpact)
    }
}

// MARK: - SwiftUI Integration

/// SwiftUI view modifier for adding haptic feedback to gestures
struct HapticFeedback: ViewModifier {
    let type: HapticFeedbackManager.FeedbackType
    let trigger: Bool
    
    func body(content: Content) -> some View {
        content
            .onChange(of: trigger) {
                HapticFeedbackManager.shared.trigger(type)
            }
    }
}

extension View {
    /// Adds haptic feedback when the trigger condition changes
    /// - Parameters:
    ///   - type: The type of haptic feedback to trigger
    ///   - trigger: Boolean that triggers the feedback when it changes
    func hapticFeedback(_ type: HapticFeedbackManager.FeedbackType, trigger: Bool) -> some View {
        modifier(HapticFeedback(type: type, trigger: trigger))
    }
    
    /// Adds haptic feedback to tap gestures
    /// - Parameter type: The type of haptic feedback to trigger
    func onTapHaptic(_ type: HapticFeedbackManager.FeedbackType = .lightImpact) -> some View {
        onTapGesture {
            HapticFeedbackManager.shared.trigger(type)
        }
    }
}

// MARK: - Enhanced Button Components with Haptics

/// Primary CTA Button with integrated haptic feedback
struct HapticPrimaryCTAButton: View {
    let title: String
    let action: () -> Void
    let isLoading: Bool
    let isDisabled: Bool
    let icon: String?
    let hapticType: HapticFeedbackManager.FeedbackType
    
    init(
        _ title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        hapticType: HapticFeedbackManager.FeedbackType = .mediumImpact,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.hapticType = hapticType
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            HapticFeedbackManager.shared.trigger(hapticType)
            action()
        }) {
            HStack(spacing: Layout.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                }
                
                Text(title)
                    .font(.buttonPrimary)
            }
            .foregroundColor(.white)
            .padding(.horizontal, Layout.Spacing.lg)
            .padding(.vertical, Layout.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                    .fill(isDisabled ? AppColors.textTertiary : AppColors.accent)
            )
        }
        .disabled(isDisabled || isLoading)
        .scaleEffect(isDisabled ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isDisabled)
    }
}

/// Secondary Button with integrated haptic feedback
struct HapticSecondaryButton: View {
    let title: String
    let action: () -> Void
    let isDisabled: Bool
    let icon: String?
    let hapticType: HapticFeedbackManager.FeedbackType
    
    init(
        _ title: String,
        icon: String? = nil,
        isDisabled: Bool = false,
        hapticType: HapticFeedbackManager.FeedbackType = .lightImpact,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isDisabled = isDisabled
        self.hapticType = hapticType
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            HapticFeedbackManager.shared.trigger(hapticType)
            action()
        }) {
            HStack(spacing: Layout.Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                }
                
                Text(title)
                    .font(.buttonSecondary)
            }
            .foregroundColor(isDisabled ? AppColors.textTertiary : AppColors.accent)
            .padding(.horizontal, Layout.Spacing.lg)
            .padding(.vertical, Layout.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                    .stroke(isDisabled ? AppColors.textTertiary : AppColors.accent, lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                            .fill(AppColors.surface)
                    )
            )
        }
        .disabled(isDisabled)
        .scaleEffect(isDisabled ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isDisabled)
    }
}

/// Chip View with integrated haptic feedback for selections
struct HapticChipView: View {
    let text: String
    let isSelected: Bool
    let onTap: (() -> Void)?
    let style: ChipView.Style
    let hapticType: HapticFeedbackManager.FeedbackType
    
    init(
        _ text: String,
        style: ChipView.Style = .tag,
        isSelected: Bool = false,
        hapticType: HapticFeedbackManager.FeedbackType = .selection,
        onTap: (() -> Void)? = nil
    ) {
        self.text = text
        self.style = style
        self.isSelected = isSelected
        self.hapticType = hapticType
        self.onTap = onTap
    }
    
    var body: some View {
        let content = HStack(spacing: Layout.Spacing.xs) {
            if case .status(let statusType) = style {
                Circle()
                    .fill(statusType.color)
                    .frame(width: 6, height: 6)
            }
            
            Text(text)
                .font(.captionL)
                .foregroundColor(foregroundColor)
        }
        .padding(.horizontal, Layout.Spacing.sm)
        .padding(.vertical, Layout.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: Layout.CornerRadius.xs)
                .fill(backgroundColor)
        )
        
        if let onTap = onTap {
            Button(action: {
                HapticFeedbackManager.shared.trigger(hapticType)
                onTap()
            }) {
                content
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            content
        }
    }
    
    private var backgroundColor: Color {
        switch style {
        case .filter:
            return isSelected ? AppColors.accent : AppColors.surfaceSecondary
        case .tag:
            return AppColors.surfaceSecondary
        case .status(let statusType):
            return statusType.color.opacity(0.1)
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .filter:
            return isSelected ? .white : AppColors.textSecondary
        case .tag:
            return AppColors.textSecondary
        case .status(let statusType):
            return statusType.color
        }
    }
}

// MARK: - Preview Components

#if DEBUG
struct HapticFeedbackManager_Previews: PreviewProvider {
    static var previews: some View {
        HapticShowcase()
            .preferredColorScheme(.light)
            .previewDisplayName("Haptic Components - Light")
        
        HapticShowcase()
            .preferredColorScheme(.dark)
            .previewDisplayName("Haptic Components - Dark")
    }
}

private struct HapticShowcase: View {
    @State private var selectedChip = false
    @State private var buttonPressed = false
    @State private var testFeedback = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: Layout.Spacing.xxl) {
                
                // Haptic Buttons Section
                VStack(alignment: .leading, spacing: Layout.Spacing.lg) {
                    Text("Haptic Buttons")
                        .font(.titleM)
                        .foregroundColor(AppColors.textPrimary)
                    
                    VStack(spacing: Layout.Spacing.md) {
                        HapticPrimaryCTAButton("Success Action", icon: "checkmark", hapticType: .success) {
                            // Action
                        }
                        
                        HapticPrimaryCTAButton("Warning Action", icon: "exclamationmark.triangle", hapticType: .warning) {
                            // Action
                        }
                        
                        HapticSecondaryButton("Light Touch", icon: "hand.tap", hapticType: .lightImpact) {
                            // Action
                        }
                        
                        HapticSecondaryButton("Heavy Impact", icon: "hand.tap.fill", hapticType: .heavyImpact) {
                            // Action
                        }
                    }
                }
                
                // Haptic Chips Section
                VStack(alignment: .leading, spacing: Layout.Spacing.lg) {
                    Text("Haptic Chips")
                        .font(.titleM)
                        .foregroundColor(AppColors.textPrimary)
                    
                    FlowLayout(spacing: Layout.Spacing.sm) {
                        HapticChipView("Filter 1", style: .filter, isSelected: selectedChip, hapticType: .selection) {
                            selectedChip.toggle()
                        }
                        
                        HapticChipView("Filter 2", style: .filter, isSelected: !selectedChip, hapticType: .selection) {
                            selectedChip.toggle()
                        }
                        
                        HapticChipView("Success Status", style: .status(.success), hapticType: .softImpact) {
                            // Action
                        }
                        
                        HapticChipView("Error Status", style: .status(.error), hapticType: .rigidImpact) {
                            // Action
                        }
                    }
                }
                
                // Manual Feedback Testing
                VStack(alignment: .leading, spacing: Layout.Spacing.lg) {
                    Text("Manual Feedback Testing")
                        .font(.titleM)
                        .foregroundColor(AppColors.textPrimary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: Layout.Spacing.md) {
                        FeedbackTestButton(title: "Success", color: AppColors.success) {
                            HapticFeedbackManager.shared.success()
                        }
                        
                        FeedbackTestButton(title: "Warning", color: AppColors.warning) {
                            HapticFeedbackManager.shared.warning()
                        }
                        
                        FeedbackTestButton(title: "Error", color: AppColors.error) {
                            HapticFeedbackManager.shared.error()
                        }
                        
                        FeedbackTestButton(title: "Selection", color: AppColors.accent) {
                            HapticFeedbackManager.shared.selection()
                        }
                        
                        FeedbackTestButton(title: "Light", color: AppColors.textSecondary) {
                            HapticFeedbackManager.shared.lightImpact()
                        }
                        
                        FeedbackTestButton(title: "Medium", color: AppColors.textPrimary) {
                            HapticFeedbackManager.shared.mediumImpact()
                        }
                        
                        FeedbackTestButton(title: "Heavy", color: Color.black) {
                            HapticFeedbackManager.shared.heavyImpact()
                        }
                        
                        FeedbackTestButton(title: "Soft", color: Color.blue) {
                            HapticFeedbackManager.shared.softImpact()
                        }
                    }
                }
                
                // Usage Examples
                VStack(alignment: .leading, spacing: Layout.Spacing.lg) {
                    Text("Usage Examples")
                        .font(.titleM)
                        .foregroundColor(AppColors.textPrimary)
                    
                    VStack(alignment: .leading, spacing: Layout.Spacing.md) {
                        Text("• Success: Task completion, save operations")
                            .font(.body)
                            .foregroundColor(AppColors.textSecondary)
                        
                        Text("• Warning: Important notifications, confirmations")
                            .font(.body)
                            .foregroundColor(AppColors.textSecondary)
                        
                        Text("• Error: Failed operations, validation errors")
                            .font(.body)
                            .foregroundColor(AppColors.textSecondary)
                        
                        Text("• Selection: Tab switches, picker changes")
                            .font(.body)
                            .foregroundColor(AppColors.textSecondary)
                        
                        Text("• Light Impact: Button taps, minor interactions")
                            .font(.body)
                            .foregroundColor(AppColors.textSecondary)
                        
                        Text("• Heavy Impact: Important actions, drag operations")
                            .font(.body)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .padding(Layout.Spacing.lg)
        }
        .background(AppColors.background)
    }
}

private struct FeedbackTestButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.buttonSecondary)
                .foregroundColor(.white)
                .padding(.vertical, Layout.Spacing.md)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: Layout.CornerRadius.sm)
                        .fill(color)
                )
        }
    }
}

private struct FlowLayout: SwiftUI.Layout {
    let spacing: CGFloat
    
    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            
            if rowWidth + subviewSize.width + spacing > maxWidth && rowWidth > 0 {
                height += rowHeight + spacing
                rowWidth = subviewSize.width
                rowHeight = subviewSize.height
            } else {
                rowWidth += subviewSize.width + (rowWidth > 0 ? spacing : 0)
                rowHeight = max(rowHeight, subviewSize.height)
            }
        }
        
        height += rowHeight
        return CGSize(width: maxWidth, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: LayoutSubviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            
            if x + subviewSize.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += subviewSize.width + spacing
            rowHeight = max(rowHeight, subviewSize.height)
        }
    }
}
#endif
