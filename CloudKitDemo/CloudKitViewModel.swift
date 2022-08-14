import CloudKit
import SwiftUI

class CloudKitViewModel: ObservableObject {
    // MARK: - State

    @Published var fruits: [Fruit] = []
    @Published var fullName: String = ""
    @Published var havePermission: Bool = false
    @Published var status: CKAccountStatus = .couldNotDetermine

    // MARK: - Initializer

    init() {
        Task {
            do {
                let status = try await CloudKit.status()
                if status == .available {
                    let permission = try await CloudKit.requestPermission()
                    if permission == .granted {
                        let fullName = try await CloudKit.userIdentity()
                        DispatchQueue.main.async { self.fullName = fullName }
                        try await retrieveFruits()
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

        DispatchQueue.main.async {
            self.fruits.append(newFruit)
            self.fruits.sort { $0.name < $1.name }
        }

        try await CloudKit.create(usePublic: true, item: newFruit)
    }

    func deleteFruit(offset: IndexSet.Element) async throws {
        let fruit = fruits[offset]
        try await CloudKit.delete(usePublic: true, item: fruit)
        DispatchQueue.main.async {
            self.fruits.remove(at: offset)
        }
    }

    func deleteFruits(offsets: IndexSet) async throws {
        for offset in offsets {
            try await deleteFruit(offset: offset)
        }
    }

    private func retrieveFruits() async throws {
        let fruits = try await CloudKit.retrieve(
            usePublic: true,
            recordType: "Fruits",
            sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)]
        ) as [Fruit]
        DispatchQueue.main.async { self.fruits = fruits }
    }

    func updateFruit(fruit: Fruit) async throws {
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
