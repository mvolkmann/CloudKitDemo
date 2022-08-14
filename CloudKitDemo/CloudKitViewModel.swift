import CloudKit
import SwiftUI

class CloudKitViewModel: ObservableObject {
    // MARK: - State

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
        self.fruits.append(newFruit)
        self.fruits.sort { $0.name < $1.name }

        try await CloudKit.create(usePublic: true, item: newFruit)
    }

    func deleteFruit(offset: IndexSet.Element) async throws {
        let fruit = self.fruits.remove(at: offset)
        try await CloudKit.delete(usePublic: true, item: fruit)
    }

    func deleteFruits(offsets: IndexSet) async throws {
        for offset in offsets {
            try await deleteFruit(offset: offset)
        }
    }

    func retrieveFruits(recordType: CKRecord.RecordType) async throws {
        let fruits = try await CloudKit.retrieve(
            usePublic: true,
            recordType: "Fruits",
            sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)]
        ) as [Fruit]
        DispatchQueue.main.async { self.fruits = fruits }
    }

    func updateFruit(fruit: Fruit) async throws {
        print("CloudKitViewModel.updateFruit: fruit =", fruit)
        try await CloudKit.update(usePublic: true, item: fruit)

        // Update the corresponding published fruit object.
        let id = fruit.record.recordID
        let index = fruits.firstIndex(where: { f in f.record.recordID == id })
        if let index = index {
            // Update the published fruit object.
            DispatchQueue.main.async { [weak self] in
                self?.fruits[index].record = fruit.record
            }
        } else {
            // This should never happen.
            throw "CloudKitViewModel.updateFruit: fruit not found"
        }
    }
}
