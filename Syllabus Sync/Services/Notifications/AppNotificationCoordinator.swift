import Foundation
import UserNotifications

@MainActor
final class AppNotificationCoordinator: NSObject, ObservableObject {
    static let shared = AppNotificationCoordinator()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let authorizationService: NotificationAuthorizationProviding
    private let scheduler: AcademicNotificationScheduling
    private let behaviorStore: NotificationBehaviorRecording
    private var isConfigured = false

    init(
        authorizationService: NotificationAuthorizationProviding = NotificationAuthorizationService(),
        scheduler: AcademicNotificationScheduling = AcademicNotificationScheduler(),
        behaviorStore: NotificationBehaviorRecording = NotificationBehaviorStore.shared
    ) {
        self.authorizationService = authorizationService
        self.scheduler = scheduler
        self.behaviorStore = behaviorStore
        super.init()
    }

    func configure() {
        guard !isConfigured else { return }
        UNUserNotificationCenter.current().delegate = self
        isConfigured = true
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await authorizationService.authorizationStatus()
    }

    func requestAuthorization() async {
        _ = await authorizationService.requestAuthorization()
        await refreshAuthorizationStatus()
    }

    func recordAppOpen() {
        guard let userId = SupabaseAuthService.shared.currentUser?.id else { return }
        behaviorStore.recordAppOpen(for: userId, at: Date())
    }

    func reconcile(events: [EventItem]) async {
        guard let userId = SupabaseAuthService.shared.currentUser?.id else {
            scheduler.cancelAll()
            return
        }

        await refreshAuthorizationStatus()

        guard await notificationsEnabled() else {
            scheduler.cancelAll()
            return
        }

        await scheduler.reconcile(
            events: events,
            userId: userId,
            preferredHour: behaviorStore.preferredDeliveryHour(for: userId)
        )
    }

    func applyNotificationPreference(_ enabled: Bool, events: [EventItem]) async {
        guard let userId = SupabaseAuthService.shared.currentUser?.id else {
            scheduler.cancelAll()
            return
        }

        await refreshAuthorizationStatus()

        guard enabled else {
            scheduler.cancelAll()
            return
        }

        await scheduler.reconcile(
            events: events,
            userId: userId,
            preferredHour: behaviorStore.preferredDeliveryHour(for: userId)
        )
    }

    func cancel(eventId: String) {
        scheduler.cancel(eventId: eventId)
    }

    func clearForSignOut(userId: String?) {
        if let userId {
            behaviorStore.clear(for: userId)
        }
        scheduler.cancelAll()
    }

    private func notificationsEnabled() async -> Bool {
        await SocialHubService.shared.fetchUserPreferences()?.notificationsEnabled ?? true
    }
}

extension AppNotificationCoordinator: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let userId = response.notification.request.content.userInfo["userId"] as? String else {
            return
        }

        await MainActor.run {
            behaviorStore.recordNotificationTap(for: userId, at: Date())
        }
    }
}
