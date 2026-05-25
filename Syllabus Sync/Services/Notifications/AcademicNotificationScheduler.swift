import Foundation
import UserNotifications

protocol AcademicNotificationScheduling {
    func reconcile(events: [EventItem], userId: String, preferredHour: Int?) async
    func cancel(eventId: String)
    func cancelAll()
}

struct AcademicNotificationScheduler: AcademicNotificationScheduling {
    private let center: UNUserNotificationCenter
    private let calendar: Calendar

    init(center: UNUserNotificationCenter = .current(), calendar: Calendar = .current) {
        self.center = center
        self.calendar = calendar
    }

    func reconcile(events: [EventItem], userId: String, preferredHour: Int?) async {
        let status = await center.notificationSettings().authorizationStatus
        guard Self.canSchedule(status) else {
            cancelAll()
            return
        }

        let planner = AcademicNotificationPlanner(calendar: calendar, preferredHour: preferredHour)
        let planned = planner.plan(for: events)
        let plannedIds = Set(planned.map(\.identifier))
        let pending = await center.pendingNotificationRequests()
        let ownedPending = pending.filter { $0.identifier.hasPrefix(AcademicNotificationPlanner.requestIdentifierPrefix) }
        let staleIds = ownedPending
            .map(\.identifier)
            .filter { !plannedIds.contains($0) }

        if !staleIds.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: staleIds)
        }

        let existingIds = Set(ownedPending.map(\.identifier)).subtracting(staleIds)
        for notification in planned where !existingIds.contains(notification.identifier) {
            schedule(notification, userId: userId)
        }
    }

    func cancel(eventId: String) {
        center.removePendingNotificationRequests(withIdentifiers: [
            AcademicNotificationPlanner.identifier(eventId: eventId, stage: .early),
            AcademicNotificationPlanner.identifier(eventId: eventId, stage: .final)
        ])
    }

    func cancelAll() {
        Task {
            let pending = await center.pendingNotificationRequests()
            let ids = pending
                .map(\.identifier)
                .filter { $0.hasPrefix(AcademicNotificationPlanner.requestIdentifierPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private func schedule(_ notification: PlannedAcademicNotification, userId: String) {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        content.userInfo = notification.userInfo.merging(["userId": userId]) { current, _ in current }

        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notification.deliveryDate)
        components.calendar = calendar
        components.timeZone = calendar.timeZone

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: notification.identifier, content: content, trigger: trigger)
        center.add(request) { error in
            if let error {
                print("Failed to schedule notification \(notification.identifier): \(error)")
            }
        }
    }

    private static func canSchedule(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }
}
