// This is a heavily modified version of CloudKitUtility.swift
// from Nick Sarno of Swiftful Thinking at
// https://github.com/SwiftfulThinking/SwiftUI-Advanced-Learning/blob/main/
// SwiftfulThinkingAdvancedLearning/CloudKitBootcamps/CloudKitUtility.swift

import CloudKit
import UIKit

protocol CloudKitable {
    init?(record: CKRecord)
    var record: CKRecord { get }
}

// This is a case-less enum.
enum CloudKit {

    static func accountStatus() async throws -> CKAccountStatus {
        try await withCheckedThrowingContinuation { continuation in
            CKContainer.default().accountStatus { status, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    print("CloudKit.accoutStatus: status = \(status)")
                    continuation.resume(returning: status)
                }
            }
        }
    }

    static func requestPermission()
    async throws -> CKContainer.ApplicationPermissionStatus {
        try await withCheckedThrowingContinuation { continuation in
            CKContainer.default().requestApplicationPermission(
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

    static func statusText(_ status: CKAccountStatus) -> String {
        switch status {
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

    static func userIdentity() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let id = try await userRecordID()
                    let identity = try await userIdentity(id: id)
                    continuation.resume(returning: identity)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func userIdentity(id: CKRecord.ID) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let container = CKContainer.default()
            container.discoverUserIdentity(withUserRecordID: id) { identity, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let components = identity?.nameComponents {
                    let formatter = PersonNameComponentsFormatter()
                    formatter.style = .long
                    continuation.resume(
                        returning: formatter.string(from: components)
                    )
                } else {
                    continuation.resume(
                        throwing: "failed to get CloudKit user identity"
                    )
                }
            }
        }
    }

    static private func userRecordID() async throws -> CKRecord.ID {
        try await withCheckedThrowingContinuation { continuation in
            let container = CKContainer.default()
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

    static private func createOperation(
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

    // TODO: Add option to add in privateCloudDatabase.
    static private func add(
        usePublic: Bool = false,
        operation: CKDatabaseOperation
    ) {
        getDb(usePublic).add(operation)
    }

    private static func getDb(_ usePublic: Bool = false) -> CKDatabase {
        let container = CKContainer.default()
        return usePublic ?
          container.publicCloudDatabase :
          container.privateCloudDatabase
    }

    // "C" in CRUD.
    static func create<T:CloudKitable>(item: T) async throws {
        try await save(record: item.record)
    }

    // "R" in CRUD.
    static func retrieve<T:CloudKitable>(
        recordType: CKRecord.RecordType,
        predicate: NSPredicate = NSPredicate(value: true), // gets all
        sortDescriptors: [NSSortDescriptor]? = nil,
        resultsLimit: Int? = nil
    ) async throws -> [T] {
        try await withCheckedThrowingContinuation { continuation in
            let operation = createOperation(
                recordType: recordType,
                predicate: predicate,
                sortDescriptors: sortDescriptors,
                resultsLimit: resultsLimit
            )

            var items: [T] = []

            // This callback is called for each record fetched.
            operation.recordMatchedBlock = { (recordID, result) in
                print("CloudKit.retrieve: recordMatchedBlock called")
                switch result {
                case .success(let record):
                    print("record = \(record)")
                    guard let item = T(record: record) else { return }
                    items.append(item)
                case .failure:
                    break
                }
            }

            // This callback is called after the last record is fetched.
            operation.queryResultBlock = { _ in
                print("CloudKit.retrieve: queryResultBlock called")
                continuation.resume(returning: items)
            }

            // This executes the operation.
            add(operation: operation)
            print("CloudKit.retrieve: executed operation")
        }
    }

    // "U" in CRUD.
    static func update<T:CloudKitable>(item: T) async throws {
        try await create(item: item)
    }

    // "D" in CRUD.
    static func delete<T:CloudKitable>(
        usePublic: Bool = false,
        item: T
    ) async throws {
        // TODO: Why is "return" necessary on the next line?
        return try await withCheckedThrowingContinuation { continuation in
            getDb(usePublic).delete(
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

    static private func save(
        usePublic: Bool = false,
        record: CKRecord
    ) async throws {
        // TODO: Why is "return" necessary on the next line?
        return try await withCheckedThrowingContinuation { continuation in
            getDb(usePublic).save(record) { _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
