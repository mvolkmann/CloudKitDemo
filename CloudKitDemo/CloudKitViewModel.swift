import CloudKit
import SwiftUI

class CloudKitViewModel: ObservableObject {
    // MARK: - State

    @Published var error: String = ""
    @Published var firstName: String = ""
    @Published var fruits: [Fruit] = []
    @Published var havePermission: Bool = false
    @Published var lastName: String = ""
    @Published var middleName: String = ""
    @Published var isSignedIn: Bool = false
    @Published var status: CKAccountStatus = .couldNotDetermine

    let container: CKContainer

    // MARK: - Initializer

    init() {
        // When this is used, saves don't report an error,
        // but the data doesn't get saved in the container.
        //container = CKContainer.default()

        // When this is used, saves don't report an error,
        // but the data doesn't get saved in the container.
        //container = CKContainer(identifier: "iCloud.r.mark.volkmann.gmail.com.CloudKitDemo")

        // I discovered this container identifier by clicking the
        // "CloudKit Console" button in "Signing & Capabilities".
        // TODO: Why did it use this identifier instead of the one
        // TODO: specified in Signing & Capabilities ... Containers?
        container = CKContainer(
            identifier: "iCloud.com.objectcomputing.swiftui-cloudkit-core-data"
        )

        Task {
            do {
                if try await isAvailable() {
                    print("CloudKitViewModel: it is available!")
                    if try await requestPermission() {
                        print("have permission")
                        getUserName()
                    } else {
                        print("no permission")
                    }
                } else {
                    print("not available")
                }
            } catch {
                print("CloudKitViewModel: X error = \(error)")
            }
        }
    }

    // MARK: - Properties

    var fullName: String {
        var result = firstName
        if !middleName.isEmpty { result += " " + middleName}
        if !lastName.isEmpty { result += " " + lastName}
        return result
    }

    var statusText: String { statusToString(status) }

    // MARK: - Methods

    func fetchRecords(recordType: String) {
        var fruits: [Fruit] = []

        let predicate = NSPredicate(value: true) // getting all records
        let query = CKQuery(recordType: recordType, predicate: predicate)
        let queryOperation = CKQueryOperation(query: query)

        // This is called once for each record.
        queryOperation.recordMatchedBlock = { recordId, result in
            switch result {
            case .success(let record):
                guard let name = record["name"] as? String else { return }
                fruits.append(Fruit(id: recordId, name: name))
            case .failure(let error):
                print("CloudKitViewModel.fetchRecords: error = \(error)")
            }
        }

        // This is called after the last record has been fetched.
        queryOperation.queryResultBlock = { [weak self] result in
            print("fetchRecords: result = \(result)")
            // Update published properties on main thread.
            DispatchQueue.main.async {
                self?.fruits = fruits
            }
        }

        container.publicCloudDatabase.add(queryOperation)
    }

    private func getUserName() {
        container.fetchUserRecordID { id, error in
            guard let id = id else { return }

            self.container.discoverUserIdentity(withUserRecordID: id) { [weak self] identity, error in
                if let error = error {
                    print("error = \(error.localizedDescription)")
                    return
                }

                guard let components = identity?.nameComponents else { return }
                //print("components = \(components)")

                // Update published properties on main thread.
                DispatchQueue.main.async {
                    self?.firstName = components.givenName ?? ""
                    self?.middleName = components.middleName ?? ""
                    self?.lastName = components.familyName ?? ""
                }
            }
        }
    }

    private func isAvailable() async throws -> Bool {
        // The user must be signed into their iCloud account.
        return try await withCheckedThrowingContinuation { continuation in
            container.accountStatus { status, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status == .available)
                }
            }
        }
    }

    private func requestPermission() async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            container.requestApplicationPermission(
                [.userDiscoverability]
            ) { status, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: status == .granted)
            }
        }
    }

    func saveFruit(name: String) async throws {
        let record = CKRecord(recordType: "Fruits")
        record["name"] = name as CKRecordValue
        try await saveRecord(record)
    }

    private func saveRecord(_ record: CKRecord) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            container.publicCloudDatabase.save(record) { record, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                print("saved record = \(record.debugDescription)")
                continuation.resume()
            }
        }
    }

    private func statusToString(_ status: CKAccountStatus) -> String {
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
}
