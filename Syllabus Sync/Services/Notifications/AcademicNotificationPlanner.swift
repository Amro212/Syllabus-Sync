import Foundation

struct PlannedAcademicNotification: Equatable {
    enum Stage: String, Equatable {
        case early
        case final
    }

    let identifier: String
    let eventId: String
    let stage: Stage
    let title: String
    let body: String
    let deliveryDate: Date
    let userInfo: [String: String]
}

struct AcademicNotificationPlanner {
    static let requestIdentifierPrefix = "syllabus-sync.event"

    private let calendar: Calendar
    private let now: Date
    private let preferredHour: Int?
    private let eventLimit: Int

    init(
        calendar: Calendar = .current,
        now: Date = Date(),
        preferredHour: Int?,
        eventLimit: Int = 32
    ) {
        self.calendar = calendar
        self.now = now
        self.preferredHour = preferredHour
        self.eventLimit = eventLimit
    }

    func plan(for events: [EventItem]) -> [PlannedAcademicNotification] {
        eligibleEvents(from: events)
            .prefix(eventLimit)
            .flatMap { plannedNotifications(for: $0) }
            .filter { $0.deliveryDate > now }
            .sorted { lhs, rhs in
                if lhs.deliveryDate == rhs.deliveryDate {
                    return lhs.identifier < rhs.identifier
                }
                return lhs.deliveryDate < rhs.deliveryDate
            }
    }

    private func eligibleEvents(from events: [EventItem]) -> [EventItem] {
        events
            .filter { event in
                Self.isAssessment(event.type)
                    && !event.needsDate
                    && event.start > now
            }
            .sorted { lhs, rhs in
                if lhs.start == rhs.start {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                return lhs.start < rhs.start
            }
    }

    private func plannedNotifications(for event: EventItem) -> [PlannedAcademicNotification] {
        reminderOffsets(for: event.type).compactMap { offset in
            guard let deliveryDate = deliveryDate(for: event, daysBefore: offset.daysBefore) else {
                return nil
            }

            return PlannedAcademicNotification(
                identifier: Self.identifier(eventId: event.id, stage: offset.stage),
                eventId: event.id,
                stage: offset.stage,
                title: notificationTitle(for: event, stage: offset.stage),
                body: notificationBody(for: event, daysBefore: offset.daysBefore),
                deliveryDate: deliveryDate,
                userInfo: [
                    "eventId": event.id,
                    "courseCode": event.courseCode,
                    "stage": offset.stage.rawValue,
                    "scheduledFor": ISO8601DateFormatter().string(from: deliveryDate)
                ]
            )
        }
    }

    private func deliveryDate(for event: EventItem, daysBefore: Int) -> Date? {
        guard let reminderDay = calendar.date(byAdding: .day, value: -daysBefore, to: event.start) else {
            return nil
        }

        if event.allDay == true {
            return calendar.date(
                bySettingHour: preferredHour ?? 20,
                minute: 0,
                second: 0,
                of: reminderDay
            )
        }

        guard let learnedHour = preferredHour else {
            return reminderDay
        }

        return calendar.date(
            bySettingHour: learnedHour,
            minute: 0,
            second: 0,
            of: reminderDay
        )
    }

    private func reminderOffsets(for type: EventItem.EventType) -> [(stage: PlannedAcademicNotification.Stage, daysBefore: Int)] {
        switch type {
        case .midterm, .final:
            return [(.early, 7), (.final, 1)]
        case .assignment, .quiz, .lab, .importantDate:
            return [(.early, 2), (.final, 1)]
        case .lecture, .tutorial, .officeHours, .other:
            return []
        }
    }

    private func notificationTitle(for event: EventItem, stage: PlannedAcademicNotification.Stage) -> String {
        switch stage {
        case .early:
            return "\(event.courseCode): upcoming \(displayName(for: event.type).lowercased())"
        case .final:
            return "\(event.courseCode): due soon"
        }
    }

    private func notificationBody(for event: EventItem, daysBefore: Int) -> String {
        "\(event.title) is \(daysBefore == 1 ? "tomorrow" : "in \(daysBefore) days")."
    }

    private func displayName(for type: EventItem.EventType) -> String {
        switch type {
        case .assignment: return "Assignment"
        case .quiz: return "Quiz"
        case .midterm: return "Midterm"
        case .final: return "Final"
        case .lab: return "Lab"
        case .lecture: return "Lecture"
        case .tutorial: return "Tutorial"
        case .officeHours: return "Office Hours"
        case .importantDate: return "Important Date"
        case .other: return "Event"
        }
    }

    static func identifier(eventId: String, stage: PlannedAcademicNotification.Stage) -> String {
        "\(requestIdentifierPrefix).\(eventId).\(stage.rawValue)"
    }

    static func isAssessment(_ type: EventItem.EventType) -> Bool {
        switch type {
        case .assignment, .quiz, .midterm, .final, .lab, .importantDate:
            return true
        case .lecture, .tutorial, .officeHours, .other:
            return false
        }
    }
}
