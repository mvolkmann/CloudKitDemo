import CloudKit

struct Fruit: CloudKitable, Hashable {
    //init?(record: CKRecord) {
    init(record: CKRecord) {
        self.record = record
    }

    var record: CKRecord

    var name: String { record["name"] as? String ?? "" }
}
