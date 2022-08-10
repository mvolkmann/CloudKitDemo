import SwiftUI

struct ContentView: View {
    @StateObject private var vm = CloudKitViewModel()

    @State private var message = ""
    @State private var name = ""

    var body: some View {
        VStack {
            Text("iCloud Status: \(vm.statusText)")
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

            Button("Load Fruits", action: loadFruits)

            if !message.isEmpty {
                Text(message).foregroundColor(.red)
            }

            if vm.fruits.isEmpty {
                ProgressView()
            } else {
                List {
                    ForEach(vm.fruits, id: \.record) { fruit in
                        Text(fruit.name)
                            .onTapGesture { updateName(fruit: fruit) }
                    }
                    .onDelete(perform: deleteFruit)
                }
            }

            Spacer()
        }
        .onAppear(perform: loadFruits)
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

    private func loadFruits() {
        Task {
            do {
                try await vm.fetchFruits(recordType: "Fruits")
            } catch {
                message = "error loading fruit: \(error.localizedDescription)"
            }
        }
    }

    private func updateName(fruit: Fruit) {
        Task {
            do {
                try await vm.updateFruit(fruit: fruit)
                print("ContentView.updateName: updated name")
            } catch {
                message = "error updating fruit: \(error.localizedDescription)"
            }
        }
    }
}
