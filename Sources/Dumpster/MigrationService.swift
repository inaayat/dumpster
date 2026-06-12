import Foundation
import GRDB

struct MigrationService {
    static var oldDbExists: Bool {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".my-mind/mind.db").path
        return FileManager.default.fileExists(atPath: path)
    }

    static func importFromMyMind() throws {
        let oldPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".my-mind/mind.db").path
        guard FileManager.default.fileExists(atPath: oldPath) else { return }

        let oldDb = try DatabasePool(path: oldPath)
        let newDb = DatabaseManager.shared.dbPool

        try oldDb.read { oldConn in
            // Migrate items + their JSON tags
            let items = try Row.fetchAll(oldConn, sql: "SELECT * FROM items")
            for row in items {
                let id: String = row["id"]
                let text: String = row["text"]
                let category: String = row["category"] ?? "brainstorm"
                let priority: String = row["priority"] ?? "medium"
                let done: Bool = row["done"]
                let doneAt: Date? = row["doneAt"]
                let dueDate: Date? = row["dueDate"]
                let url: String? = row["url"]
                let urlTitle: String? = row["urlTitle"]
                let notes: String? = row["notes"]
                let createdAt: Date = row["createdAt"]
                let tagsJSON: String? = row["tags"]
                let clusterId: String? = row["clusterId"]

                try newDb.write { db in
                    try db.execute(
                        sql: """
                            INSERT OR IGNORE INTO items (id, text, category, priority, done, doneAt, dueDate, url, urlTitle, notes, createdAt)
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                            """,
                        arguments: [id, text, category == "revisit" ? "brainstorm" : category, priority, done, doneAt, dueDate, url, urlTitle, notes, createdAt]
                    )
                }

                // Parse JSON tags and create tag records + associations
                if let tagsJSON, let data = tagsJSON.data(using: .utf8),
                   let tags = try? JSONDecoder().decode([String].self, from: data) {
                    for tagName in tags {
                        let tag = try Queries.getOrCreateTag(name: tagName)
                        try? Queries.tagItem(itemId: id, tagId: tag.id)
                    }
                }

                // Convert cluster membership to a tag
                if let clusterId {
                    if let clusterRow = try? Row.fetchOne(oldConn, sql: "SELECT title FROM clusters WHERE id = ?", arguments: [clusterId]) {
                        let clusterTitle: String = clusterRow["title"]
                        let tagName = clusterTitle.lowercased().replacingOccurrences(of: " ", with: "-")
                        let tag = try Queries.getOrCreateTag(name: tagName)
                        try? Queries.tagItem(itemId: id, tagId: tag.id)
                    }
                }
            }

            // Migrate daily dumps
            let dumps = try Row.fetchAll(oldConn, sql: "SELECT * FROM daily_dumps")
            for row in dumps {
                try newDb.write { db in
                    try db.execute(
                        sql: "INSERT OR IGNORE INTO daily_dumps (id, date, content, createdAt, updatedAt) VALUES (?, ?, ?, ?, ?)",
                        arguments: [row["id"] as String, row["date"] as String, row["content"] as String, row["createdAt"] as Date, row["updatedAt"] as Date]
                    )
                }
            }

            // Migrate wins
            let wins = try Row.fetchAll(oldConn, sql: "SELECT * FROM wins")
            for row in wins {
                let valueAdd: String? = row["valueAdd"]
                let text = valueAdd ?? "Win logged"
                try newDb.write { db in
                    try db.execute(
                        sql: "INSERT OR IGNORE INTO wins (id, text, itemId, artifact, createdAt) VALUES (?, ?, ?, ?, ?)",
                        arguments: [row["id"] as String, text, row["itemId"] as String?, row["artifact"] as String?, row["createdAt"] as Date]
                    )
                }
            }

            // Migrate master docs
            if (try? oldConn.tableExists("master_docs")) == true {
                let docs = try Row.fetchAll(oldConn, sql: "SELECT * FROM master_docs")
                for row in docs {
                    let tagName: String = row["tag"]
                    let tag = try Queries.getOrCreateTag(name: tagName)
                    try? Queries.upsertMasterDoc(tagId: tag.id, content: row["content"], title: row["title"])
                }
            }

            // Migrate links
            if (try? oldConn.tableExists("links")) == true {
                let links = try Row.fetchAll(oldConn, sql: "SELECT * FROM links")
                for row in links {
                    try newDb.write { db in
                        try db.execute(
                            sql: "INSERT OR IGNORE INTO item_links (id, fromItemId, toItemId, relationship, createdAt) VALUES (?, ?, ?, ?, ?)",
                            arguments: [UUID().uuidString, row["fromId"] as String, row["toId"] as String, row["relationship"] as String? ?? "related", row["createdAt"] as Date]
                        )
                    }
                }
            }

            // Migrate tag relationships
            if (try? oldConn.tableExists("tag_relationships")) == true {
                let rels = try Row.fetchAll(oldConn, sql: "SELECT * FROM tag_relationships")
                for row in rels {
                    let parentName: String = row["parentTag"]
                    let childName: String = row["childTag"]
                    let parentTag = try Queries.getOrCreateTag(name: parentName)
                    let childTag = try Queries.getOrCreateTag(name: childName)
                    try? Queries.addSubTag(parentTagId: parentTag.id, childTagId: childTag.id)
                }
            }
        }
    }
}
