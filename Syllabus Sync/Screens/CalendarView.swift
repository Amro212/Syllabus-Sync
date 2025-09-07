//
//  CalendarView.swift
//  Syllabus Sync
//
//  Created by Cursor on 2025-09-06.
//

import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var navigationManager: AppNavigationManager
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var selectedDate = Date()
    @State private var showingEventDetail: MockEvent?
    @State private var events = MockEvent.allSampleEvents
    @State private var selectedFilter: EventFilter = .all
    
    enum EventFilter: String, CaseIterable {
        case all = "All"
        case today = "Today"
        case thisWeek = "This Week"
        case upcoming = "Upcoming"
        
        var icon: String {
            switch self {
            case .all: return "calendar"
            case .today: return "clock"
            case .thisWeek: return "calendar.badge.clock"
            case .upcoming: return "arrow.right.circle"
            }
        }
    }
    
    var filteredEvents: [MockEvent] {
        let now = Date()
        
        switch selectedFilter {
        case .all:
            return events.sorted { $0.date < $1.date }
        case .today:
            return events.filter { Calendar.current.isDateInToday($0.date) }
                .sorted { $0.date < $1.date }
        case .thisWeek:
            return events.filter { $0.date.isThisWeek }
                .sorted { $0.date < $1.date }
        case .upcoming:
            return events.filter { $0.date >= now }
                .sorted { $0.date < $1.date }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Layout.Spacing.sm) {
                        ForEach(EventFilter.allCases, id: \.self) { filter in
                            FilterPill(
                                filter: filter,
                                isSelected: selectedFilter == filter
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedFilter = filter
                                }
                                HapticFeedbackManager.shared.lightImpact()
                            }
                        }
                    }
                    .padding(.horizontal, Layout.Spacing.lg)
                }
                .padding(.vertical, Layout.Spacing.md)
                
                // Events Timeline
                if filteredEvents.isEmpty {
                    EmptyStateView(filter: selectedFilter)
                } else {
                    ScrollView {
                        LazyVStack(spacing: Layout.Spacing.md) {
                            ForEach(filteredEvents) { event in
                                TimelineEventCard(event: event) {
                                    showingEventDetail = event
                                }
                            }
                        }
                        .padding(.horizontal, Layout.Spacing.lg)
                        .padding(.vertical, Layout.Spacing.md)
                    }
                }
                
                Spacer()
            }
            .background(AppColors.background)
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $showingEventDetail) { event in
                EventDetailSheet(event: event)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Filter Pill

struct FilterPill: View {
    let filter: CalendarView.EventFilter
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Layout.Spacing.xs) {
                Image(systemName: filter.icon)
                    .font(.system(size: 14, weight: .medium))
                
                Text(filter.rawValue)
                    .font(.captionL)
                    .fontWeight(.medium)
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

// MARK: - Timeline Event Card

struct TimelineEventCard: View {
    let event: MockEvent
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            HapticFeedbackManager.shared.lightImpact()
            onTap()
        }) {
            HStack(spacing: Layout.Spacing.md) {
                // Date & Time Column
                VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                    if event.date.isToday {
                        Text("Today")
                            .font(.captionL)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.accent)
                    } else if event.date.isTomorrow {
                        Text("Tomorrow")
                            .font(.captionL)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.textSecondary)
                    } else {
                        Text(event.date.monthDayName)
                            .font(.captionL)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    if let time = event.time {
                        Text(time)
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                .frame(width: 60, alignment: .leading)
                
                // Event Type Indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(event.type.color)
                    .frame(width: 4)
                    .frame(maxHeight: .infinity)
                
                // Event Content
                VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                    HStack(spacing: Layout.Spacing.xs) {
                        Image(systemName: event.type.icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(event.type.color)
                        
                        Text(event.type.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.textSecondary)
                        
                        Spacer()
                        
                        Text(event.courseCode)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.accent)
                    }
                    
                    Text(event.title)
                        .font(.titleS)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    
                    if let location = event.location {
                        HStack(spacing: Layout.Spacing.xs) {
                            Image(systemName: "location")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textTertiary)
                            
                            Text(location)
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                    
                    if event.isCompleted {
                        HStack(spacing: Layout.Spacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                            
                            Text("Completed")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(Layout.Spacing.lg)
            .background(AppColors.surface)
            .cornerRadius(Layout.CornerRadius.lg)
            .shadow(
                color: AppColors.shadow.opacity(0.1),
                radius: Layout.Shadow.medium.radius,
                x: Layout.Shadow.medium.x,
                y: Layout.Shadow.medium.y
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            EventContextMenu(event: event)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Context Menu

struct EventContextMenu: View {
    let event: MockEvent
    
    var body: some View {
        Button {
            HapticFeedbackManager.shared.lightImpact()
            // Toggle completion status (mock)
        } label: {
            Label(
                event.isCompleted ? "Mark Incomplete" : "Mark Complete",
                systemImage: event.isCompleted ? "xmark.circle" : "checkmark.circle"
            )
        }
        
        Button {
            HapticFeedbackManager.shared.lightImpact()
            // Edit event (mock)
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        
        Button {
            HapticFeedbackManager.shared.lightImpact()
            // Share event (mock)
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        
        Divider()
        
        Button(role: .destructive) {
            HapticFeedbackManager.shared.warning()
            // Delete event (mock)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let filter: CalendarView.EventFilter
    
    var body: some View {
        VStack(spacing: Layout.Spacing.xl) {
            Spacer()
            
            VStack(spacing: Layout.Spacing.lg) {
                ZStack {
                    Circle()
                        .fill(AppColors.accent.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .fill(AppColors.accent.opacity(0.15))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: filter.icon)
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(AppColors.accent)
                }
                .shadow(
                    color: AppColors.accent.opacity(0.2),
                    radius: 20,
                    x: 0,
                    y: 10
                )
            }
            
            VStack(spacing: Layout.Spacing.md) {
                Text("No Events \(filter.rawValue)")
                    .font(.titleL)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(emptyStateMessage)
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
    
    private var emptyStateMessage: String {
        switch filter {
        case .all:
            return "Import your syllabi to see all your assignments, exams, and events in one place."
        case .today:
            return "No events scheduled for today. Time to relax!"
        case .thisWeek:
            return "No events this week. Check back later or try a different filter."
        case .upcoming:
            return "All caught up! No upcoming events to show."
        }
    }
}

// MARK: - Event Detail Sheet

struct EventDetailSheet: View {
    let event: MockEvent
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.Spacing.xl) {
                    // Header
                    VStack(alignment: .leading, spacing: Layout.Spacing.md) {
                        HStack {
                            HStack(spacing: Layout.Spacing.xs) {
                                Image(systemName: event.type.icon)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(event.type.color)
                                
                                Text(event.type.rawValue)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            Spacer()
                            
                            Text(event.courseCode)
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.accent)
                        }
                        
                        Text(event.title)
                            .font(.titleL)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textPrimary)
                    }
                    
                    // Details
                    VStack(alignment: .leading, spacing: Layout.Spacing.lg) {
                        DetailRow(
                            icon: "calendar",
                            title: "Date",
                            value: DateFormatter.eventDetail.string(from: event.date)
                        )
                        
                        if let time = event.time {
                            DetailRow(
                                icon: "clock",
                                title: "Time",
                                value: time
                            )
                        }
                        
                        if let location = event.location {
                            DetailRow(
                                icon: "location",
                                title: "Location",
                                value: location
                            )
                        }
                        
                        if let description = event.description {
                            VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
                                HStack(spacing: Layout.Spacing.sm) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(AppColors.accent)
                                        .frame(width: 20)
                                    
                                    Text("Description")
                                        .font(.body)
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppColors.textPrimary)
                                }
                                
                                Text(description)
                                    .font(.body)
                                    .foregroundColor(AppColors.textSecondary)
                                    .lineSpacing(4)
                                    .padding(.leading, 28)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(Layout.Spacing.lg)
            }
            .background(AppColors.background)
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.accent)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        // Edit functionality (mock)
                        HapticFeedbackManager.shared.lightImpact()
                    }
                    .foregroundColor(AppColors.accent)
                }
            }
        }
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: Layout.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppColors.accent)
                .frame(width: 20)
            
            Text(title)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .foregroundColor(AppColors.textSecondary)
        }
    }
}

// MARK: - Date Formatter Extension

extension DateFormatter {
    static let eventDetail: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()
}

// MARK: - Preview

#if DEBUG
struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarView()
            .environmentObject(AppNavigationManager())
            .environmentObject(ThemeManager())
    }
}
#endif
