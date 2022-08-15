import SwiftUI

struct ContentView: View {
    @StateObject private var vm = CloudKitViewModel()

    @State private var message = ""
    @State private var fruitName = ""
    @State private var updating = false

    var body: some View {
        VStack {
            Text("iCloud Status: \(vm.statusText)")
            Text("iCloud User Name: \(vm.userIdentity)")

            if !message.isEmpty {
                Text(message).foregroundColor(.red)
            }

            HStack {
                MyTextField(label: "Fruit Name", text: $fruitName)
                Button("Add Fruit", action: addFruit)
                    .disabled(fruitName.isEmpty)
            }
            .padding()

            if vm.fruits.isEmpty {
                ProgressView()
            } else {
                List {
                    ForEach(vm.fruits, id: \.record) { fruit in
                        Text(fruit.name)
                            .onTapGesture {
                                // This ignores multiple taps.
                                if updating { return }

                                // TODO: Open a sheet that displays data in the
                                // TODO: tapped fruit and allows it to be edited.
                                let record = fruit.record
                                //let name = record["name"] as? String ?? ""
                                let name = record.value(forKey: "name") as? String ?? ""
                                //fruit.record["name"] = name + "!"
                                record.setValue(name + "!", forKey: "name")
                                updateFruit(fruit: fruit)
                            }
                    }
                    .onDelete(perform: deleteFruit)
                }
                //.refreshable(action: refresh)
                .refreshable { refresh() }
            }

            Spacer()
        }
    }

    private func addFruit() {
        Task {
            do {
                try await vm.addFruit(name: fruitName)
                fruitName = ""
                message = ""
            } catch {
                message = "error adding fruit: \(error.localizedDescription)"
            }
        }
    }

    private func deleteFruit(at offsets: IndexSet) {
        Task {
            do {
                try await vm.deleteFruits(offsets: offsets)
                message = ""
            } catch {
                message = "error deleting fruit: \(error.localizedDescription)"
            }
        }
    }

    private func refresh() {
        Task {
            do {
                try await vm.retrieveFruits()
            } catch {
                message = "error refreshing fruits: \(error.localizedDescription)"
            }
        }
    }

    private func updateFruit(fruit: Fruit) {
        updating = true
        defer { updating = false }
        Task {
            do {
                try await vm.updateFruit(fruit: fruit)
                message = ""
            } catch {
                message = "error updating fruit: \(error.localizedDescription)"
            }
        }
    }
}
