//
//  Buttons.swift
//  Syllabus Sync
//
//  Created by Amro Zabin on 2025-09-06.
//

import SwiftUI

// MARK: - Button Styles

/// Primary CTA Button - main action button with accent color and gradient
struct PrimaryCTAButton: View {
    let title: String
    let action: () -> Void
    let isLoading: Bool
    let isDisabled: Bool
    let icon: String?
    
    @State private var isPressed = false
    
    init(
        _ title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            HapticFeedbackManager.shared.lightImpact()
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
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Layout.Spacing.lg)
            .padding(.vertical, Layout.Spacing.md)
            .background(
                Group {
                    if isDisabled {
                        RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                            .fill(AppColors.textTertiary)
                    } else {
                        RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.886, green: 0.714, blue: 0.275), // #E2B646
                                        Color(red: 0.816, green: 0.612, blue: 0.118)  // #D09C1E
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            )
            .shadow(color: isDisabled ? .clear : AppColors.accent.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(isDisabled || isLoading)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDisabled)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

/// Secondary Button - outline style for secondary actions
struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    let isDisabled: Bool
    let icon: String?
    
    init(
        _ title: String,
        icon: String? = nil,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
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

/// Small Button - compact button for secondary actions
struct SmallButton: View {
    let title: String
    let action: () -> Void
    let style: Style
    
    enum Style {
        case primary
        case secondary
        case destructive
        
        var backgroundColor: Color {
            switch self {
            case .primary: return AppColors.accent
            case .secondary: return AppColors.surfaceSecondary
            case .destructive: return AppColors.error
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary: return .white
            case .secondary: return AppColors.textPrimary
            case .destructive: return .white
            }
        }
    }
    
    init(_ title: String, style: Style = .secondary, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.buttonSmall)
                .foregroundColor(style.foregroundColor)
                .padding(.horizontal, Layout.Spacing.md)
                .padding(.vertical, Layout.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Layout.CornerRadius.sm)
                        .fill(style.backgroundColor)
                )
        }
    }
}

// MARK: - Chip Components

/// Chip View - for tags, filters, and selections
struct ChipView: View {
    let text: String
    let isSelected: Bool
    let onTap: (() -> Void)?
    let style: Style
    
    enum Style {
        case filter
        case tag
        case status(StatusType)
        
        enum StatusType {
            case success
            case warning
            case error
            case info
            
            var color: Color {
                switch self {
                case .success: return AppColors.success
                case .warning: return AppColors.warning
                case .error: return AppColors.error
                case .info: return AppColors.accent
                }
            }
        }
    }
    
    init(
        _ text: String,
        style: Style = .tag,
        isSelected: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.text = text
        self.style = style
        self.isSelected = isSelected
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
            Button(action: onTap) {
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

// MARK: - Card Components

/// Card View - container for content with proper styling
struct CardView<Content: View>: View {
    let content: Content
    let style: Style
    let onTap: (() -> Void)?
    
    enum Style {
        case elevated
        case flat
        case outlined
        
        var backgroundColor: Color {
            switch self {
            case .elevated, .flat: return AppColors.surface
            case .outlined: return Color.clear
            }
        }
        
        var shadow: Bool {
            switch self {
            case .elevated: return true
            case .flat, .outlined: return false
            }
        }
        
        var border: Bool {
            switch self {
            case .outlined: return true
            case .elevated, .flat: return false
            }
        }
    }
    
    init(
        style: Style = .elevated,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.onTap = onTap
        self.content = content()
    }
    
    var body: some View {
        let cardContent = content
            .padding(Layout.Spacing.lg)
            .background(style.backgroundColor)
            .cornerRadius(Layout.CornerRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                    .stroke(AppColors.border, lineWidth: style.border ? 1 : 0)
            )
            .cardShadowLight()
        
        if let onTap = onTap {
            Button(action: onTap) {
                cardContent
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            cardContent
        }
    }
}

// MARK: - App Icon Component

/// App Icon - displays app icons with proper styling
struct AppIcon: View {
    let iconName: String
    let size: Size
    let style: Style
    
    enum Size {
        case small, medium, large, xlarge
        
        var dimension: CGFloat {
            switch self {
            case .small: return 32
            case .medium: return 48
            case .large: return 64
            case .xlarge: return 80
            }
        }
        
        var cornerRadius: CGFloat {
            return dimension * 0.2 // 20% of size for modern iOS look
        }
    }
    
    enum Style {
        case filled
        case outlined
        case system
    }
    
    init(_ iconName: String, size: Size = .medium, style: Style = .filled) {
        self.iconName = iconName
        self.size = size
        self.style = style
    }
    
    var body: some View {
        Group {
            switch style {
            case .filled:
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .fill(AppColors.accent)
                    .frame(width: size.dimension, height: size.dimension)
                    .overlay(
                        Image(systemName: iconName)
                            .font(.system(size: size.dimension * 0.5, weight: .medium))
                            .foregroundColor(.white)
                    )
                
            case .outlined:
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .stroke(AppColors.border, lineWidth: 1.5)
                    .frame(width: size.dimension, height: size.dimension)
                    .overlay(
                        Image(systemName: iconName)
                            .font(.system(size: size.dimension * 0.5, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                    )
                
            case .system:
                Image(systemName: iconName)
                    .font(.system(size: size.dimension * 0.6, weight: .medium))
                    .foregroundColor(AppColors.accent)
                    .frame(width: size.dimension, height: size.dimension)
            }
        }
    }
}

// MARK: - Shimmer Effect

/// Shimmer View - loading placeholder with animated shimmer effect
struct ShimmerView: View {
    @State private var animationOffset: CGFloat = -1
    
    let cornerRadius: CGFloat
    let height: CGFloat?
    
    init(cornerRadius: CGFloat = Layout.CornerRadius.md, height: CGFloat? = nil) {
        self.cornerRadius = cornerRadius
        self.height = height
    }
    
    var body: some View {
        Rectangle()
            .fill(AppColors.surfaceSecondary)
            .frame(height: height)
            .cornerRadius(cornerRadius)
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.3),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(cornerRadius)
                    .offset(x: animationOffset * UIScreen.main.bounds.width)
                    .animation(
                        Animation.linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                        value: animationOffset
                    )
            )
            .onAppear {
                animationOffset = 1
            }
    }
}

// MARK: - Segmented Tabs

/// Segmented Tabs - horizontal tab selection component
struct SegmentedTabs<Item: Hashable>: View {
    let items: [Item]
    let selectedItem: Item
    let itemTitle: (Item) -> String
    let onSelection: (Item) -> Void
    
    @Namespace private var selectedTab
    
    init(
        items: [Item],
        selectedItem: Item,
        itemTitle: @escaping (Item) -> String,
        onSelection: @escaping (Item) -> Void
    ) {
        self.items = items
        self.selectedItem = selectedItem
        self.itemTitle = itemTitle
        self.onSelection = onSelection
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        onSelection(item)
                    }
                }) {
                    Text(itemTitle(item))
                        .font(.buttonSecondary)
                        .foregroundColor(
                            selectedItem == item ? AppColors.accent : AppColors.textSecondary
                        )
                        .padding(.horizontal, Layout.Spacing.lg)
                        .padding(.vertical, Layout.Spacing.md)
                        .background(
                            Group {
                                if selectedItem == item {
                                    RoundedRectangle(cornerRadius: Layout.CornerRadius.sm)
                                        .fill(AppColors.accent.opacity(0.1))
                                        .matchedGeometryEffect(id: "selectedTab", in: selectedTab)
                                }
                            }
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(Layout.Spacing.xs)
        .background(AppColors.surfaceSecondary)
        .cornerRadius(Layout.CornerRadius.md)
    }
}

// MARK: - Helper Extensions

extension View {
    @ViewBuilder
    func conditionalModifier<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Preview Components

#if DEBUG
struct Buttons_Previews: PreviewProvider {
    static var previews: some View {
        ComponentShowcase()
            .preferredColorScheme(.light)
            .previewDisplayName("Components - Light")
        
        ComponentShowcase()
            .preferredColorScheme(.dark)
            .previewDisplayName("Components - Dark")
    }
}

private struct ComponentShowcase: View {
    @State private var selectedTab = "All"
    @State private var selectedChip = false
    
    private let tabs = ["All", "Assignments", "Quizzes", "Exams"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: Layout.Spacing.xxl) {
                
                // Buttons Section
                ComponentSection(title: "Buttons") {
                    VStack(spacing: Layout.Spacing.lg) {
                        PrimaryCTAButton("Primary Action", icon: "plus") { }
                        
                        PrimaryCTAButton("Loading...", isLoading: true) { }
                        
                        PrimaryCTAButton("Disabled", isDisabled: true) { }
                        
                        SecondaryButton("Secondary Action", icon: "gear") { }
                        
                        SecondaryButton("Disabled", isDisabled: true) { }
                        
                        HStack(spacing: Layout.Spacing.md) {
                            SmallButton("Edit", style: .primary) { }
                            SmallButton("Cancel", style: .secondary) { }
                            SmallButton("Delete", style: .destructive) { }
                        }
                    }
                }
                
                // Chips Section
                ComponentSection(title: "Chips") {
                    VStack(alignment: .leading, spacing: Layout.Spacing.md) {
                        FlowLayout(spacing: Layout.Spacing.sm) {
                            ChipView("Computer Science", style: .tag)
                            ChipView("Mathematics", style: .tag)
                            ChipView("Physics", style: .tag)
                        }
                        
                        FlowLayout(spacing: Layout.Spacing.sm) {
                            ChipView("Filter 1", style: .filter, isSelected: false) {
                                selectedChip.toggle()
                            }
                            ChipView("Filter 2", style: .filter, isSelected: true) {
                                selectedChip.toggle()
                            }
                        }
                        
                        FlowLayout(spacing: Layout.Spacing.sm) {
                            ChipView("Completed", style: .status(.success))
                            ChipView("Due Soon", style: .status(.warning))
                            ChipView("Overdue", style: .status(.error))
                            ChipView("In Progress", style: .status(.info))
                        }
                    }
                }
                
                // App Icons Section
                ComponentSection(title: "App Icons") {
                    HStack(spacing: Layout.Spacing.lg) {
                        VStack(spacing: Layout.Spacing.sm) {
                            AppIcon("book.fill", size: .small, style: .filled)
                            Text("Small").captionS()
                        }
                        
                        VStack(spacing: Layout.Spacing.sm) {
                            AppIcon("graduationcap.fill", size: .medium, style: .outlined)
                            Text("Medium").captionS()
                        }
                        
                        VStack(spacing: Layout.Spacing.sm) {
                            AppIcon("calendar", size: .large, style: .system)
                            Text("Large").captionS()
                        }
                    }
                }
                
                // Cards Section
                ComponentSection(title: "Cards") {
                    VStack(spacing: Layout.Spacing.lg) {
                        CardView(style: .elevated) {
                            SampleCardContent()
                        }
                        
                        CardView(style: .flat) {
                            SampleCardContent()
                        }
                        
                        CardView(style: .outlined) {
                            SampleCardContent()
                        }
                    }
                }
                
                // Segmented Tabs Section
                ComponentSection(title: "Segmented Tabs") {
                    SegmentedTabs(
                        items: tabs,
                        selectedItem: selectedTab,
                        itemTitle: { $0 }
                    ) { tab in
                        selectedTab = tab
                    }
                }
                
                // Shimmer Section
                ComponentSection(title: "Shimmer Loading") {
                    VStack(spacing: Layout.Spacing.md) {
                        ShimmerView(height: 20)
                        ShimmerView(height: 16)
                        ShimmerView(height: 12)
                    }
                }
            }
            .padding(Layout.Spacing.lg)
        }
        .background(AppColors.background)
    }
}

private struct ComponentSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.lg) {
            Text(title)
                .font(.titleM)
                .foregroundColor(AppColors.textPrimary)
            
            content
        }
    }
}

private struct SampleCardContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.md) {
            HStack {
                AppIcon("book.fill", size: .small, style: .filled)
                
                VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                    Text("CS 101").font(.captionL).foregroundColor(AppColors.textSecondary)
                    Text("Data Structures").font(.titleS).foregroundColor(AppColors.textPrimary)
                }
                
                Spacer()
                
                ChipView("Due Soon", style: .status(.warning))
            }
            
            Text("Complete the binary tree implementation assignment. Focus on insertion, deletion, and traversal algorithms.")
                .font(.body)
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(3)
            
            HStack {
                Text("Due: Tomorrow").font(.caption).foregroundColor(AppColors.textTertiary)
                Spacer()
                Text("100 pts").font(.captionL).foregroundColor(AppColors.accent)
            }
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
