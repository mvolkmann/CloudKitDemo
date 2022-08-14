import SwiftUI

struct MyTextField: View {
    var label: String = ""
    @Binding var text: String

    var body: some View {
        TextField(label, text: $text)
            .padding(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5).stroke(.gray)
            )
    }
}
