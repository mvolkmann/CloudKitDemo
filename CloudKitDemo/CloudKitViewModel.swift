import CloudKit
import SwiftUI

class CloudKitViewModel: ObservableObject {
    // MARK: - State

    @Published var error: String = ""
    @Published var fruits: [Fruit] = []
    @Published var fullName: String = ""
    @Published var havePermission: Bool = false
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
                let status = try await CloudKit.accountStatus()
                DispatchQueue.main.async { self.status = status }
                if status == .available {
                    let permission = try await CloudKit.requestPermission()
                    if permission == .granted {
                        let fullName = try await CloudKit.userIdentity()
                        DispatchQueue.main.async { self.fullName = fullName }
                    }
                }
            } catch {
                print("CloudKitViewModel: error = \(error)")
            }
        }
    }

    // MARK: - Methods

    func addFruit(name: String) async throws {
        let record = CKRecord(recordType: "Fruits")
        record["name"] = name as CKRecordValue
        let newFruit = Fruit(record: record)

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

    func fetchFruits(recordType: CKRecord.RecordType) async throws {
        /*
        print("CloudKitViewModel.fetchFruits: entered")
        let fruits = try await CloudKit.retrieve(
            recordType: "Fruits",
            sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)]
        ) as [Fruit]
        print("CloudKitViewModel.fetchFruits: fruits = \(fruits)")
        DispatchQueue.main.async { self.fruits = fruits }
        */

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
                    // Update published properties on main thread.
                    DispatchQueue.main.async {
                        self.fruits.append(Fruit(record: record))
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

    func updateFruit(fruit: Fruit) async throws {
        let newName = fruit.name + "!"

        let record = fruit.record
        record["name"] = newName
        try await saveRecord(record)

        // Find the corresponding published fruit object.
        let id = record.recordID
        let pubFruit = fruits.first(where: { f in f.record.recordID == id })
        if pubFruit == nil {
            print("CloudKitViewModel.updateFruit: fruit not found")
            return
        }

        // Update the published fruit object.
        DispatchQueue.main.async {
            pubFruit!.record["name"] = newName
            print("CloudKitViewModel.updateFruit: updated fruit")
            // TODO: This doesn't case the UI to update!
        }
    }
}
