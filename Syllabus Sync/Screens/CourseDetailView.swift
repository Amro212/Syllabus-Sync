//
//  CourseDetailView.swift
//  Syllabus Sync
//
//  Created by Cursor on 2025-09-06.
//

import SwiftUI

struct CourseDetailView: View {
    let course: MockCourse
    @EnvironmentObject var navigationManager: AppNavigationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: CourseTab = .all
    @State private var showingEditSheet = false
    @State private var editedCourse: MockCourse
    @Namespace private var heroAnimation
    
    enum CourseTab: String, CaseIterable {
        case all = "All"
        case assignments = "Assignments"
        case exams = "Exams"
        case lectures = "Lectures"
        case labs = "Labs"
        
        var icon: String {
            switch self {
            case .all: return "calendar"
            case .assignments: return "doc.text"
            case .exams: return "graduationcap"
            case .lectures: return "person.fill"
            case .labs: return "flask"
            }
        }
        
        func matches(_ eventType: MockEvent.EventType) -> Bool {
            switch self {
            case .all: return true
            case .assignments: return eventType == .assignment || eventType == .project
            case .exams: return eventType == .exam || eventType == .quiz
            case .lectures: return eventType == .lecture
            case .labs: return eventType == .lab
            }
        }
    }
    
    init(course: MockCourse) {
        self.course = course
        self._editedCourse = State(initialValue: course)
    }
    
    var filteredEvents: [MockEvent] {
        course.events.filter { event in
            selectedTab.matches(event.type)
        }.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header with matched geometry effect
                    CourseHeaderView(
                        course: course,
                        heroAnimation: heroAnimation
                    )
                    
                    // Tab selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Layout.Spacing.sm) {
                            ForEach(CourseTab.allCases, id: \.self) { tab in
                                CourseTabButton(
                                    tab: tab,
                                    isSelected: selectedTab == tab,
                                    eventCount: getEventCount(for: tab)
                                ) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedTab = tab
                                    }
                                    HapticFeedbackManager.shared.lightImpact()
                                }
                            }
                        }
                        .padding(.horizontal, Layout.Spacing.lg)
                    }
                    .padding(.vertical, Layout.Spacing.md)
                    .background(AppColors.background)
                    
                    // Events list
                    LazyVStack(spacing: Layout.Spacing.md) {
                        ForEach(filteredEvents) { event in
                            CourseEventCard(event: event) {
                                // Navigate to event detail
                                HapticFeedbackManager.shared.lightImpact()
                            }
                        }
                    }
                    .padding(.horizontal, Layout.Spacing.lg)
                    .padding(.vertical, Layout.Spacing.md)
                }
            }
            .background(AppColors.background)
            .navigationBarHidden(true)
            .sheet(isPresented: $showingEditSheet) {
                CourseEditSheet(course: $editedCourse) { updatedCourse in
                    // Save changes (mock)
                    HapticFeedbackManager.shared.success()
                    showingEditSheet = false
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func getEventCount(for tab: CourseTab) -> Int {
        course.events.filter { tab.matches($0.type) }.count
    }
}

// MARK: - Course Header

struct CourseHeaderView: View {
    let course: MockCourse
    let heroAnimation: Namespace.ID
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    course.color.opacity(0.8),
                    course.color.opacity(0.4)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(edges: .top)
            
            VStack(alignment: .leading, spacing: Layout.Spacing.lg) {
                // Navigation
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.lexend(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.black.opacity(0.2))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Button {
                        // Show edit sheet
                        HapticFeedbackManager.shared.lightImpact()
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.lexend(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.black.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                .padding(.top, 60) // Account for status bar
                
                Spacer()
                
                // Course info
                VStack(alignment: .leading, spacing: Layout.Spacing.md) {
                    Text(course.code)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text(course.name)
                        .font(.titleL)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .matchedGeometryEffect(id: "course-\(course.id)", in: heroAnimation)
                    
                    Text(course.professor)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(course.semester)
                        .font(.captionL)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Quick stats
                HStack(spacing: Layout.Spacing.xl) {
                    StatCard(
                        title: "Total Events",
                        value: "\(course.events.count)",
                        icon: "calendar"
                    )
                    
                    StatCard(
                        title: "Completed",
                        value: "\(course.events.filter { $0.isCompleted }.count)",
                        icon: "checkmark.circle"
                    )
                    
                    StatCard(
                        title: "Upcoming",
                        value: "\(course.events.filter { $0.date >= Date() }.count)",
                        icon: "clock"
                    )
                }
                .padding(.bottom, Layout.Spacing.lg)
            }
            .padding(.horizontal, Layout.Spacing.lg)
        }
        .frame(height: 320)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: Layout.Spacing.xs) {
            Image(systemName: icon)
                .font(.lexend(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Text(value)
                .font(.titleS)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Course Tab Button

struct CourseTabButton: View {
    let tab: CourseDetailView.CourseTab
    let isSelected: Bool
    let eventCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Layout.Spacing.xs) {
                Image(systemName: tab.icon)
                    .font(.lexend(size: 14, weight: .medium))
                
                Text(tab.rawValue)
                    .font(.captionL)
                    .fontWeight(.medium)
                
                if eventCount > 0 {
                    Text("\(eventCount)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .white : AppColors.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.3) : AppColors.accent.opacity(0.1))
                        )
                }
            }
            .padding(.horizontal, Layout.Spacing.md)
            .padding(.vertical, Layout.Spacing.sm)
            .foregroundColor(isSelected ? .white : AppColors.textSecondary)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            gradient: Gradient(colors: [Color.purple, Color.blue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        AppColors.surfaceSecondary
                    }
                }
            )
            .cornerRadius(Layout.CornerRadius.md)
            .scaleEffect(isSelected ? 1.0 : 0.95)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Course Event Card

struct CourseEventCard: View {
    let event: MockEvent
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Layout.Spacing.md) {
                // Header
                HStack {
                    HStack(spacing: Layout.Spacing.xs) {
                        Image(systemName: event.type.icon)
                            .font(.lexend(size: 14, weight: .medium))
                            .foregroundColor(event.type.color)
                        
                        Text(event.type.rawValue)
                            .font(.captionL)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(event.date.monthDayName)
                            .font(.captionL)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                        
                        if let time = event.time {
                            Text(time)
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                }
                
                // Title
                Text(event.title)
                    .font(.titleS)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                
                // Details
                if let location = event.location {
                    HStack(spacing: Layout.Spacing.xs) {
                        Image(systemName: "location")
                            .font(.lexend(size: 12, weight: .regular))
                            .foregroundColor(AppColors.textTertiary)
                        
                        Text(location)
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                
                // Status
                if event.isCompleted {
                    HStack(spacing: Layout.Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.lexend(size: 12, weight: .regular))
                            .foregroundColor(.green)
                        
                        Text("Completed")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                } else if event.date < Date() {
                    HStack(spacing: Layout.Spacing.xs) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.lexend(size: 12, weight: .regular))
                            .foregroundColor(.orange)
                        
                        Text("Overdue")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(Layout.Spacing.lg)
            .background(AppColors.surface)
            .cornerRadius(Layout.CornerRadius.lg)
            .cardShadowLight()
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Course Edit Sheet

struct CourseEditSheet: View {
    @Binding var course: MockCourse
    let onSave: (MockCourse) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var courseName: String = ""
    @State private var professorName: String = ""
    @State private var selectedColor: Color = .blue
    
    let availableColors: [Color] = [
        .blue, .green, .purple, .orange, .red, .pink, .teal, .indigo
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.Spacing.xl) {
                    // Course Name
                    VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
                        Text("Course Name")
                            .font(.titleS)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                        
                        TextField("Introduction to Computer Science", text: $courseName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Professor
                    VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
                        Text("Professor")
                            .font(.titleS)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                        
                        TextField("Dr. Sarah Chen", text: $professorName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Color Selection
                    VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
                        Text("Course Color")
                            .font(.titleS)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: Layout.Spacing.md) {
                            ForEach(availableColors, id: \.self) { color in
                                ColorSelectionButton(
                                    color: color,
                                    isSelected: selectedColor == color
                                ) {
                                    selectedColor = color
                                    HapticFeedbackManager.shared.lightImpact()
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(Layout.Spacing.lg)
            }
            .background(AppColors.background)
            .navigationTitle("Edit Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.accent)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        HapticFeedbackManager.shared.mediumImpact()
                        onSave(course)
                    }
                    .foregroundColor(AppColors.accent)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            courseName = course.name
            professorName = course.professor
            selectedColor = course.color
        }
    }
}

struct ColorSelectionButton: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 40, height: 40)
                
                if isSelected {
                    Circle()
                        .stroke(AppColors.accent, lineWidth: 3)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "checkmark")
                        .font(.lexend(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#if DEBUG
struct CourseDetailView_Previews: PreviewProvider {
    static var previews: some View {
        CourseDetailView(course: MockCourse.sampleCourses[0])
            .environmentObject(AppNavigationManager())
    }
}
#endif
