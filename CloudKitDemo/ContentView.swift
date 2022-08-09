import SwiftUI

struct ContentView: View {
    @StateObject private var vm = CloudKitViewModel()

    @State private var name = ""

    var body: some View {
        VStack {
            Text("Signed in? \(vm.isSignedIn.description)")
            Text("Status: \(vm.statusText)")
            Text("Error: \(vm.error)")
            Text("Name: \(vm.fullName)")

            Text("Fruits")
            HStack {
                TextField("Name", text: $name)
                Button("Add Fruit", action: addFruit)
                    .disabled(name.isEmpty)
            }
            .padding()

            Button("Load Fruits", action: loadFruits)

            List {
                ForEach(vm.fruits, id: \.id) { fruit in
                    Text(fruit.name)
                }
                .onDelete(perform: deleteFruit)
            }
        }
        .onAppear(perform: loadFruits)
    }

    private func addFruit() {
        Task {
            do {
                try await vm.saveFruit(name: name)
                print("added fruit \(name)")
                name = ""
            } catch {
                print("error adding fruit: \(error.localizedDescription)")
            }
        }
    }

    private func deleteFruit(at offsets: IndexSet) {
        for offset in offsets {
            print("offset = \(offset)")
        }
    }

    private func loadFruits() {
        vm.fetchRecords(recordType: "Fruits")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
