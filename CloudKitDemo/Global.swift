import Foundation

let containerId = "iCloud.com.objectcomputing.swiftui-cloudkit-core-data"

func runAfter(seconds: Int, closure: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(
        deadline: .now().advanced(by: .seconds(seconds)),
        execute: closure
    )
}
