import Foundation

struct AIService {
    private static let client = AIClient.shared

    // MARK: - Categorize

    struct CategorizeResult {
        let category: Category
        let tags: [String]
        let cleanedText: String
    }

    static func categorize(text: String) async throws -> CategorizeResult {
        if text.trimmingCharacters(in: .whitespaces).range(of: #"^https?://\S+$"#, options: .regularExpression) != nil {
            return CategorizeResult(category: .resource, tags: [], cleanedText: text.trimmingCharacters(in: .whitespaces))
        }

        let system = """
            You categorize user thoughts, extract topic tags, and clean up the language.
            Categories:
            - brainstorm: ideas, musings, observations, questions
            - action: concrete tasks, things to do, deliverables
            - resource: URLs, links, references, articles

            Tags: extract 1-3 short topic tags. Use project/system names when applicable. Lowercase, 1-2 words.

            cleaned_text: Rewrite to be clearer and more concise. Fix typos, grammar. Keep it natural.

            Respond with ONLY valid JSON:
            {"category": "...", "tags": ["tag1"], "cleaned_text": "..."}
            """

        let response = try await client.send(system: system, userMessage: text, maxTokens: 400)
        let parsed = try parseJSON(response)

        let categoryStr = parsed["category"] as? String ?? "brainstorm"
        let category = Category(rawValue: categoryStr) ?? .brainstorm
        let tags = (parsed["tags"] as? [String] ?? []).prefix(5).map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        let cleanedText = (parsed["cleaned_text"] as? String)?.trimmingCharacters(in: .whitespaces) ?? text

        return CategorizeResult(category: category, tags: Array(tags), cleanedText: cleanedText)
    }

    // MARK: - Analyze Dump

    struct AnalyzeResult {
        var proposedItems: [ProposedItem]
        var suggestedTags: [SuggestedTag]
    }

    struct ProposedItem: Identifiable {
        let id = UUID()
        var text: String
        var category: Category
        var isWin: Bool
        let tags: [String]
        let originalText: String
    }

    struct SuggestedTag {
        let bulletText: String
        let tag: String
    }

    static func analyzeDump(content: String) async throws -> AnalyzeResult {
        let system = """
            You analyze a daily brain-dump (bullet-pointed thoughts). You do two things:

            1. EXTRACT ITEMS: For each meaningful bullet, propose it as an item:
            - text: a CLEAR, professional rewrite — full sentence, no filler words, no shorthand
            - category: "action" (concrete task), "brainstorm" (idea/observation), "win" (achievement), or "resource" (URL/reference)
            - tags: 1-3 short topic tags (lowercase, use exact project/system names)
            - original_text: the exact source bullet text

            2. SUGGEST TAGS: For bullets without a #tag, suggest what tag should be appended.

            Respond with ONLY valid JSON:
            {
              "items": [{"text": "...", "category": "action", "tags": ["tag1"], "original_text": "..."}],
              "suggested_tags": [{"bullet": "exact bullet text", "tag": "suggested-tag"}]
            }

            Rules:
            - Don't create items from trivial/filler bullets
            - Preserve existing #hashtags as tags
            - Return empty arrays if nothing applies
            """

        let response = try await client.send(system: system, userMessage: content, maxTokens: 3000)
        let cleaned = cleanJSON(response)
        guard let data = cleaned.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return AnalyzeResult(proposedItems: [], suggestedTags: [])
        }

        let items: [ProposedItem] = ((obj["items"] as? [[String: Any]]) ?? []).compactMap { item in
            guard let text = item["text"] as? String,
                  let categoryStr = item["category"] as? String else { return nil }
            let isWin = categoryStr == "win"
            let category: Category = switch categoryStr {
            case "action", "win": .action
            case "resource": .resource
            default: .brainstorm
            }
            let tags = (item["tags"] as? [String])?.map { $0.lowercased() } ?? []
            let originalText = item["original_text"] as? String ?? text
            return ProposedItem(text: text, category: category, isWin: isWin, tags: tags, originalText: originalText)
        }

        let suggestedTags: [SuggestedTag] = ((obj["suggested_tags"] as? [[String: Any]]) ?? []).compactMap { st in
            guard let bullet = st["bullet"] as? String,
                  let tag = st["tag"] as? String else { return nil }
            return SuggestedTag(bulletText: bullet, tag: tag.lowercased())
        }

        return AnalyzeResult(proposedItems: items, suggestedTags: suggestedTags)
    }

    // MARK: - Master Doc Insert

    static func insertBulletsIntoDoc(existingContent: String, bullets: [String]) async throws -> String {
        let system = """
            You integrate new notes into an existing document. For each new bullet:
            1. Find the most relevant existing heading/section to place it under
            2. Expand the bullet into a full insight — complete sentences, connect to other content
            3. If no existing heading fits, create a new section heading (## Title)
            4. Prefix each newly inserted line with "→ " so the user can see what was added

            Rules:
            - Preserve ALL existing content exactly as-is
            - Only ADD new content, never modify or remove existing lines
            - Place new content logically within the section
            - Use professional, clear language
            - Return ONLY the full updated document
            """
        var userMessage = "EXISTING DOCUMENT:\n"
        userMessage += existingContent.isEmpty ? "(empty document)" : existingContent
        userMessage += "\n\nNEW BULLETS TO INSERT:\n"
        userMessage += bullets.map { "• \($0)" }.joined(separator: "\n")
        return try await client.send(system: system, userMessage: userMessage, maxTokens: 4000)
    }

    // MARK: - Master Doc Synthesis

    static func synthesizeMasterDoc(existingContent: String, bullets: String) async throws -> String {
        let system = """
            You organize notes into a clean, well-structured document. Output well-formatted Markdown.
            Use headings (##, ###) to group by theme. Use bullet points for items. Use clear, professional language.
            Preserve ALL information — do not drop anything. Remove duplicates. Merge related points.
            If there is existing content, integrate new bullets into the existing structure.
            Return ONLY the final document content.
            """
        var userMessage = ""
        if !existingContent.isEmpty { userMessage += "EXISTING DOCUMENT:\n\(existingContent)\n\n" }
        userMessage += "BULLETS TO INTEGRATE:\n\(bullets)"
        return try await client.send(system: system, userMessage: userMessage, maxTokens: 4000)
    }

    // MARK: - Notes Analysis

    struct NoteSuggestionsResult {
        let actions: [String]
        let brainstorms: [String]
    }

    static func analyzeNotes(itemText: String, notes: String) async throws -> NoteSuggestionsResult {
        let system = """
            You analyze notes attached to a task and extract:
            1. Follow-up action items (concrete, specific tasks)
            2. Brainstorm ideas (observations, questions, directions to explore)
            Respond ONLY with valid JSON:
            {"actions": ["...", "..."], "brainstorms": ["...", "..."]}
            Keep suggestions concise (1 sentence each). Return empty arrays if nothing applies.
            """
        let userMessage = "Task: \(itemText)\n\nNotes:\n\(notes)"
        let response = try await client.send(system: system, userMessage: userMessage, maxTokens: 600)
        let parsed = try parseJSON(response)
        return NoteSuggestionsResult(
            actions: (parsed["actions"] as? [String] ?? []).map { $0.trimmingCharacters(in: .whitespaces) },
            brainstorms: (parsed["brainstorms"] as? [String] ?? []).map { $0.trimmingCharacters(in: .whitespaces) }
        )
    }

    // MARK: - Redundancy Detection

    struct RedundancyGroup: Identifiable {
        let id = UUID()
        let itemIds: [String]
        let reason: String
        let mergedText: String
    }

    static func findRedundancies(items: [(id: String, text: String, category: String)]) async throws -> [RedundancyGroup] {
        guard !items.isEmpty else { return [] }
        let itemsJSON = items.map { "{\"id\":\"\($0.id)\",\"text\":\"\($0.text.replacingOccurrences(of: "\"", with: "'"))\",\"category\":\"\($0.category)\"}" }.joined(separator: ",")
        let system = """
            Find groups of redundant or near-duplicate items.
            Two items are redundant if they say essentially the same thing or one is a subset of the other.

            For each group:
            - ids: the item IDs that are redundant (minimum 2)
            - reason: one short sentence explaining why they're duplicates
            - merged_text: a single clean sentence capturing all meaning

            Respond with ONLY valid JSON:
            [{"ids": ["id1", "id2"], "reason": "...", "merged_text": "..."}]
            If no redundancies exist, return: []
            """

        let response = try await client.send(system: system, userMessage: "[\(itemsJSON)]", maxTokens: 2000)
        let cleaned = cleanJSON(response)
        guard let data = cleaned.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }

        return arr.compactMap { obj in
            guard let ids = obj["ids"] as? [String], ids.count >= 2,
                  let reason = obj["reason"] as? String,
                  let mergedText = obj["merged_text"] as? String else { return nil }
            return RedundancyGroup(itemIds: ids, reason: reason, mergedText: mergedText)
        }
    }

    // MARK: - Helpers

    private static func parseJSON(_ raw: String) throws -> [String: Any] {
        let cleaned = cleanJSON(raw)
        guard let data = cleaned.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIError.parseError
        }
        return obj
    }

    private static func cleanJSON(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            let lines = s.components(separatedBy: "\n")
            s = lines.dropFirst().joined(separator: "\n")
            if let end = s.range(of: "```") { s = String(s[s.startIndex..<end.lowerBound]) }
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
