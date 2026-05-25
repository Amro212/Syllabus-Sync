import Foundation

protocol NotificationBehaviorRecording {
    func recordAppOpen(for userId: String, at date: Date)
    func recordNotificationTap(for userId: String, at date: Date)
    func preferredDeliveryHour(for userId: String) -> Int?
    func clear(for userId: String)
}

final class NotificationBehaviorStore: NotificationBehaviorRecording {
    static let shared = NotificationBehaviorStore()

    private struct Snapshot: Codable {
        var appOpens: [Date] = []
        var notificationTaps: [Date] = []
    }

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let minimumOpenCount: Int
    private let maximumSamples: Int

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        minimumOpenCount: Int = 7,
        maximumSamples: Int = 200
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.minimumOpenCount = minimumOpenCount
        self.maximumSamples = maximumSamples
    }

    func recordAppOpen(for userId: String, at date: Date = Date()) {
        updateSnapshot(for: userId) { snapshot in
            snapshot.appOpens.append(date)
            snapshot.appOpens = Array(snapshot.appOpens.suffix(maximumSamples))
        }
    }

    func recordNotificationTap(for userId: String, at date: Date = Date()) {
        updateSnapshot(for: userId) { snapshot in
            snapshot.notificationTaps.append(date)
            snapshot.notificationTaps = Array(snapshot.notificationTaps.suffix(maximumSamples))
        }
    }

    func preferredDeliveryHour(for userId: String) -> Int? {
        let opens = snapshot(for: userId).appOpens
        guard opens.count >= minimumOpenCount else { return nil }

        let counts = Dictionary(grouping: opens) { date in
            calendar.component(.hour, from: date)
        }.mapValues(\.count)

        return counts.sorted { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key < rhs.key
            }
            return lhs.value > rhs.value
        }.first?.key
    }

    func clear(for userId: String) {
        defaults.removeObject(forKey: key(for: userId))
    }

    private func updateSnapshot(for userId: String, mutate: (inout Snapshot) -> Void) {
        var value = snapshot(for: userId)
        mutate(&value)

        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key(for: userId))
    }

    private func snapshot(for userId: String) -> Snapshot {
        guard let data = defaults.data(forKey: key(for: userId)),
              let value = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return Snapshot()
        }
        return value
    }

    private func key(for userId: String) -> String {
        "notificationBehavior.\(userId)"
    }
}
