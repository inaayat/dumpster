import Foundation
import GRDB

struct StarFields: Codable {
    var s: String
    var t: String
    var a: String
    var r: String

    static func from(_ json: String?) -> StarFields {
        guard let json,
              let data = json.data(using: .utf8),
              let fields = try? JSONDecoder().decode(StarFields.self, from: data)
        else { return StarFields(s: "", t: "", a: "", r: "") }
        return fields
    }

    func toJSON() -> String {
        let data = try? JSONEncoder().encode(self)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    var isEmpty: Bool { s.isEmpty && t.isEmpty && a.isEmpty && r.isEmpty }
}

struct Win: Identifiable, Codable, Equatable {
    var id: String
    var text: String
    var itemId: String?
    var artifact: String?
    var kind: String      // "win" or "scenario"
    var star: String?     // JSON-encoded StarFields
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, text, itemId, artifact, kind, star, createdAt
    }

    init(id: String, text: String, itemId: String?, artifact: String?, kind: String, star: String?, createdAt: Date) {
        self.id = id
        self.text = text
        self.itemId = itemId
        self.artifact = artifact
        self.kind = kind
        self.star = star
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        text = try c.decode(String.self, forKey: .text)
        itemId = try c.decodeIfPresent(String.self, forKey: .itemId)
        artifact = try c.decodeIfPresent(String.self, forKey: .artifact)
        kind = (try c.decodeIfPresent(String.self, forKey: .kind)) ?? "win"
        star = try c.decodeIfPresent(String.self, forKey: .star)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
    }
}

extension Win: FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "wins"

    enum Columns: String, ColumnExpression {
        case id, text, itemId, artifact, kind, star, createdAt
    }
}

extension Win {
    static func new(text: String, itemId: String? = nil, artifact: String? = nil, kind: String = "win") -> Win {
        Win(
            id: UUID().uuidString,
            text: text.trimmingCharacters(in: .whitespaces),
            itemId: itemId,
            artifact: artifact?.trimmingCharacters(in: .whitespaces).isEmpty == true ? nil : artifact?.trimmingCharacters(in: .whitespaces),
            kind: kind,
            star: nil,
            createdAt: Date()
        )
    }
}
