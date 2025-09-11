 //
//  MockData.swift
//  Syllabus Sync
//
//  Created by Cursor on 2025-09-06.
//

import Foundation
import SwiftUI

// MARK: - Mock Course Model

struct MockCourse: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let code: String
    let professor: String
    let color: Color
    let semester: String
    let events: [MockEvent]
    
    static let sampleCourses: [MockCourse] = [
        MockCourse(
            name: "Introduction to Computer Science",
            code: "CS 101",
            professor: "Dr. Sarah Chen",
            color: .blue,
            semester: "Fall 2024",
            events: MockEvent.cs101Events
        ),
        MockCourse(
            name: "Calculus II",
            code: "MATH 152",
            professor: "Prof. Michael Rodriguez",
            color: .green,
            semester: "Fall 2024",
            events: MockEvent.math152Events
        ),
        MockCourse(
            name: "Introduction to Psychology",
            code: "PSYC 101",
            professor: "Dr. Emily Johnson",
            color: .purple,
            semester: "Fall 2024",
            events: MockEvent.psyc101Events
        )
    ]
}

// MARK: - Mock Event Model

struct MockEvent: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let type: EventType
    let date: Date
    let time: String?
    let location: String?
    let description: String?
    let courseCode: String
    let isCompleted: Bool
    
    enum EventType: String, CaseIterable {
        case assignment = "Assignment"
        case exam = "Exam"
        case lecture = "Lecture"
        case lab = "Lab"
        case quiz = "Quiz"
        case project = "Project"
        case reading = "Reading"
        
        var color: Color {
            switch self {
            case .assignment: return .orange
            case .exam: return .red
            case .lecture: return .blue
            case .lab: return .green
            case .quiz: return .yellow
            case .project: return .purple
            case .reading: return .brown
            }
        }
        
        var icon: String {
            switch self {
            case .assignment: return "doc.text"
            case .exam: return "graduationcap"
            case .lecture: return "person.fill"
            case .lab: return "flask"
            case .quiz: return "questionmark.circle"
            case .project: return "folder"
            case .reading: return "book"
            }
        }
    }
}

// MARK: - Sample Events

extension MockEvent {
    
    static let cs101Events: [MockEvent] = [
        MockEvent(
            title: "Assignment 1: Variables and Data Types",
            type: .assignment,
            date: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date(),
            time: "11:59 PM",
            location: nil,
            description: "Complete exercises 1-15 in Chapter 2. Focus on understanding variable declarations and basic data types.",
            courseCode: "CS 101",
            isCompleted: false
        ),
        MockEvent(
            title: "Introduction to Programming",
            type: .lecture,
            date: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
            time: "10:00 AM",
            location: "Room 204",
            description: "Overview of programming concepts and Python basics.",
            courseCode: "CS 101",
            isCompleted: false
        ),
        MockEvent(
            title: "Lab 1: Setting Up Development Environment",
            type: .lab,
            date: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date(),
            time: "2:00 PM",
            location: "Computer Lab A",
            description: "Install Python, VS Code, and configure your development environment.",
            courseCode: "CS 101",
            isCompleted: false
        ),
        MockEvent(
            title: "Quiz 1: Basic Syntax",
            type: .quiz,
            date: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date(),
            time: "10:00 AM",
            location: "Room 204",
            description: "20-minute quiz covering Python syntax from chapters 1-2.",
            courseCode: "CS 101",
            isCompleted: false
        ),
        MockEvent(
            title: "Midterm Exam",
            type: .exam,
            date: Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date(),
            time: "10:00 AM",
            location: "Room 204",
            description: "Comprehensive exam covering all material from weeks 1-7.",
            courseCode: "CS 101",
            isCompleted: false
        )
    ]
    
    static let math152Events: [MockEvent] = [
        MockEvent(
            title: "Homework 3: Integration by Parts",
            type: .assignment,
            date: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
            time: "11:59 PM",
            location: nil,
            description: "Complete problems 1-20 from section 7.1. Show all work.",
            courseCode: "MATH 152",
            isCompleted: false
        ),
        MockEvent(
            title: "Integration Techniques",
            type: .lecture,
            date: Date(),
            time: "9:00 AM",
            location: "Math Building 301",
            description: "Advanced integration methods including substitution and by parts.",
            courseCode: "MATH 152",
            isCompleted: true
        ),
        MockEvent(
            title: "Reading: Chapter 7.2-7.3",
            type: .reading,
            date: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date(),
            time: nil,
            location: nil,
            description: "Read sections on trigonometric integrals and partial fractions.",
            courseCode: "MATH 152",
            isCompleted: false
        ),
        MockEvent(
            title: "Quiz 4: Integration Methods",
            type: .quiz,
            date: Calendar.current.date(byAdding: .day, value: 4, to: Date()) ?? Date(),
            time: "9:00 AM",
            location: "Math Building 301",
            description: "Quiz covering integration by parts and substitution.",
            courseCode: "MATH 152",
            isCompleted: false
        ),
        MockEvent(
            title: "Final Project: Applied Integration",
            type: .project,
            date: Calendar.current.date(byAdding: .day, value: 21, to: Date()) ?? Date(),
            time: "11:59 PM",
            location: nil,
            description: "Choose a real-world problem and solve using integration techniques.",
            courseCode: "MATH 152",
            isCompleted: false
        )
    ]
    
    static let psyc101Events: [MockEvent] = [
        MockEvent(
            title: "Research Paper Draft",
            type: .assignment,
            date: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
            time: "11:59 PM",
            location: nil,
            description: "Submit first draft of your research paper (5-7 pages).",
            courseCode: "PSYC 101",
            isCompleted: false
        ),
        MockEvent(
            title: "Cognitive Psychology",
            type: .lecture,
            date: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
            time: "1:00 PM",
            location: "Psychology Building 150",
            description: "Introduction to memory, attention, and perception.",
            courseCode: "PSYC 101",
            isCompleted: false
        ),
        MockEvent(
            title: "Lab 2: Memory Experiments",
            type: .lab,
            date: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date(),
            time: "3:00 PM",
            location: "Psych Lab B",
            description: "Participate in memory recall experiments and analyze data.",
            courseCode: "PSYC 101",
            isCompleted: false
        ),
        MockEvent(
            title: "Reading: Chapters 6-7",
            type: .reading,
            date: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date(),
            time: nil,
            location: nil,
            description: "Read about learning and memory processes.",
            courseCode: "PSYC 101",
            isCompleted: false
        ),
        MockEvent(
            title: "Final Exam",
            type: .exam,
            date: Calendar.current.date(byAdding: .day, value: 28, to: Date()) ?? Date(),
            time: "1:00 PM",
            location: "Psychology Building 150",
            description: "Comprehensive final exam covering all course material.",
            courseCode: "PSYC 101",
            isCompleted: false
        )
    ]
    
    // All events combined for timeline view
    static let allSampleEvents: [MockEvent] = {
        return cs101Events + math152Events + psyc101Events
    }()
}

// MARK: - Helper Extensions

extension Date {
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(self)
    }
    
    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }
    
    func isSameDay(as date: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: date)
    }
    
    var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: self)
    }
    
    var monthDayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: self)
    }
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: self)
    }
}
