import SwiftUI

struct ContentView: View {
    @StateObject private var vm = CloudKitViewModel()

    @State private var message = ""
    @State private var name = ""

    var body: some View {
        VStack {
            Text("iCloud Status: \(CloudKit.statusText(vm.status))")
            if !vm.error.isEmpty {
                Text("Error: \(vm.error)").foregroundColor(.red)
            }
            if !vm.fullName.isEmpty {
                Text("iCloud User Name: \(vm.fullName)")
            }

            HStack {
                TextField("Fruit Name", text: $name)
                    .padding(5)
                    .border(.gray)
                    .cornerRadius(5)
                Button("Add Fruit", action: addFruit)
                    .disabled(name.isEmpty)
            }
            .padding()

            if !message.isEmpty {
                Text(message).foregroundColor(.red)
            }

            if vm.fruits.isEmpty {
                ProgressView()
            } else {
                List {
                    ForEach(vm.fruits, id: \.record) { fruit in
                        Text(fruit.name)
                            .onTapGesture {
                                let name = fruit.record["name"] as? String ?? ""
                                fruit.record["name"] = name + "!"
                                updateFruit(fruit: fruit)
                            }
                    }
                    .onDelete(perform: deleteFruit)
                }
            }

            Spacer()
        }
        .task {
            do {
                try await vm.retrieveFruits(recordType: "Fruits")
            } catch {
                message = "error retrieving fruits: \(error.localizedDescription)"
            }
        }
    }

    private func addFruit() {
        Task {
            do {
                try await vm.addFruit(name: name)
                name = ""
            } catch {
                print("error adding fruit: \(error.localizedDescription)")
            }
        }
    }

    private func deleteFruit(at offsets: IndexSet) {
        Task {
            do {
                for offset in offsets {
                    try await vm.deleteFruit(offset: offset)
                }
            } catch {
                message = "error deleting fruit: \(error.localizedDescription)"
            }
        }
    }

    private func updateFruit(fruit: Fruit) {
        Task {
            do {
                try await vm.updateFruit(fruit: fruit)
            } catch {
                message = "error updating fruit: \(error.localizedDescription)"
            }
        }
    }
}
