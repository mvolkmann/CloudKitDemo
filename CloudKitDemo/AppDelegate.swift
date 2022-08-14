import CloudKit
import UIKit

// To use this, register it in the main .swift file.
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UIApplication.shared.registerForRemoteNotifications()
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
        if let sub = notification?.subscriptionID {
            print("AppDelegate: sub =", sub)
        }
    }
}
