import CloudKit
import SwiftUI

class CloudKitViewModel: ObservableObject {
    // MARK: - State

    @Published var fruits: [Fruit] = []
    @Published var userIdentity: String = ""
    @Published var havePermission: Bool = false
    @Published var statusText: String = ""

    // MARK: - Initializer

    // This class is a singleton.
    private init() {
        cloudKit = CloudKit(containerId: containerId)
        Task {
            do {
                let statusText = try await cloudKit.statusText()
                DispatchQueue.main.async { self.statusText = statusText }

                if statusText == "available" {
                    let permission = try await cloudKit.requestPermission()
                    if permission == .granted {
                        let userIdentity = try await cloudKit.userIdentity()
                        DispatchQueue.main.async {
                            self.userIdentity = userIdentity
                        }

                        try await cloudKit.requestNotifications()
                        try await cloudKit.subscribeToNotifications()

                        // try await cloudKit.subscribe(recordType: "Fruits")
                        try await retrieveFruits()
                    }
                }
            } catch {
                Log.error(error)
            }
        }
    }

    // MARK: - Properties

    static var shared = CloudKitViewModel()

    private var cloudKit: CloudKit!

    // MARK: - Methods

    func addFruit(name: String) async throws {
        let record = CKRecord(recordType: "Fruits")
        // record["name"] = name as CKRecordValue
        record.setValue(name as CKRecordValue, forKey: "name")
        // Also see record.setValuesForKeys([
        //    "name": name, "anotherKey": anotherValue, ...
        // ])
        let newFruit = Fruit(record: record)

        DispatchQueue.main.async {
            self.fruits.append(newFruit)
            self.fruits.sort { $0.name < $1.name }
        }

        try await cloudKit.create(item: newFruit)
    }

    private func deleteFruit(offset: IndexSet.Element) async throws {
        let fruit = fruits[offset]
        try await cloudKit.delete(item: fruit)
        DispatchQueue.main.async {
            self.fruits.remove(at: offset)
        }
    }

    func deleteFruits(offsets: IndexSet) async throws {
        for offset in offsets {
            try await deleteFruit(offset: offset)
        }
    }

    func retrieveFruits() async throws {
        let fruits = try await cloudKit.retrieve(
            recordType: "Fruits",
            sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)],
            resultsLimit: 2 // TODO: ONLY HERE TO TEST USED OF CURSORS!
        ) as [Fruit]
        DispatchQueue.main.async { self.fruits = fruits }
    }

    func updateFruit(fruit: Fruit) async throws {
        try await cloudKit.update(item: fruit)

        // Update the corresponding published fruit object.
        let id = fruit.record.recordID
        let index = fruits.firstIndex { fruit in fruit.record.recordID == id }
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
