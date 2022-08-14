import CloudKit
import SwiftUI

class CloudKitViewModel: ObservableObject {
    // MARK: - State

    @Published var fruits: [Fruit] = []
    @Published var userIdentity: String = ""
    @Published var havePermission: Bool = false
    @Published var statusText: String = ""

    // MARK: - Initializer

    init() {
        Task {
            do {
                let statusText = try await CloudKit.statusText()
                DispatchQueue.main.async { self.statusText = statusText }

                if statusText == "available" {
                    let permission = try await CloudKit.requestPermission()
                    if permission == .granted {
                        let userIdentity = try await CloudKit.userIdentity()
                        DispatchQueue.main.async { self.userIdentity = userIdentity }
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

        try await CloudKit.create(item: newFruit)
    }

    private func deleteFruit(offset: IndexSet.Element) async throws {
        let fruit = fruits[offset]
        try await CloudKit.delete(item: fruit)
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
            recordType: "Fruits",
            sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)]
        ) as [Fruit]
        DispatchQueue.main.async { self.fruits = fruits }
    }

    func updateFruit(fruit: Fruit) async throws {
        try await CloudKit.update(item: fruit)

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
