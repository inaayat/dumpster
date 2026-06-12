import Foundation
import GRDB

struct DailyDump: Identifiable, Codable, Equatable {
    var id: String
    var date: String
    var content: String
    var createdAt: Date
    var updatedAt: Date

    static func today() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    static func displayDate(_ dateStr: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: dateStr) else { return dateStr }
        let display = DateFormatter()
        display.dateFormat = "EEEE, MMM d, yyyy"
        return display.string(from: date)
    }

    static func new(date: String? = nil) -> DailyDump {
        let d = date ?? today()
        return DailyDump(id: UUID().uuidString, date: d, content: "", createdAt: Date(), updatedAt: Date())
    }
}

extension DailyDump: FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "daily_dumps"

    enum Columns: String, ColumnExpression {
        case id, date, content, createdAt, updatedAt
    }
}

struct DumpBullet: Identifiable {
    let id = UUID()
    var text: String
    var tags: [String]
    var magicTags: [MagicTag]
    var isRetired: Bool
    var rawLine: String

    static let retiredMarker = " [retired]"

    static func parse(from content: String) -> [DumpBullet] {
        content
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { line in
                var cleaned = line
                if cleaned.hasPrefix("• ") { cleaned = String(cleaned.dropFirst(2)) }
                else if cleaned.hasPrefix("* ") { cleaned = String(cleaned.dropFirst(2)) }
                let retired = cleaned.hasSuffix(retiredMarker)
                if retired { cleaned = String(cleaned.dropLast(retiredMarker.count)) }
                let allTags = extractTags(from: cleaned)
                let magic = allTags.compactMap { MagicTag(rawValue: $0) }
                let topicTags = allTags.filter { MagicTag(rawValue: $0) == nil }
                return DumpBullet(text: cleaned, tags: topicTags, magicTags: magic, isRetired: retired, rawLine: line)
            }
    }

    static func extractTags(from text: String) -> [String] {
        let pattern = #"#([\w\-]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range]).lowercased()
        }
    }
}

enum MagicTag: String {
    case action
    case brainstorm
    case resource
    case win
    case save
    case prio
    case delete
}
