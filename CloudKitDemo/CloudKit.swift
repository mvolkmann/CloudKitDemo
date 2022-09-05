// This is a heavily modified version of CloudKitUtility.swift
// from Nick Sarno of Swiftful Thinking at
// https://github.com/SwiftfulThinking/SwiftUI-Advanced-Learning/blob/main/
// SwiftfulThinkingAdvancedLearning/CloudKitBootcamps/CloudKitUtility.swift

import CloudKit
import UIKit

protocol CloudKitable {
    // This must be an optional initializer
    // due to this line in the retreive method:
    // guard let item = T(record: record) else { return }
    init?(record: CKRecord)

    var record: CKRecord { get }
}

struct CloudKit {
    typealias Cursor = CKQueryOperation.Cursor

    // MARK: - Initializer

    init(containerId: String, usePublic: Bool = false) {
        // TODO: This doesn't result in pointing to the correct container.  Why?
        // container = CKContainer.default()

        // I discovered this container identifier by looking in CloudKitDemo.entitlements.
        // "CloudKit Console" button in "Signing & Capabilities"
        // under "Ubiquity Container Identifiers".
        // TODO: Why did it use this identifier instead of the one
        // TODO: specified in Signing & Capabilities ... Containers?

        container = CKContainer(identifier: containerId)

        database = usePublic ?
            container.publicCloudDatabase :
            container.privateCloudDatabase
    }

    // MARK: - Properties

    var container: CKContainer!
    var database: CKDatabase!

    // MARK: - Non-CRUD Methods

    private func createOperation(
        recordType: CKRecord.RecordType,
        predicate: NSPredicate,
        sortDescriptors: [NSSortDescriptor]? = nil,
        resultsLimit: Int? = nil
    ) -> CKQueryOperation {
        let query = CKQuery(recordType: recordType, predicate: predicate)
        query.sortDescriptors = sortDescriptors
        let operation = CKQueryOperation(query: query)
        if let limit = resultsLimit { operation.resultsLimit = limit }
        return operation
    }

    func requestNotifications() async throws {
        let center = UNUserNotificationCenter.current()
        let options: UNAuthorizationOptions = [.alert, .badge, .sound]
        try await center.requestAuthorization(options: options)
        await UIApplication.shared.registerForRemoteNotifications()
    }

    // Notifications are only delivered to real devices, not to the Simulator.
    // They are only delivered if the app is not currently in the foreground.
    func subscribeToNotifications() async throws {
        let predicate = NSPredicate(value: true) // all records
        let subscription = CKQuerySubscription(
            recordType: "Fruits",
            predicate: predicate,
            subscriptionID: "fruit_added",
            options: .firesOnRecordCreation
        )

        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info

        try await database.save(subscription)
    }

    func requestPermission() async throws
    -> CKContainer.ApplicationPermissionStatus {
        try await container.applicationPermissionStatus(
            for: [.userDiscoverability]
        )
    }

    private func runOperation<T: CloudKitable>(
        _ operation: CKQueryOperation
    ) async throws -> [T] {
        typealias Cont = CheckedContinuation<[T], Error>
        try await withCheckedThrowingContinuation { (continuation: Cont) in
            var objects: [T] = []

            operation.recordMatchedBlock = { _, result in
                switch result {
                case let .success(record):
                    objects.append(T(record: record)!)
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }

            operation.queryResultBlock = { result, error in
                switch result {
                case let .success(cursor):
                    if let cursor = cursor {
                        // Make a recursive call to get more results.
                        let newOperation = CKQueryOperation(cursor: cursor)
                        Task {
                            let moreObjects: [T] =
                                try await runOperation(newOperation)
                            objects.append(contentsOf: moreObjects)
                            continuation.resume(returning: objects)
                        }
                    } else {
                        continuation.resume(returning: objects)
                    }
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }

            database.add(operation)
        // } as! [theType.self]
        }
    }

    func statusText() async throws -> String {
        switch try await container.accountStatus() {
        case .available:
            return "available"
        case .couldNotDetermine:
            return "could not determine"
        case .noAccount:
            return "no account"
        case .restricted:
            return "restricted"
        case .temporarilyUnavailable:
            return "temporarily unavailable"
        default:
            return "unknown"
        }
    }

    // See https://nemecek.be/blog/31/how-to-setup-cloudkit-subscription-to-get-notified-for-changes.
    // This requires adding the "Background Modes" capability
    // and checking "Remote notifications".
    // Supposedly subscriptions do not work in the Simulator.
    func subscribe(recordType: CKRecord.RecordType) async throws {
        let subscription = CKQuerySubscription(
            recordType: recordType,
            predicate: NSPredicate(value: true), // all records
            options: [
                .firesOnRecordCreation,
                .firesOnRecordDeletion,
                .firesOnRecordUpdate
            ]
        )

        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        info.alertBody = "" // if this isn't set, pushes aren't always sent
        subscription.notificationInfo = info
        try await database.save(subscription)
    }

    func userIdentity() async throws -> String {
        let id = try await container.userRecordID()
        let identity = try await container.userIdentity(forUserRecordID: id)
        guard let components = identity?.nameComponents else {
            Log.error("failed to get CloudKit user identity")
            return ""
        }
        let formatter = PersonNameComponentsFormatter()
        formatter.style = .long
        return formatter.string(from: components)
    }

    // MARK: - CRUD Methods

    // "C" in CRUD.
    func create<T: CloudKitable>(item: T) async throws {
        try await database.save(item.record)
    }

    // "R" in CRUD.
    func retrieve<T: CloudKitable>(
        recordType: CKRecord.RecordType,
        predicate: NSPredicate = NSPredicate(value: true), // gets all
        sortDescriptors: [NSSortDescriptor]? = nil,
        resultsLimit: Int = CKQueryOperation.maximumResults
    ) async throws -> [T] {
        let query = CKQuery(recordType: recordType, predicate: predicate)
        query.sortDescriptors = sortDescriptors
        let operation = CKQueryOperation(query: query)
        let objects: [T] = try await runOperation(operation)
        return objects
    }

    // "U" in CRUD.
    func update<T: CloudKitable>(item: T) async throws {
        try await database.save(item.record)
    }

    // "D" in CRUD.
    func delete<T: CloudKitable>(item: T) async throws {
        try await database.deleteRecord(withID: item.record.recordID)
    }
}
