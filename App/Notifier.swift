import Foundation
import UserNotifications

/// "Command finished" notifications for long commands in tabs you are not looking at.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()
    /// Commands shorter than this never notify.
    static let longCommandSeconds: TimeInterval = 10
    var onOpenTab: ((UUID) -> Void)?
    private var requested = false

    func requestAuthorization() {
        guard !requested, Bundle.main.bundleIdentifier != nil else { return }
        requested = true
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func commandFinished(title: String, command: String, exitCode: Int32?, duration: TimeInterval, tab: UUID) {
        let content = UNMutableNotificationContent()
        let ok = (exitCode ?? 0) == 0
        content.title = ok ? "Finished: \(title)" : "Failed: \(title)"
        let secs = duration >= 90 ? String(format: "%.0f min", duration / 60) : String(format: "%.0f s", duration)
        content.body = "\(command.prefix(80)) — \(ok ? "done" : "exit \(exitCode ?? -1)") after \(secs)"
        content.sound = .default
        content.userInfo = ["tab": tab.uuidString]
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    // Show banners even while the app is frontmost (the tab just isn't the one on screen).
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let s = response.notification.request.content.userInfo["tab"] as? String, let id = UUID(uuidString: s) {
            DispatchQueue.main.async { self.onOpenTab?(id) }
        }
        completionHandler()
    }
}
