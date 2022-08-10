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
                    if try await requestPermission() {
                        getUserName()
                    } else {
                        print("No permission to access CloudKit.")
                    }
                } else {
                    print("CloudKit is not available.")
                }
            } catch {
                print("CloudKitViewModel: error = \(error)")
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

    func addFruit(name: String) async throws {
        let record = CKRecord(recordType: "Fruits")
        record["name"] = name as CKRecordValue
        let newFruit = Fruit(record: record, name: name)

        // Update published properties on main thread.
        //DispatchQueue.main.async {
            self.fruits.append(newFruit)
            self.fruits.sort { $0.name < $1.name }
        //}

        try await saveRecord(record)
    }

    func deleteFruit(offset: IndexSet.Element) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            // Update published properties on main thread.
            //DispatchQueue.main.async {
                let fruit = self.fruits.remove(at: offset)
                Task {
                    try await self.deleteRecord(fruit.record)
                    continuation.resume()
                }
            //}
        }
    }

    func deleteFruits(offsets: IndexSet) async throws {
        for offset in offsets {
            try await deleteFruit(offset: offset)
        }
    }

    func deleteRecord(_ record: CKRecord) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            container.publicCloudDatabase.delete(
                withRecordID: record.recordID
            ) { id, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume()
            }
        }
    }

    func fetchFruits(recordType: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in

            let predicate = NSPredicate(value: true) // getting all records

            // This predicate gets only records where
            // the value of the name field begins with "B".
            // From https://developer.apple.com/documentation/cloudkit/ckquery,
            // "For fields that contain string values, you can match the
            // beginning portion of the string using the BEGINSWITH operator.
            // You can’t use other string comparison operators,
            // such as CONTAINS or ENDSWITH.
            //let predicate = NSPredicate(format: "K beginswith %@", "name", "B")
            //let predicate = NSPredicate(format: "name beginswith %@", "B")

            let query = CKQuery(recordType: recordType, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

            let queryOperation = CKQueryOperation(query: query)

            // The maximum number of records returned is 100.
            //queryOperation.resultsLimit = 3 // to get less than the maximum

            // This is called once for each record.
            queryOperation.recordMatchedBlock = { recordId, result in
                switch result {
                case .success(let record):
                    guard let name = record["name"] as? String else { return }

                    // Update published properties on main thread.
                    DispatchQueue.main.async {
                        self.fruits.append(Fruit(record: record, name: name))
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            // This is called after the last record has been fetched.
            //queryOperation.queryResultBlock = { [weak self] result in
            queryOperation.queryResultBlock = { result in
                switch result {
                case .success(let cursor):
                    // Use cursor to fetch additional records.
                    // If will be nil if there are no more records to fetch.
                    // TODO: How to you use the cursor to get more records?
                    print("CloudKitViewModel.fetchRecords: cursor = \(cursor.debugDescription)")
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            container.publicCloudDatabase.add(queryOperation)
        }
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
                self.status = status
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

    private func saveRecord(_ record: CKRecord) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            container.publicCloudDatabase.save(record) { record, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
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

    func updateFruit(fruit: Fruit) async throws {
        let newName = fruit.name + "!"

        let record = fruit.record
        record["name"] = newName
        try await saveRecord(record)

        // Find the corresponding published fruit object.
        let id = record.recordID
        var pubFruit = fruits.first(where: { f in f.record.recordID == id })
        if pubFruit == nil {
            print("CloudKitViewModel.updateFruit: fruit not found")
            return
        }

        // Update the published fruit object.
        DispatchQueue.main.async {
            pubFruit!.name = newName
            print("CloudKitViewModel.updateFruit: updated fruit")
            // TODO: This doesn't case the UI to update!
        }
    }
}
