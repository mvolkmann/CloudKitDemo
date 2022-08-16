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
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        completionHandler(.newData)

        // Determine the operation type.
        // print(userInfo)
        let ck = userInfo["ck"] as! [AnyHashable: Any]
        let qry = ck["qry"] as! [AnyHashable: Any]
        let fo = qry["fo"] as! Int

        // fo is an integer that indicates the operation type.
        // It is is 1 for create, 2 for update, and 3 for delete
        // If a record has been updated or deleted,
        // we do not need to wait to retrieve new fruits.
        // However, if a record has been added then we do need to wait.
        // Waiting one second seems to work, but is that reliable?
        var seconds = 0
        if fo == 1 { seconds = 1 }

        runAfter(seconds: seconds) {
            Task {
                do {
                    try await CloudKitViewModel.shared.retrieveFruits()
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
            } catch {
                print("AppDelegate: subscribe error =", error)
            }
        }
    }
}
