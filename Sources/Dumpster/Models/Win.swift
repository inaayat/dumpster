import Foundation
import GRDB

struct Win: Identifiable, Codable, Equatable {
    var id: String
    var text: String
    var itemId: String?
    var artifact: String?
    var createdAt: Date
}

extension Win: FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "wins"

    enum Columns: String, ColumnExpression {
        case id, text, itemId, artifact, createdAt
    }
}

extension Win {
    static func new(text: String, itemId: String? = nil, artifact: String? = nil) -> Win {
        Win(
            id: UUID().uuidString,
            text: text.trimmingCharacters(in: .whitespaces),
            itemId: itemId,
            artifact: artifact?.trimmingCharacters(in: .whitespaces).isEmpty == true ? nil : artifact?.trimmingCharacters(in: .whitespaces),
            createdAt: Date()
        )
    }
}
