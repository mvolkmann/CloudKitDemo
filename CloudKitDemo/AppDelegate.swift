import CloudKit
import UIKit

// TODO: Do you need this?
// To use this, register it in the main .swift file.
class AppDelegate: UIResponder, UIApplicationDelegate,
    UNUserNotificationCenterDelegate {
    
    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(
            options: [.alert, .badge, .sound],
            completionHandler: { authorized, _ in
                DispatchQueue.main.async {
                    if authorized {
                        UIApplication.shared.registerForRemoteNotifications()
                    } else {
                        print(
                            "AppDelegate: not authorized for remote notifications"
                        )
                    }
                }
            }
        )

        return true
    }

    func application(
        _: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (
            UIBackgroundFetchResult
        )
            -> Void
    ) {
        completionHandler(.newData)

        // Determine the operation type.
        // print(userInfo)
        // swiftlint:disable force_cast
        let cloudkit = userInfo["ck"] as! [AnyHashable: Any]
        let query = cloudkit["qry"] as! [AnyHashable: Any]
        let operationType = query["fo"] as! Int

        // operationType is an integer that indicates the operation type.
        // It is is 1 for create, 2 for update, and 3 for delete
        // If a record has been updated or deleted,
        // we do not need to wait to retrieve new fruits.
        // However, if a record has been added then we do need to wait.
        // Waiting one second seems to work, but is that reliable?
        var seconds = 0
        if operationType == 1 { seconds = 1 }

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
        _: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken _: Data
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
