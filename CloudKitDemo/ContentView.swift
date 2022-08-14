import SwiftUI

struct ContentView: View {
    @StateObject private var vm = CloudKitViewModel()

    @State private var message = ""
    @State private var fruitName = ""

    var body: some View {
        VStack {
            Text("iCloud Status: \(vm.statusText)")
            Text("iCloud User Name: \(vm.userIdentity)")

            if !message.isEmpty {
                Text(message).foregroundColor(.red)
            }

            HStack {
                TextField("Fruit Name", text: $fruitName)
                    .padding(5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5).stroke(.gray)
                    )
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
    }

    private func addFruit() {
        Task {
            do {
                try await vm.addFruit(name: fruitName)
                fruitName = ""
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
