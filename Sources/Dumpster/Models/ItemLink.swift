import Foundation
import GRDB

struct ItemLink: Identifiable, Codable, Equatable {
    var id: String
    var fromItemId: String
    var toItemId: String
    var relationship: String
    var createdAt: Date
}

extension ItemLink: FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "item_links"

    enum Columns: String, ColumnExpression {
        case id, fromItemId, toItemId, relationship, createdAt
    }
}

extension ItemLink {
    static func new(fromId: String, toId: String, relationship: String = "related") -> ItemLink {
        ItemLink(id: UUID().uuidString, fromItemId: fromId, toItemId: toId, relationship: relationship, createdAt: Date())
    }
}
