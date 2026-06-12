import SwiftUI

struct DumpView: View {
    @Bindable var appState: AppState
    @State private var todayDump: DailyDump?
    @State private var pastDumps: [DailyDump] = []
    @State private var content = ""
    @State private var isAnalyzing = false
    @State private var proposedItems: [AIService.ProposedItem] = []
    @State private var suggestedTags: [AIService.SuggestedTag] = []
    @State private var expandedPastDays: Set<String> = []
    @State private var searchTag: String? = nil
    @State private var tagFilter = ""
    @State private var isUpdating = false
    @State private var showMergeConfirm = false
    @State private var mergeSource: String? = nil
    @State private var mergeTarget: String? = nil
    @State private var showTagDropAction = false
    @State private var tagDropSource: String? = nil
    @State private var tagDropTarget: String? = nil
    @State private var attentionItems: [Item] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                attentionBar
                header
                tagBar
                if searchTag != nil {
                    tagSearchSection
                } else {
                    todaySection
                    if !suggestedTags.isEmpty { tagSuggestionsSection }
                    if !proposedItems.isEmpty { reviewSection }
                    if !pastDumps.isEmpty { pastSection }
                }
            }
            .padding(28)
        }
        .background(Theme.canvas)
        .onAppear { reload() }
    }

    // MARK: - Attention Bar

    @ViewBuilder
    private var attentionBar: some View {
        if !attentionItems.isEmpty {
            let overdue = attentionItems.filter(\.isOverdue).count
            let dueToday = attentionItems.filter(\.isDueToday).count
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(attentionItems) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(item.isOverdue ? Color.red : Theme.warnColor)
                                .frame(width: 6, height: 6)
                            Text(item.text)
                                .font(.inter(11))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            if let due = item.dueDate {
                                Text(due.formatted(.dateTime.month(.abbreviated).day()))
                                    .font(.inter(9))
                                    .foregroundStyle(item.isOverdue ? .red : Theme.textMuted)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { appState.openDetail(itemId: item.id) }
                    }
                }
                .padding(.top, 6)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.warnColor)
                    if overdue > 0 {
                        Text("\(overdue) overdue")
                            .font(.inter(11, weight: .semibold))
                            .foregroundStyle(.red)
                    }
                    if dueToday > 0 {
                        Text("\(dueToday) due today")
                            .font(.inter(11, weight: .semibold))
                            .foregroundStyle(Theme.warnColor)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.warnColor.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Daily Dump")
                    .font(.inter(24, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(DailyDump.displayDate(DailyDump.today()))
                    .font(.inter(12))
                    .foregroundStyle(Theme.textMuted)
            }
            Spacer()

            if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    analyze()
                } label: {
                    HStack(spacing: 5) {
                        if isAnalyzing {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text("Analyze with AI")
                    }
                    .font(.inter(12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .controlSize(.small)
                .disabled(isAnalyzing)
            }
        }
    }

    // MARK: - Tag Bar

    private var tagBar: some View {
        let allTags = collectAllTags()
        let filteredTags = tagFilter.isEmpty ? allTags : allTags.filter { $0.localizedCaseInsensitiveContains(tagFilter) }
        return Group {
            if !allTags.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    if allTags.count > 8 {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.textMuted)
                            TextField("Filter tags...", text: $tagFilter)
                                .textFieldStyle(.plain)
                                .font(.inter(11))
                                .frame(maxWidth: 180)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.cardAlt, in: Capsule())
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(filteredTags, id: \.self) { tag in
                                TagPill(tag: tag, isSelected: searchTag == tag) {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        searchTag = (searchTag == tag) ? nil : tag
                                    }
                                }
                                .draggable(tag)
                                .dropDestination(for: String.self) { dropped, _ in
                                    guard let source = dropped.first, source != tag else { return false }
                                    tagDropSource = source
                                    tagDropTarget = tag
                                    showTagDropAction = true
                                    return true
                                } isTargeted: { _ in }
                            }

                            if searchTag != nil {
                                Button {
                                    withAnimation { searchTag = nil }
                                } label: {
                                    HStack(spacing: 3) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 8, weight: .bold))
                                        Text("Clear")
                                            .font(.inter(10))
                                    }
                                    .foregroundStyle(Theme.textMuted)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Theme.cardAlt, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .confirmationDialog("Merge Tags", isPresented: $showMergeConfirm) {
                    Button("Merge") { performMerge() }
                    Button("Cancel", role: .cancel) { mergeSource = nil; mergeTarget = nil }
                } message: {
                    if let src = mergeSource, let tgt = mergeTarget {
                        Text("Replace all #\(src) with #\(tgt)?")
                    }
                }
                .confirmationDialog(
                    tagDropSource.map { "What do you want to do with #\($0)?" } ?? "",
                    isPresented: $showTagDropAction,
                    titleVisibility: .visible
                ) {
                    if let src = tagDropSource, let tgt = tagDropTarget {
                        Button("Merge into #\(tgt)") {
                            mergeSource = src; mergeTarget = tgt
                            showMergeConfirm = true
                            tagDropSource = nil; tagDropTarget = nil
                        }
                        Button("Make #\(src) a sub-tag of #\(tgt)") {
                            makeSubTag(child: src, parent: tgt)
                            tagDropSource = nil; tagDropTarget = nil
                        }
                        Button("Cancel", role: .cancel) {
                            tagDropSource = nil; tagDropTarget = nil
                        }
                    }
                }
            }
        }
    }

    // MARK: - Today Section

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today")
                    .font(.inter(14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(bulletCount) bullets")
                    .font(.inter(10))
                    .foregroundStyle(Theme.textMuted)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $content)
                    .font(.inter(13))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 300)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                    .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.border, lineWidth: 1))
                    .onChange(of: content) { _, newValue in
                        handleContentChange(newValue)
                        saveDraft()
                    }

                if content.isEmpty {
                    Text("• Start typing your thoughts...")
                        .font(.inter(13))
                        .foregroundStyle(Theme.textMuted)
                        .padding(16)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: - Tag Suggestions

    private var tagSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "tag").font(.system(size: 11)).foregroundStyle(Theme.accent)
                Text("Suggested Tags").font(.inter(12, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                Spacer()
                Button("Dismiss") { withAnimation { suggestedTags.removeAll() } }
                    .font(.inter(10)).foregroundStyle(Theme.textMuted)
            }
            ForEach(Array(suggestedTags.enumerated()), id: \.offset) { index, suggestion in
                HStack(spacing: 8) {
                    Text(suggestion.bulletText).font(.inter(11)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                    Spacer()
                    Text("#\(suggestion.tag)").font(.inter(10, weight: .bold)).foregroundStyle(Theme.accent)
                        .padding(.horizontal, 6).padding(.vertical, 2).background(Theme.accent.opacity(0.1), in: Capsule())
                    Button { applyTagSuggestion(index: index, suggestion: suggestion) } label: {
                        Image(systemName: "plus.circle.fill").font(.system(size: 16)).foregroundStyle(Theme.successColor)
                    }.buttonStyle(.plain)
                    Button { _ = withAnimation { suggestedTags.remove(at: index) } } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundStyle(Theme.textMuted)
                    }.buttonStyle(.plain)
                }
                .padding(8)
                .background(Theme.cardAlt, in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    // MARK: - Review Section

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Proposed Items").font(.inter(14, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                Spacer()
                Button("Dismiss All") { withAnimation { proposedItems.removeAll() } }
                    .font(.inter(10)).foregroundStyle(Theme.textMuted)
            }
            ForEach(Array(proposedItems.enumerated()), id: \.element.id) { index, proposed in
                proposedRow(index: index, proposed: proposed)
            }
        }
    }

    @ViewBuilder
    private func proposedRow(index: Int, proposed: AIService.ProposedItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: proposed.category.icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.categoryColor(proposed.category))
                .frame(width: 20)
            Text(proposed.text).font(.inter(12)).foregroundStyle(Theme.textPrimary).lineLimit(2)
            Spacer()
            Button { acceptItem(at: index) } label: {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).foregroundStyle(Theme.successColor)
            }.buttonStyle(.plain)
            Button { _ = withAnimation { proposedItems.remove(at: index) } } label: {
                Image(systemName: "xmark.circle.fill").font(.system(size: 18)).foregroundStyle(Theme.textMuted)
            }.buttonStyle(.plain)
        }
        .padding(10)
        .background(Theme.categoryTint(proposed.category).opacity(0.4), in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Tag Search

    @ViewBuilder
    private var tagSearchSection: some View {
        if let tag = searchTag {
            let results = findBulletsByTag(tag)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "number").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.accent)
                    Text(tag).font(.inter(16, weight: .bold)).foregroundStyle(Theme.textPrimary)
                    Text("\(results.count) bullets").font(.inter(11)).foregroundStyle(Theme.textMuted)
                    Spacer()
                }
                ForEach(results, id: \.id) { result in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.dateDisplay).font(.inter(10, weight: .medium)).foregroundStyle(Theme.textMuted)
                            Text(stripTags(result.bulletText)).font(.inter(13)).foregroundStyle(Theme.textPrimary).textSelection(.enabled)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                    .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.border, lineWidth: 1))
                }
            }
        }
    }

    // MARK: - Past Days

    private var pastSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Past Days").font(.inter(14, weight: .semibold)).foregroundStyle(Theme.textMuted)
            ForEach(pastDumps) { dump in
                pastDayRow(dump)
            }
        }
    }

    @ViewBuilder
    private func pastDayRow(_ dump: DailyDump) -> some View {
        let isExpanded = expandedPastDays.contains(dump.date)
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded { expandedPastDays.remove(dump.date) } else { expandedPastDays.insert(dump.date) }
                }
            } label: {
                HStack {
                    Text(DailyDump.displayDate(dump.date)).font(.inter(12, weight: .medium)).foregroundStyle(Theme.textPrimary)
                    let count = dump.content.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
                    Text("\(count) bullets").font(.inter(10)).foregroundStyle(Theme.textMuted)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down").font(.system(size: 9)).foregroundStyle(Theme.textMuted)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Theme.cardAlt, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(dump.content).font(.inter(12)).foregroundStyle(Theme.textSecondary).textSelection(.enabled)
                    .padding(12)
                    .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Logic

    private var bulletCount: Int {
        content.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    private func handleContentChange(_ newValue: String) {
        guard !isUpdating else { return }
        var updated = newValue

        updated = updated.replacingOccurrences(of: "\n* ", with: "\n• ")
        updated = updated.replacingOccurrences(of: "\n*", with: "\n• ")
        if updated.hasPrefix("* ") { updated = "• " + String(updated.dropFirst(2)) }
        if updated == "*" { updated = "• " }
        if !updated.isEmpty && !updated.hasPrefix("• ") && !updated.contains("\n") { updated = "• " + updated }

        // Process magic tags on Enter
        if updated.hasSuffix("\n") {
            let lines = updated.components(separatedBy: "\n")
            if lines.count >= 2 {
                let completedLine = lines[lines.count - 2]
                processMagicTags(line: completedLine)
            }
            updated += "• "
        }

        if updated != newValue {
            isUpdating = true
            content = updated
            DispatchQueue.main.async { isUpdating = false }
        }
    }

    private func processMagicTags(line: String) {
        let bullet = DumpBullet.parse(from: line).first
        guard let bullet, !bullet.magicTags.isEmpty else { return }

        let cleanText = stripTags(bullet.text)
        guard !cleanText.isEmpty else { return }

        for magic in bullet.magicTags {
            switch magic {
            case .action:
                let item = Item.new(text: cleanText, category: .action)
                try? Queries.addItem(item)
                try? Queries.tagItemWithNames(itemId: item.id, tagNames: bullet.tags)
                appState.refreshCounts()
            case .brainstorm:
                let item = Item.new(text: cleanText, category: .brainstorm)
                try? Queries.addItem(item)
                try? Queries.tagItemWithNames(itemId: item.id, tagNames: bullet.tags)
                appState.refreshCounts()
            case .resource:
                let item = Item.new(text: cleanText, category: .resource)
                try? Queries.addItem(item)
                try? Queries.tagItemWithNames(itemId: item.id, tagNames: bullet.tags)
                appState.refreshCounts()
            case .win:
                let win = Win.new(text: cleanText)
                try? Queries.addWin(win)
                appState.refreshCounts()
            case .save:
                for tagName in bullet.tags {
                    if let tag = try? Queries.getOrCreateTag(name: tagName),
                       let doc = try? Queries.getMasterDoc(tagId: tag.id) {
                        let newContent = doc.content.isEmpty ? "• \(cleanText)" : "\(doc.content)\n• \(cleanText)"
                        try? Queries.upsertMasterDoc(tagId: tag.id, content: newContent, title: doc.title)
                    } else if let tag = try? Queries.getOrCreateTag(name: tagName) {
                        let title = tagName.replacingOccurrences(of: "-", with: " ").capitalized
                        try? Queries.upsertMasterDoc(tagId: tag.id, content: "• \(cleanText)", title: title)
                    }
                }
            }
        }
    }

    private func stripTags(_ text: String) -> String {
        text.replacingOccurrences(of: #"#[\w\-]+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    private func collectAllTags() -> [String] {
        var allDumps = pastDumps
        if let today = todayDump { allDumps.insert(today, at: 0) }
        var tagSet = Set<String>()
        for dump in allDumps {
            let bullets = DumpBullet.parse(from: dump.content)
            for bullet in bullets { tagSet.formUnion(bullet.tags) }
        }
        return tagSet.sorted()
    }

    private func findBulletsByTag(_ tag: String) -> [TagSearchResult] {
        var results: [TagSearchResult] = []
        var allDumps = pastDumps
        if let today = todayDump { allDumps.insert(today, at: 0) }
        for dump in allDumps {
            let bullets = DumpBullet.parse(from: dump.content)
            for bullet in bullets where bullet.tags.contains(tag) && !bullet.isRetired {
                results.append(TagSearchResult(id: UUID(), date: dump.date, dateDisplay: DailyDump.displayDate(dump.date), bulletText: bullet.text))
            }
        }
        return results
    }

    private func applyTagSuggestion(index: Int, suggestion: AIService.SuggestedTag) {
        let lines = content.components(separatedBy: "\n")
        let updated = lines.map { line -> String in
            let stripped = line.hasPrefix("• ") ? String(line.dropFirst(2)) : line
            if stripped.trimmingCharacters(in: .whitespaces) == suggestion.bulletText.trimmingCharacters(in: .whitespaces) {
                return line + " #\(suggestion.tag)"
            }
            return line
        }
        content = updated.joined(separator: "\n")
        saveDraft()
        _ = withAnimation { suggestedTags.remove(at: index) }
    }

    private func acceptItem(at index: Int) {
        let proposed = proposedItems[index]
        if proposed.isWin {
            let win = Win.new(text: proposed.text)
            try? Queries.addWin(win)
        } else {
            let item = Item.new(text: proposed.text, category: proposed.category)
            try? Queries.addItem(item)
            try? Queries.tagItemWithNames(itemId: item.id, tagNames: proposed.tags)
        }
        appState.refreshCounts()
        _ = withAnimation { proposedItems.remove(at: index) }
    }

    private func performMerge() {
        guard let source = mergeSource, let target = mergeTarget else { return }
        content = content.replacingOccurrences(of: "#\(source)", with: "#\(target)")
        saveDraft()
        for dump in pastDumps {
            let updated = dump.content.replacingOccurrences(of: "#\(source)", with: "#\(target)")
            if updated != dump.content { try? Queries.updateDumpContent(id: dump.id, content: updated) }
        }
        mergeSource = nil; mergeTarget = nil
        reload()
    }

    private func makeSubTag(child: String, parent: String) {
        if let parentTag = try? Queries.getOrCreateTag(name: parent),
           let childTag = try? Queries.getOrCreateTag(name: child) {
            try? Queries.addSubTag(parentTagId: parentTag.id, childTagId: childTag.id)
        }
    }

    private func analyze() {
        isAnalyzing = true
        Task {
            do {
                let result = try await AIService.analyzeDump(content: content)
                await MainActor.run {
                    proposedItems = result.proposedItems
                    suggestedTags = result.suggestedTags
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run { isAnalyzing = false }
            }
        }
    }

    private func saveDraft() {
        guard let dump = todayDump else { return }
        try? Queries.updateDumpContent(id: dump.id, content: content)
    }

    private func reload() {
        todayDump = try? Queries.getOrCreateTodayDump()
        content = todayDump?.content ?? ""
        let all = (try? Queries.getAllDumps()) ?? []
        pastDumps = all.filter { $0.date != DailyDump.today() }
        attentionItems = (try? Queries.getOverdueAndDueToday()) ?? []
    }
}

struct TagSearchResult: Identifiable {
    let id: UUID
    let date: String
    let dateDisplay: String
    let bulletText: String
}
