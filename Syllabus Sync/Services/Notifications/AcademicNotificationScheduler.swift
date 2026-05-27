import Foundation
import UserNotifications

protocol AcademicNotificationScheduling {
    func reconcile(events: [EventItem], userId: String, preferredHour: Int?) async
    func cancel(eventId: String)
    func cancelAll() async
}

protocol UserNotificationCenterProviding {
    func authorizationStatus() async -> UNAuthorizationStatus
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func add(_ request: UNNotificationRequest) async throws
}

extension UNUserNotificationCenter: UserNotificationCenterProviding {
    func authorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }
}

struct AcademicNotificationScheduler: AcademicNotificationScheduling {
    private let center: UserNotificationCenterProviding
    private let calendar: Calendar

    init(center: UserNotificationCenterProviding = UNUserNotificationCenter.current(), calendar: Calendar = .current) {
        self.center = center
        self.calendar = calendar
    }

    func reconcile(events: [EventItem], userId: String, preferredHour: Int?) async {
        let status = await center.authorizationStatus()
        guard Self.canSchedule(status) else {
            await cancelAll()
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

        let existingPlannedIds = ownedPending
            .map(\.identifier)
            .filter { plannedIds.contains($0) }
        let idsToReplace = staleIds + existingPlannedIds

        if !idsToReplace.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: idsToReplace)
        }

        for notification in planned {
            await schedule(notification, userId: userId)
        }
    }

    func cancel(eventId: String) {
        center.removePendingNotificationRequests(withIdentifiers: [
            AcademicNotificationPlanner.identifier(eventId: eventId, stage: .early),
            AcademicNotificationPlanner.identifier(eventId: eventId, stage: .final)
        ])
    }

    func cancelAll() async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(AcademicNotificationPlanner.requestIdentifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func schedule(_ notification: PlannedAcademicNotification, userId: String) async {
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
        do {
            try await center.add(request)
        } catch {
            print("Failed to schedule notification \(notification.identifier): \(error)")
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
