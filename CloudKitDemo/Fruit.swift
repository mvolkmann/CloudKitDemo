import CloudKit

struct Fruit: CloudKitable, Hashable {
    //init?(record: CKRecord) {
    init(record: CKRecord) {
        self.record = record
    }

    let record: CKRecord

    var name: String { record["name"] as? String ?? "" }
}
