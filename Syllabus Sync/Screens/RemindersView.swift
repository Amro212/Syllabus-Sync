//
//  RemindersView.swift
//  Syllabus Sync
//
//  Created by Assistant on 2024-01-01.
//

import SwiftUI

struct RemindersView: View {
    @EnvironmentObject var navigationManager: AppNavigationManager
    @EnvironmentObject var eventStore: EventStore
    @EnvironmentObject var importViewModel: ImportViewModel
    
    // UI State
    @State private var isRefreshing = false
    @State private var showingImportView = false
    @State private var editingEvent: EventItem?
    
    // Filtering & Sorting
    @State private var searchText = ""
    @State private var sortOption: SortOption = .dateAsc
    @State private var selectedFilter: ReminderFilter = .all
    @State private var selectedCourse: String? = nil  // nil means "All"
    
    // User State
    @AppStorage("hasAddedEvents") private var hasAddedEvents: Bool = false
    @State private var userSpecificHasAddedEvents: Bool = false

    enum SortOption {
        case dateAsc, dateDesc, course, type
        
        var label: String {
            switch self {
            case .dateAsc: return "Date (Earliest First)"
            case .dateDesc: return "Date (Latest First)"
            case .course: return "Course Code"
            case .type: return "Event Type"
            }
        }
    }
    
    enum ReminderFilter: String, CaseIterable {
        case all = "All"
        case assignments = "Assignments"
        case exams = "Exams"
        case labs = "Labs"
        case lectures = "Lectures"
        case other = "Other"
        
        var icon: String {
            switch self {
            case .all: return "tray.fill" // Generic tray/all icon
            case .assignments: return "doc.text.fill"
            case .exams: return "graduationcap.fill"
            case .labs: return "flask.fill"
            case .lectures: return "person.3.fill"
            case .other: return "star.fill"
            }
        }
        
        func matches(_ eventType: EventItem.EventType) -> Bool {
            switch self {
            case .all: return true
            case .assignments: return eventType == .assignment
            case .exams: return eventType == .midterm || eventType == .final || eventType == .quiz
            case .labs: return eventType == .lab
            case .lectures: return eventType == .lecture
            case .other: return eventType == .other
            }
        }
    }
    
    var filteredEvents: [EventItem] {
        let text = searchText.lowercased()
        let events = eventStore.events.filter { event in
            let matchesSearch = text.isEmpty ||
            event.title.lowercased().contains(text) ||
            event.courseCode.lowercased().contains(text)
            
            let matchesFilter = selectedFilter.matches(event.type)
            
            let matchesCourse = selectedCourse == nil || event.courseCode == selectedCourse
            
            return matchesSearch && matchesFilter && matchesCourse
        }
        
        switch sortOption {
        case .dateAsc: return events.sorted { $0.start < $1.start }
        case .dateDesc: return events.sorted { $0.start > $1.start }
        case .course: return events.sorted { $0.courseCode < $1.courseCode }
        case .type: return events.sorted { $0.type.rawValue < $1.type.rawValue }
        }
    }
    
    // Unique courses from events
    var availableCourses: [String] {
        let courses = Set(eventStore.events.map { $0.courseCode }).filter { !$0.isEmpty }
        return courses.sorted()
    }
    
    enum TimeSection: String, CaseIterable {
        case today = "Today"
        case tomorrow = "Tomorrow"
        case laterThisWeek = "Later This Week"
        case later = "Later"
        
        func contains(_ date: Date) -> Bool {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .today:
                return calendar.isDateInToday(date)
            case .tomorrow:
                return calendar.isDateInTomorrow(date)
            case .laterThisWeek:
                guard !calendar.isDateInToday(date) && !calendar.isDateInTomorrow(date) else { return false }
                guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: now) else { return false }
                return date >= now && date < weekEnd
            case .later:
                guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: now) else { return false }
                return date >= weekEnd
            }
        }
    }
    
    /// Returns the effective date for display/sorting
    /// For recurring events, calculates the next occurrence; otherwise returns the start date
    private func effectiveDate(for event: EventItem) -> Date {
        // If event has a recurrence rule and the start date is in the past, find next occurrence
        guard let _ = event.recurrenceRule, event.start < Date() else {
            return event.start
        }
        
        // For recurring events, calculate next occurrence based on pattern
        // This is a simplified calculation - assumes weekly recurrence (most common for classes)
        let calendar = Calendar.current
        let now = Date()
        var nextDate = event.start
        
        // Keep adding weeks until we find a future occurrence
        // Limit to 52 weeks to prevent infinite loops
        var weeksAdded = 0
        while nextDate < now && weeksAdded < 52 {
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: nextDate) else {
                break
            }
            nextDate = next
            weeksAdded += 1
        }
        
        return nextDate
    }
    
    var groupedEvents: [(TimeSection, [EventItem])] {
        let sorted = filteredEvents.sorted { effectiveDate(for: $0) < effectiveDate(for: $1) }
        var groups: [(TimeSection, [EventItem])] = []
        
        for section in TimeSection.allCases {
            let sectionEvents = sorted.filter { section.contains(effectiveDate(for: $0)) }
            if !sectionEvents.isEmpty {
                groups.append((section, sectionEvents))
            }
        }
        
        return groups
    }

    var body: some View {
        NavigationView {
             GeometryReader { geo in
                 let headerHeight = geo.safeAreaInsets.top + 4
                 
                 ZStack(alignment: .top) {
                     VStack(spacing: 0) {
                         // Search & Sort Bar
                         VStack(spacing: Layout.Spacing.xs) {
                             // Course Filter Bar - only show when events exist
                             if !eventStore.events.isEmpty {
                                 ScrollView(.horizontal, showsIndicators: false) {
                                     HStack(spacing: Layout.Spacing.sm) {
                                         // "All" pill
                                         CourseFilterButton(
                                             title: "All",
                                             isSelected: selectedCourse == nil
                                         ) {
                                             withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                 selectedCourse = nil
                                             }
                                             HapticFeedbackManager.shared.lightImpact()
                                         }
                                         
                                         ForEach(availableCourses, id: \.self) { course in
                                             CourseFilterButton(
                                                 title: course,
                                                 isSelected: selectedCourse == course
                                             ) {
                                                 withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                     selectedCourse = course
                                                 }
                                                 HapticFeedbackManager.shared.lightImpact()
                                             }
                                         }
                                     }
                                     .padding(.horizontal, 4)
                                 }
                             }
                             
                             HStack(spacing: Layout.Spacing.xs) {
                                 // Search Field
                                 HStack {
                                     Image(systemName: "magnifyingglass")
                                         .foregroundColor(AppColors.textSecondary)
                                     TextField("Search reminders...", text: $searchText)
                                         .foregroundColor(AppColors.textPrimary)
                                     
                                     if !searchText.isEmpty {
                                         Button(action: { searchText = "" }) {
                                             Image(systemName: "xmark.circle.fill")
                                                 .foregroundColor(AppColors.textSecondary)
                                         }
                                     }
                                 }
                                 .padding(10)
                                 .background(AppColors.surface)
                                 .cornerRadius(10)
                                 
                                 // Sort Menu
                                 Menu {
                                     Picker("Sort By", selection: Binding(
                                         get: { sortOption },
                                         set: { newValue in
                                             withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                 sortOption = newValue
                                             }
                                         }
                                     )) {
                                         Text("Date (Earliest)").tag(SortOption.dateAsc)
                                         Text("Date (Latest)").tag(SortOption.dateDesc)
                                         Text("Course").tag(SortOption.course)
                                         Text("Type").tag(SortOption.type)
                                     }
                                 } label: {
                                     Image(systemName: "arrow.up.arrow.down")
                                         .font(.system(size: 16, weight: .semibold))
                                         .foregroundColor(AppColors.textPrimary)
                                         .frame(width: 44, height: 44)
                                         .background(AppColors.surface)
                                         .cornerRadius(10)
                                 }
                             }
                             
                             // Event Type Filter Bar
                             ScrollView(.horizontal, showsIndicators: false) {
                                 HStack(spacing: Layout.Spacing.sm) {
                                     ForEach(ReminderFilter.allCases, id: \.self) { filter in
                                         FilterTabButton(
                                             filter: filter,
                                             isSelected: selectedFilter == filter
                                         ) {
                                             withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                 selectedFilter = filter
                                             }
                                             HapticFeedbackManager.shared.lightImpact()
                                         }
                                     }
                                 }
                                 .padding(.horizontal, 4) // Slight inset for scroll
                             }
                         }
                         .padding(.horizontal, Layout.Spacing.md)
                         .padding(.top, headerHeight + 10)
                         .padding(.bottom, Layout.Spacing.md)
                         .background(AppColors.background)
                         .zIndex(1)
                         
                         // List Content
                         if groupedEvents.isEmpty {
                             if !userSpecificHasAddedEvents && searchText.isEmpty && selectedFilter == .all && selectedCourse == nil {
                                 // "New User" Empty State
                                 VStack(spacing: Layout.Spacing.lg) {
                                     Spacer()
                                     Image(systemName: "checklist")
                                         .font(.system(size: 64))
                                         .foregroundColor(AppColors.accent.opacity(0.8))
                                     
                                     Text("No reminders yet")
                                         .font(.title2)
                                         .fontWeight(.bold)
                                         .foregroundColor(AppColors.textPrimary)
                                     
                                     Text("Import your syllabus to automatically generate reminders for assignments and exams.")
                                         .font(.body)
                                         .foregroundColor(AppColors.textSecondary)
                                         .multilineTextAlignment(.center)
                                         .padding(.horizontal, Layout.Spacing.xl)
                                     
                                     Button {
                                         showingImportView = true
                                     } label: {
                                         Text("Import Syllabus")
                                             .fontWeight(.semibold)
                                             .padding(.horizontal, 24)
                                             .padding(.vertical, 12)
                                             .background(AppColors.accent)
                                             .foregroundColor(.white)
                                             .cornerRadius(Layout.CornerRadius.md)
                                     }
                                     Spacer()
                                 }
                                 .frame(maxWidth: .infinity)
                                 
                             } else {
                                 // "Filtered/Empty but Existing" State
                                 VStack(spacing: Layout.Spacing.lg) {
                                     Spacer()
                                     Image(systemName: "magnifyingglass")
                                         .font(.system(size: 48))
                                         .foregroundColor(AppColors.textSecondary.opacity(0.5))
                                     
                                     Text("No reminders found")
                                         .font(.title3)
                                         .fontWeight(.semibold)
                                         .foregroundColor(AppColors.textSecondary)
                                     Spacer()
                                 }
                                 .frame(maxWidth: .infinity)
                             }
                         } else {
                             List {
                                 ForEach(groupedEvents, id: \.0) { section, events in
                                     Section {
                                         ForEach(events) { event in
                                             ReminderCard(event: event)
                                                 .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                                 .listRowSeparator(.hidden)
                                                 .listRowBackground(Color.clear)
                                                 .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                     Button(role: .destructive) {
                                                         deleteEvent(event)
                                                     } label: {
                                                         Label("Delete", systemImage: "trash")
                                                     }
                                                     
                                                     Button {
                                                         editingEvent = event
                                                     } label: {
                                                         Label("Edit", systemImage: "pencil")
                                                     }
                                                     .tint(.blue)
                                                 }
                                                 .swipeActions(edge: .leading) {
                                                      // Future: Mark Complete logic
                                                 }
                                         }
                                     } header: {
                                         Text(section.rawValue)
                                             .font(.system(.title2, design: .default, weight: .bold))
                                             .foregroundColor(AppColors.textPrimary)
                                             .textCase(nil)
                                             .padding(.leading, -4)
                                     }
                                     .listSectionSpacing(8)
                                 }
                             }
                             .listStyle(.plain)
                             .refreshable {
                                 await eventStore.refresh()
                             }
                             .padding(.bottom, 60) // Space for tab bar
                         }
                     }
                     
                     // Sticky Header
                     VStack(spacing: 0) {
                         HStack {
                             Text("Reminders")
                                 .font(.titleL)
                                 .fontWeight(.bold)
                                 .foregroundColor(AppColors.textPrimary)
                             Spacer()
                             Image(systemName: "person.circle")
                                 .font(.system(size: 28))
                                 .foregroundColor(AppColors.textPrimary)
                         }
                         .padding(.horizontal, Layout.Spacing.md)
                         .padding(.bottom, Layout.Spacing.sm)
                         .padding(.top, geo.safeAreaInsets.top)
                         .background(AppColors.background.opacity(0.95))
                         .overlay(alignment: .bottom) { Divider().opacity(0.5) }
                         Spacer()
                     }
                     .frame(height: headerHeight + 50)
                     .ignoresSafeArea(edges: .top)
                     .zIndex(2)
                 }
                 .background(AppColors.background)
             }
             .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingImportView) {
            AISyllabusScanModal()
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(20)
        }
        .sheet(item: $editingEvent) { event in
            EventEditView(event: event, isCreatingNew: false) { updated in
                Task {
                    await importViewModel.applyEditedEvent(updated)
                    editingEvent = nil
                }
            } onCancel: {
                editingEvent = nil
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(20)
        }
        .task {
            loadUserPreference()
            await eventStore.fetchEvents()
            if !eventStore.events.isEmpty {
                updateUserPreference(true)
            }
        }
        .onChange(of: eventStore.events) { events in
            if !events.isEmpty {
                updateUserPreference(true)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func deleteEvent(_ event: EventItem) {
        Task {
            await eventStore.deleteEvent(event)
        }
    }
    
    private func loadUserPreference() {
        guard let userId = SupabaseAuthService.shared.currentUser?.id else { return }
        userSpecificHasAddedEvents = UserDefaults.standard.bool(forKey: "hasAddedEvents_\(userId)")
    }
    
    private func updateUserPreference(_ value: Bool) {
        guard let userId = SupabaseAuthService.shared.currentUser?.id else { return }
        userSpecificHasAddedEvents = value
        UserDefaults.standard.set(value, forKey: "hasAddedEvents_\(userId)")
    }
}

// MARK: - Reminder Card
private struct ReminderCard: View {
    let event: EventItem
    
    var eventColor: Color {
        switch event.type {
        case .assignment: return .blue
        case .quiz, .midterm, .final: return .red
        case .lab: return .green
        case .lecture: return .purple
        case .other: return AppColors.accent
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Color Strip
            Rectangle()
                .fill(eventColor)
                .frame(width: 6)
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(event.title)
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    
                    // Repeat Badge
                    if event.recurrenceRule != nil {
                        Image(systemName: "repeat")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.accent)
                    }
                    
                    Spacer()
                    
                    if let location = event.location {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                            Text(location)
                                .font(.caption)
                        }
                        .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                HStack {
                    Text(event.courseCode)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AppColors.surface.opacity(0.5)) // Darker/Lighter background
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(AppColors.separator, lineWidth: 1)
                        )
                    
                    Spacer()
                    
                    Text(formatDate(event))
                        .font(.subheadline)
                        .foregroundColor(eventColor) // Colored date for emphasis
                        .fontWeight(.medium)
                }
                
                if let notes = event.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            .padding(12)
        }
        .background(AppColors.surface)
        .cornerRadius(12)
        .shadow(color: AppColors.shadow.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func formatDate(_ event: EventItem) -> String {
        let formatter = DateFormatter()
        
        if event.allDay == true {
            // All-day event: show date only with "All Day"
            formatter.dateFormat = "MMM d"
            return formatter.string(from: event.start) + ", All Day"
        } else {
            // Regular event: show date and time
            formatter.dateFormat = "MMM d, h:mm a"
            return formatter.string(from: event.start)
        }
    }
}


// MARK: - Reminders Shimmer

struct RemindersShimmerView: View {
    @State private var animateShimmer = false
    
    var body: some View {
        VStack(spacing: Layout.Spacing.xl) {
            // Header Section
            VStack(spacing: Layout.Spacing.lg) {
                HStack {
                    Text("Refreshing...")
                        .font(.titleM)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Spacer()
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                        .scaleEffect(0.8)
                }
                
                Rectangle()
                    .fill(AppColors.separator)
                    .frame(height: 1)
            }
            .padding(.top, Layout.Spacing.lg)
            
            // Content Shimmer
            VStack(spacing: Layout.Spacing.lg) {
                ForEach(0..<3, id: \.self) { _ in
                    ShimmerCard()
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, Layout.Spacing.md)
    }
}

// MARK: - Preview

// MARK: - Filter Tab Button

struct FilterTabButton: View {
    let filter: RemindersView.ReminderFilter
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
                             gradient: Gradient(colors: [
                                 Color(red: 0.886, green: 0.714, blue: 0.275), // Medium gold
                                 Color(red: 0.816, green: 0.612, blue: 0.118)  // Darker gold
                             ]),
                             startPoint: .topLeading,
                             endPoint: .bottomTrailing
                         )
                         .shadow(color: Color(red: 0.886, green: 0.714, blue: 0.275).opacity(0.4), radius: 8, x: 0, y: 4)
                    } else {
                        AppColors.surface
                            .shadow(color: AppColors.shadow.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                }
            )
            .cornerRadius(20) // Pill shape
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CourseFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Layout.Spacing.xs) {
                Image(systemName: "book.fill")
                    .font(.system(size: 12, weight: .medium))
                
                Text(title)
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
                             gradient: Gradient(colors: [
                                 Color(red: 0.886, green: 0.714, blue: 0.275), // Medium gold
                                 Color(red: 0.816, green: 0.612, blue: 0.118)  // Darker gold
                             ]),
                             startPoint: .topLeading,
                             endPoint: .bottomTrailing
                         )
                         .shadow(color: Color(red: 0.886, green: 0.714, blue: 0.275).opacity(0.4), radius: 8, x: 0, y: 4)
                    } else {
                        AppColors.surface
                            .shadow(color: AppColors.shadow.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                }
            )
            .cornerRadius(20) // Pill shape
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    RemindersView()
        .environmentObject(AppNavigationManager())
        .environmentObject(ThemeManager())
        .environmentObject(EventStore())
        .environmentObject(ImportViewModel(
            extractor: PDFKitExtractor(),
            parser: SyllabusParserRemote(apiClient: URLSessionAPIClient(
                configuration: URLSessionAPIClient.Configuration(
                    baseURL: URL(string: "https://api.example.com")!,
                    requestTimeout: 30,
                    maxRetryCount: 1
                )
            )),
            eventStore: EventStore()
        ))
}
