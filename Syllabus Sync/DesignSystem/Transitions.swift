//
//  Transitions.swift
//  Syllabus Sync
//
//  Created by Cursor on 2025-09-06.
//

import SwiftUI

// MARK: - Transition Types

/// Available transition types for navigation
enum TransitionType: CaseIterable {
    case slide
    case dissolve
    case scale
    case slideUp
    case slideDown
    case push
    
    var animation: Animation {
        switch self {
        case .slide, .push:
            return .spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)
        case .dissolve:
            return .easeInOut(duration: 0.3)
        case .scale:
            return .spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)
        case .slideUp, .slideDown:
            return .spring(response: 0.45, dampingFraction: 0.75, blendDuration: 0)
        }
    }
}

// MARK: - Transition Extensions

extension AnyTransition {
    
    /// Smooth slide transition (horizontal)
    static let slide: AnyTransition = .asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )
    
    /// Elegant dissolve transition
    static let dissolve: AnyTransition = .opacity
    
    /// Scale transition with fade
    static let scale: AnyTransition = .scale(scale: 0.95).combined(with: .opacity)
    
    /// Slide up transition (for modals)
    static let slideUp: AnyTransition = .asymmetric(
        insertion: .move(edge: .bottom).combined(with: .opacity),
        removal: .move(edge: .bottom).combined(with: .opacity)
    )
    
    /// Slide down transition (for dismissals)
    static let slideDown: AnyTransition = .asymmetric(
        insertion: .move(edge: .top).combined(with: .opacity),
        removal: .move(edge: .top).combined(with: .opacity)
    )
    
    /// Push transition (iOS-style)
    static let push: AnyTransition = .asymmetric(
        insertion: .move(edge: .trailing),
        removal: .move(edge: .leading)
    )
}

// MARK: - Matched Geometry Helper

/// Helper for creating smooth matched geometry transitions
struct MatchedGeometryHelper {
    let namespace: Namespace.ID
    
    /// Create a matched geometry effect with consistent styling
    func effect(id: String, in category: String = "default") -> some View {
        Rectangle()
            .fill(Color.clear)
            .matchedGeometryEffect(id: "\(category)_\(id)", in: namespace)
    }
}

// MARK: - Transition View Modifier

/// View modifier for applying consistent transitions
struct TransitionModifier: ViewModifier {
    let type: TransitionType
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .transition(transition(for: type))
            .animation(type.animation, value: isActive)
    }
    
    private func transition(for type: TransitionType) -> AnyTransition {
        switch type {
        case .slide:
            return .slide
        case .dissolve:
            return .dissolve
        case .scale:
            return .scale
        case .slideUp:
            return .slideUp
        case .slideDown:
            return .slideDown
        case .push:
            return .push
        }
    }
}

extension View {
    /// Apply a transition with animation
    func transition(_ type: TransitionType, isActive: Bool = true) -> some View {
        modifier(TransitionModifier(type: type, isActive: isActive))
    }
}

// MARK: - Navigation Transition Container

/// Container view that handles navigation transitions
struct NavigationTransitionContainer<Content: View>: View {
    let content: Content
    let transitionType: TransitionType
    @State private var isVisible = false
    
    init(
        transitionType: TransitionType = .slide,
        @ViewBuilder content: () -> Content
    ) {
        self.transitionType = transitionType
        self.content = content()
    }
    
    var body: some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.95)
            .onAppear {
                withAnimation(transitionType.animation) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Card Transition Helper

/// Helper for card-based transitions with matched geometry
struct CardTransition: View {
    let id: String
    let namespace: Namespace.ID
    let isExpanded: Bool
    let content: AnyView
    
    init<Content: View>(
        id: String,
        namespace: Namespace.ID,
        isExpanded: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.id = id
        self.namespace = namespace
        self.isExpanded = isExpanded
        self.content = AnyView(content())
    }
    
    var body: some View {
        content
            .matchedGeometryEffect(id: id, in: namespace)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isExpanded)
    }
}

// MARK: - Slide Transition Helper

/// Helper for creating slide transitions between views
struct SlideTransition<PrimaryContent: View, SecondaryContent: View>: View {
    @Binding var showSecondary: Bool
    let primaryContent: PrimaryContent
    let secondaryContent: SecondaryContent
    let direction: Edge
    
    init(
        showSecondary: Binding<Bool>,
        direction: Edge = .trailing,
        @ViewBuilder primary: () -> PrimaryContent,
        @ViewBuilder secondary: () -> SecondaryContent
    ) {
        self._showSecondary = showSecondary
        self.direction = direction
        self.primaryContent = primary()
        self.secondaryContent = secondary()
    }
    
    var body: some View {
        ZStack {
            if !showSecondary {
                primaryContent
                    .transition(.asymmetric(
                        insertion: .move(edge: oppositeEdge),
                        removal: .move(edge: direction)
                    ))
            }
            
            if showSecondary {
                secondaryContent
                    .transition(.asymmetric(
                        insertion: .move(edge: direction),
                        removal: .move(edge: oppositeEdge)
                    ))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showSecondary)
    }
    
    private var oppositeEdge: Edge {
        switch direction {
        case .leading: return .trailing
        case .trailing: return .leading
        case .top: return .bottom
        case .bottom: return .top
        }
    }
}

// MARK: - Dissolve Transition Helper

/// Helper for creating dissolve transitions between views
struct DissolveTransition<PrimaryContent: View, SecondaryContent: View>: View {
    @Binding var showSecondary: Bool
    let primaryContent: PrimaryContent
    let secondaryContent: SecondaryContent
    let duration: Double
    
    init(
        showSecondary: Binding<Bool>,
        duration: Double = 0.3,
        @ViewBuilder primary: () -> PrimaryContent,
        @ViewBuilder secondary: () -> SecondaryContent
    ) {
        self._showSecondary = showSecondary
        self.duration = duration
        self.primaryContent = primary()
        self.secondaryContent = secondary()
    }
    
    var body: some View {
        ZStack {
            if !showSecondary {
                primaryContent
                    .transition(.opacity)
            }
            
            if showSecondary {
                secondaryContent
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: duration), value: showSecondary)
    }
}

// MARK: - Hero Transition Helper

/// Helper for hero-style transitions with matched geometry
struct HeroTransition: View {
    let id: String
    let namespace: Namespace.ID
    @State private var isExpanded = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: isExpanded ? 0 : 20)
            .fill(AppColors.accent)
            .matchedGeometryEffect(id: id, in: namespace)
            .frame(
                width: isExpanded ? UIScreen.main.bounds.width : 100,
                height: isExpanded ? UIScreen.main.bounds.height : 100
            )
            .onTapGesture {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }
    }
}

// MARK: - Animation Presets

/// Collection of pre-configured animations for common use cases
struct AnimationPresets {
    /// Smooth spring animation for general UI interactions
    static let smooth = Animation.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)
    
    /// Quick spring animation for small UI changes
    static let quick = Animation.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0)
    
    /// Bouncy animation for playful interactions
    static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0)
    
    /// Gentle ease animation for subtle changes
    static let gentle = Animation.easeInOut(duration: 0.4)
    
    /// Snappy animation for button presses
    static let snappy = Animation.spring(response: 0.2, dampingFraction: 0.8, blendDuration: 0)
}

// MARK: - Transition Preview

#if DEBUG
struct TransitionPreview: View {
    @Namespace private var namespace
    @State private var currentTransition: TransitionType = .slide
    @State private var showSecondary = false
    @State private var heroID = "hero"
    
    var body: some View {
        NavigationView {
            VStack(spacing: Layout.Spacing.lg) {
                // Transition Type Picker
                Picker("Transition", selection: $currentTransition) {
                    ForEach(TransitionType.allCases, id: \.self) { type in
                        Text(String(describing: type).capitalized)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Transition Demo
                CardView(style: .elevated) {
                    VStack(spacing: Layout.Spacing.md) {
                        Text("Transition Demo")
                            .font(.titleM)
                            .foregroundColor(AppColors.textPrimary)
                        
                        PrimaryCTAButton("Toggle Transition") {
                            withAnimation(currentTransition.animation) {
                                showSecondary.toggle()
                            }
                        }
                        
                        ZStack {
                            if !showSecondary {
                                RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                                    .fill(AppColors.accent)
                                    .frame(height: 100)
                                    .transition(transition(for: currentTransition))
                            }
                            
                            if showSecondary {
                                RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                                    .fill(AppColors.success)
                                    .frame(height: 100)
                                    .transition(transition(for: currentTransition))
                            }
                        }
                        .frame(height: 100)
                    }
                    .padding(Layout.Spacing.lg)
                }
                
                // Hero Transition Demo
                CardView(style: .elevated) {
                    VStack(spacing: Layout.Spacing.md) {
                        Text("Hero Transition")
                            .font(.titleM)
                            .foregroundColor(AppColors.textPrimary)
                        
                        HeroTransition(id: heroID, namespace: namespace)
                    }
                    .padding(Layout.Spacing.lg)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Transitions")
        }
    }
    
    private func transition(for type: TransitionType) -> AnyTransition {
        switch type {
        case .slide: return .slide
        case .dissolve: return .dissolve
        case .scale: return .scale
        case .slideUp: return .slideUp
        case .slideDown: return .slideDown
        case .push: return .push
        }
    }
}

struct TransitionPreview_Previews: PreviewProvider {
    static var previews: some View {
        TransitionPreview()
    }
}
#endif
