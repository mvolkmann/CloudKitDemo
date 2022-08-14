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
    var container: CKContainer!
    var database: CKDatabase!

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

    func requestPermission() async throws -> CKContainer.ApplicationPermissionStatus {
        try await withCheckedThrowingContinuation { continuation in
            container.requestApplicationPermission(
                [.userDiscoverability]
            ) { status, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }

    private func save(record: CKRecord) async throws {
        // TODO: Why is "return" necessary on the next line?
        return try await withCheckedThrowingContinuation { continuation in
            database.save(record) { _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func status() async throws -> CKAccountStatus {
        try await withCheckedThrowingContinuation { continuation in
            container.accountStatus { status, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }

    func statusText() async throws -> String {
        switch try await status() {
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
        return try await withCheckedThrowingContinuation { continuation in
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

            database.save(subscription) { (subscription, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let _ = subscription {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: "no subscription created")
                }
            }
        }
    }

    func userIdentity() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let id = try await userRecordID()

                    container.discoverUserIdentity(withUserRecordID: id) { identity, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let components = identity?.nameComponents {
                            let formatter = PersonNameComponentsFormatter()
                            formatter.style = .long
                            let identity = formatter.string(from: components)
                            continuation.resume(returning: identity)
                        } else {
                            continuation.resume(
                                throwing: "failed to get CloudKit user identity"
                            )
                        }
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func userRecordID() async throws -> CKRecord.ID {
        try await withCheckedThrowingContinuation { continuation in
            container.fetchUserRecordID { id, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let id = id {
                    continuation.resume(returning: id)
                } else {
                    continuation.resume(
                        throwing: "failed to get CloudKit user record id"
                    )
                }
            }
        }
    }

    // "C" in CRUD.
    func create<T:CloudKitable>(item: T) async throws {
        try await save(record: item.record)
    }

    // "R" in CRUD.
    func retrieve<T:CloudKitable>(
        recordType: CKRecord.RecordType,
        predicate: NSPredicate = NSPredicate(value: true), // gets all
        sortDescriptors: [NSSortDescriptor]? = nil,
        resultsLimit: Int? = nil
    ) async throws -> [T] {
        try await withCheckedThrowingContinuation { continuation in
            var items: [T] = []

            let operation = createOperation(
                recordType: recordType,
                predicate: predicate,
                sortDescriptors: sortDescriptors,
                resultsLimit: resultsLimit
            )

            // This callback is called for each record fetched.
            operation.recordMatchedBlock = { _, result in
                switch result {
                case .success(let record):
                    guard let item = T(record: record) else { return }
                    items.append(item)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            // This callback is called after the last record is fetched.
            operation.queryResultBlock = { result in
                switch result {
                case .success(let cursor):
                    // Use cursor to fetch additional records.
                    // If will be nil if there are no more records to fetch.
                    // TODO: How to you use the cursor to get more records?
                    if cursor != nil {
                        print("CloudKitView.retrieve: cursor =", cursor.debugDescription)
                    }
                    continuation.resume(returning: items)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            // This executes the operation.
            database.add(operation)
        }
    }

    // "U" in CRUD.
    func update<T:CloudKitable>(item: T) async throws {
        try await save(record: item.record)
    }

    // "D" in CRUD.
    func delete<T:CloudKitable>(item: T) async throws {
        // TODO: Why is "return" necessary on the next line?
        return try await withCheckedThrowingContinuation { continuation in
            database.delete(
                withRecordID: item.record.recordID
            ) { _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
