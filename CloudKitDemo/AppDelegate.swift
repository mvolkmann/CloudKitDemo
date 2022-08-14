import CloudKit
import UIKit

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
        didReceiveRemoteNotification userInfo: [AnyHashable : Any]
        //fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        /*
        if let _ = CKNotification(fromRemoteNotificationDictionary: userInfo) {
            print("CloudKit database changed")
            /*
            NotificationCenter.default.post(
                name: .cloudKitChanged,
                object: nil
            )
            */
            completionHandler(.newData)
        }
        */
        let dict = userInfo as! [String: NSObject]
        let notification = CKNotification(fromRemoteNotificationDictionary: dict)
        if let id = notification?.subscriptionID {
            print("AppDelegate: subscription ID =", id)
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Add CloudKit subscriptions here.
        let cloudKit = CloudKit(
            containerId: "iCloud.com.objectcomputing.swiftui-cloudkit-core-data"
        )
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
