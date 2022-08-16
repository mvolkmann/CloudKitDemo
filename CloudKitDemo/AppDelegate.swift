import CloudKit
import UIKit

// TODO: Do you need this?
// To use this, register it in the main .swift file.
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(
            options: [.alert, .badge, .sound],
            completionHandler: { authorized, error in
                DispatchQueue.main.async {
                    if authorized {
                        UIApplication.shared.registerForRemoteNotifications()
                        print("AppDelegate: registered for remote notifications")
                    } else {
                        print("AppDelegate: not authorized for remote notifications")
                    }
                }
            }
        )

        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // print(userInfo)
        completionHandler(.newData)

        runAfter(seconds: 1) {
            Task {
                do {
                    try await CloudKitViewModel.shared.retrieveFruits()
                    print("AppDelegate: retrieved fruits")
                } catch {
                    print("AppDelegate: error retrieving fruits; \(error)")
                }
            }
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let cloudKit = CloudKit(containerId: containerId)
        Task {
            do {
                try await cloudKit.subscribe(recordType: "Fruits")
                print("AppDelegate: subscribed to CloudKit")
            } catch {
                print("AppDelegate: subscribe error =", error)
            }
        }
    }
}
