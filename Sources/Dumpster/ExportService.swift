import Foundation
import AppKit

struct ExportService {
    static func exportMarkdown() {
        let markdown = generateMarkdown()
        let panel = NSSavePanel()
        let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
            .replacingOccurrences(of: "/", with: "-")
        panel.nameFieldStringValue = "dumpster-export-\(dateStr).md"
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            try? markdown.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    static func generateMarkdown() -> String {
        var md = "# Dumpster Export\n"
        let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none)
        md += "Exported: \(dateStr)\n\n"

        let allItems = (try? Queries.getAllItems()) ?? []
        let openItems = allItems.filter { !$0.done }
        let completedItems = allItems.filter { $0.done }

        // Open Items by priority
        md += "---\n\n## Open Items (\(openItems.count))\n\n"

        let highItems = openItems.filter { $0.priority == .high }
        let standardItems = openItems.filter { $0.priority == .medium || $0.priority == .low }
        let backlogItems = openItems.filter { $0.priority == .backlog }

        if !highItems.isEmpty {
            md += "### High Priority\n\n"
            for item in highItems {
                let due = item.dueDate.map { formatDate($0) } ?? ""
                md += "- [\(item.category.label)] \(escape(item.text))\(due.isEmpty ? "" : " (due: \(due))")\n"
            }
            md += "\n"
        }

        if !standardItems.isEmpty {
            md += "### Standard\n\n"
            for item in standardItems { md += "- [\(item.category.label)] \(escape(item.text))\n" }
            md += "\n"
        }

        if !backlogItems.isEmpty {
            md += "### Backlog\n\n"
            for item in backlogItems { md += "- \(escape(item.text))\n" }
            md += "\n"
        }

        // Wins
        let wins = (try? Queries.getAllWins()) ?? []
        if !wins.isEmpty {
            md += "---\n\n## Wins (\(wins.count))\n\n"
            for win in wins {
                let date = formatDate(win.createdAt)
                md += "- **\(escape(win.text))** (\(date))\n"
            }
            md += "\n"
        }

        // Daily Dumps
        let dumps = (try? Queries.getAllDumps()) ?? []
        if !dumps.isEmpty {
            md += "---\n\n## Daily Dumps (\(dumps.count) days)\n\n"
            for dump in dumps {
                md += "### \(DailyDump.displayDate(dump.date))\n\n"
                let lines = dump.content.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                for line in lines { md += "- \(line.trimmingCharacters(in: .whitespaces))\n" }
                md += "\n"
            }
        }

        // Completed
        if !completedItems.isEmpty {
            md += "---\n\n## Completed (\(completedItems.count))\n\n"
            for item in completedItems { md += "- [x] \(escape(item.text))\n" }
            md += "\n"
        }

        return md
    }

    private static func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "|", with: "\\|").replacingOccurrences(of: "\n", with: " ")
    }
}
