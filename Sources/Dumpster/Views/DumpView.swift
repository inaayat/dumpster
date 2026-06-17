import SwiftUI

struct DumpView: View {
    @Bindable var appState: AppState
    @State private var todayDump: DailyDump?
    @State private var pastDumps: [DailyDump] = []
    @State private var content = ""
    @State private var editorHeight: CGFloat = 300
    @State private var isAnalyzing = false
    @State private var proposedItems: [AIService.ProposedItem] = []
    @State private var suggestedTags: [AIService.SuggestedTag] = []
    @State private var expandedPastDays: Set<String> = []
    @State private var searchTag: String? = nil
    @State private var tagFilter = ""
    @State private var showMergeConfirm = false
    @State private var mergeSource: String? = nil
    @State private var mergeTarget: String? = nil
    @State private var showTagDropAction = false
    @State private var tagDropSource: String? = nil
    @State private var tagDropTarget: String? = nil
    @State private var attentionItems: [Item] = []
    @State private var showMasterDocPanel = false
    @State private var selectedBulletIds: Set<UUID> = []
    @State private var docRefreshToken = 0
    @State private var editingBulletId: UUID? = nil
    @State private var editedBulletText = ""

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                    attentionBar
                    header
                    magicTagsGuide
                    tagBar
                    if searchTag != nil {
                        tagSearchSection
                            .id(docRefreshToken)
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

            if showMasterDocPanel, let tag = searchTag,
               let tagId = resolveTagId(tag) {
                Divider()
                MasterDocCore(
                    tagId: tagId,
                    tagDisplayName: tag,
                    mode: .panel,
                    showSubTagSettings: true,
                    onClose: { withAnimation { showMasterDocPanel = false } },
                    onDocUpdated: { docRefreshToken += 1 }
                )
                .frame(minWidth: 300, maxWidth: .infinity)
            }
        }
        .onAppear { reload() }
    }

    // MARK: - Attention Bar (always expanded, all high-prio items)

    @ViewBuilder
    private var attentionBar: some View {
        if !attentionItems.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.warnColor)
                    Text("\(attentionItems.count) items need attention")
                        .font(.inter(11, weight: .semibold))
                        .foregroundStyle(Theme.warnColor)
                }

                ForEach(attentionItems) { item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(item.isOverdue ? Color.red : (item.isDueToday ? Theme.warnColor : Theme.actionColor))
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
                        } else {
                            Text("high prio")
                                .font(.inter(8, weight: .bold))
                                .foregroundStyle(Theme.actionColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { appState.openDetail(itemId: item.id) }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
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

    // MARK: - Magic Tags Guide

    private var magicTagsGuide: some View {
        HStack(spacing: 0) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 10))
                .foregroundStyle(Theme.accent)
                .padding(.trailing, 8)

            Group {
                magicTagLabel("#action", color: Theme.successColor)
                separator
                magicTagLabel("#prio", color: Color.red)
                separator
                magicTagLabel("#backlog", color: Color.gray)
                separator
                magicTagLabel("#brainstorm", color: Theme.brainstormColor)
                separator
                magicTagLabel("#win", color: Theme.warnColor)
                separator
                magicTagLabel("#save", color: Theme.accent)
            }

            Spacer()

            Text("Toss items on Enter")
                .font(.inter(9))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Theme.accent.opacity(0.04), in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.accent.opacity(0.15), lineWidth: 1))
    }

    private func magicTagLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.inter(10, weight: .semibold))
            .foregroundStyle(color)
    }

    private var separator: some View {
        Text("·")
            .font(.inter(10))
            .foregroundStyle(Theme.textMuted.opacity(0.5))
            .padding(.horizontal, 6)
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
                                TagPill(tag: tag, isSelected: searchTag == tag, action: {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        searchTag = (searchTag == tag) ? nil : tag
                                        showMasterDocPanel = false
                                        selectedBulletIds.removeAll()
                                    }
                                }, onRename: { oldName, newName in
                                    renameTag(oldName: oldName, newName: newName)
                                }, onOpenDoc: {
                                    openMasterDoc(tagName: tag)
                                }, onDelete: {
                                    deleteTag(name: tag)
                                })
                                .draggable(tag) {
                                    Text("#\(tag)")
                                        .font(.inter(12, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Theme.accent, in: Capsule())
                                }
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
                                    withAnimation { searchTag = nil; showMasterDocPanel = false }
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
                DumpTextEditor(text: $content, fontSize: 13, focusOnAppear: true,
                               onHeightChange: { h in editorHeight = max(300, h) })
                    .frame(height: editorHeight)
                    .padding(12)
                    .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                    .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.border, lineWidth: 1))
                    .onChange(of: content) { oldValue, newValue in
                        // Only transform when ADDING text (never on delete/backspace)
                        guard newValue.count > oldValue.count else { saveDraft(); return }

                        var updated = newValue

                        // Replace * with • when typed at start of a line
                        if updated.hasSuffix("* ") {
                            let beforeStar = updated.dropLast(2)
                            if beforeStar.isEmpty || beforeStar.last == "\n" {
                                updated = String(beforeStar) + "• "
                            }
                        }

                        // Enter pressed — add bullet on new line + process magic tags
                        if updated.hasSuffix("\n") {
                            let lines = updated.components(separatedBy: "\n")
                            if lines.count >= 2 {
                                let completedLine = lines[lines.count - 2]
                                if !completedLine.trimmingCharacters(in: .whitespaces).isEmpty {
                                    updated = processLineIfNeeded(updated, line: completedLine)
                                    processMagicTags(line: completedLine)
                                }
                            }
                            updated += "• "
                        }

                        // Space after #tag — register tags in DB but don't process magic tags yet
                        // (magic tags fire on Enter, after all tags on the line have been typed)
                        if updated.hasSuffix(" ") {
                            let lines = updated.components(separatedBy: "\n")
                            if let currentLine = lines.last, currentLine.contains("#") {
                                updated = processLineIfNeeded(updated, line: currentLine)
                            }
                        }

                        if updated != newValue {
                            content = updated
                        }
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

    // MARK: - Review Section (Proposed Items)

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
            // Category pill — tap to cycle
            Button {
                cycleCategory(at: index)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: categoryIcon(proposedItems[index].category, isWin: proposedItems[index].isWin))
                        .font(.system(size: 9, weight: .semibold))
                    Text(proposedItems[index].isWin ? "Win" : proposedItems[index].category.label)
                        .font(.inter(10, weight: .semibold))
                }
                .foregroundStyle(categoryColor(proposedItems[index].category, isWin: proposedItems[index].isWin))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(categoryColor(proposedItems[index].category, isWin: proposedItems[index].isWin).opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)

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
        .background(categoryColor(proposed.category, isWin: proposed.isWin).opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    private func cycleCategory(at index: Int) {
        let order: [(Category, Bool)] = [(.action, false), (.brainstorm, false), (.resource, false), (.action, true)]
        let current = (proposedItems[index].category, proposedItems[index].isWin)
        let currentIdx = order.firstIndex(where: { $0.0 == current.0 && $0.1 == current.1 }) ?? 0
        let next = order[(currentIdx + 1) % order.count]
        proposedItems[index].category = next.0
        proposedItems[index].isWin = next.1
    }

    private func categoryIcon(_ category: Category, isWin: Bool) -> String {
        if isWin { return "star.fill" }
        return category.icon
    }

    private func categoryColor(_ category: Category, isWin: Bool) -> Color {
        if isWin { return Theme.warnColor }
        return Theme.categoryColor(category)
    }

    // MARK: - Tag Search with Master Doc Panel

    @ViewBuilder
    private var tagSearchSection: some View {
        if let tag = searchTag {
            let docContent = getMasterDocContent(for: tag)
            let results = findBulletsByTag(tag)
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "number").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.accent)
                    Text(tag).font(.inter(16, weight: .bold)).foregroundStyle(Theme.textPrimary)
                    Text("\(results.count) bullets").font(.inter(11)).foregroundStyle(Theme.textMuted)
                    Spacer()

                    // Master Doc button
                    Button {
                        withAnimation { showMasterDocPanel.toggle() }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "doc.text.fill").font(.system(size: 9))
                            Text("Master Doc").font(.inter(9, weight: .medium))
                        }
                        .foregroundStyle(showMasterDocPanel ? .white : Theme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(showMasterDocPanel ? Theme.accent : Theme.accent.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    // Send selected to doc
                    if !selectedBulletIds.isEmpty && showMasterDocPanel {
                        Button {
                            sendSelectedToDoc(tag: tag)
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.right.doc").font(.system(size: 9))
                                Text("Send \(selectedBulletIds.count) to doc").font(.inter(9, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.successColor, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Bullets sorted: not-in-doc first
                let sorted = results.sorted { a, b in
                    let aInDoc = bulletIsInDoc(a.bulletText, docContent: docContent)
                    let bInDoc = bulletIsInDoc(b.bulletText, docContent: docContent)
                    if aInDoc != bInDoc { return !aInDoc }
                    return false
                }

                ForEach(sorted, id: \.id) { result in
                    let isInDoc = bulletIsInDoc(result.bulletText, docContent: docContent)
                    let isSelected = selectedBulletIds.contains(result.id)

                    HStack(spacing: 8) {
                        // Checkbox / in-doc indicator
                        if isInDoc {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.successColor.opacity(0.6))
                        } else {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 14))
                                .foregroundStyle(isSelected ? Theme.accent : Theme.textMuted.opacity(0.3))
                                .onTapGesture {
                                    if isSelected { selectedBulletIds.remove(result.id) }
                                    else { selectedBulletIds.insert(result.id) }
                                }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(result.dateDisplay).font(.inter(10, weight: .medium)).foregroundStyle(Theme.textMuted)
                                if isInDoc {
                                    Text("in doc")
                                        .font(.inter(8, weight: .bold))
                                        .foregroundStyle(Theme.successColor)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Theme.successColor.opacity(0.1), in: Capsule())
                                }
                            }
                            if editingBulletId == result.id {
                                TextField("", text: $editedBulletText)
                                    .font(.inter(13))
                                    .textFieldStyle(.plain)
                                    .onSubmit { commitBulletEdit(result: result) }
                                    .onExitCommand { editingBulletId = nil }
                            } else {
                                Text(stripTags(result.bulletText))
                                    .font(.inter(13))
                                    .foregroundStyle(isInDoc ? Theme.textMuted : Theme.textPrimary)
                                    .textSelection(.enabled)
                                    .onTapGesture(count: 2) {
                                        editingBulletId = result.id
                                        editedBulletText = result.bulletText
                                    }
                            }
                        }
                        Spacer()

                        // Add to doc button (only if not in doc and panel is open)
                        if !isInDoc && showMasterDocPanel {
                            Button {
                                appendBulletToMasterDoc(text: result.bulletText, tag: tag)
                            } label: {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.accent)
                            }
                            .buttonStyle(.plain)
                            .help("Append as bullet (drag into doc for AI sort)")
                        }
                    }
                    .padding(10)
                    .background(
                        isInDoc ? Theme.successColor.opacity(0.04) : (isSelected ? Theme.accent.opacity(0.06) : Theme.cardBg),
                        in: RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    )
                    .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(
                        isInDoc ? Theme.successColor.opacity(0.2) : (isSelected ? Theme.accent.opacity(0.5) : Theme.border), lineWidth: 1
                    ))
                    .draggable(result.bulletText) {
                        Text(result.bulletText)
                            .font(.inter(11))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(2)
                            .padding(8)
                            .frame(maxWidth: 280, alignment: .leading)
                            .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: 6))
                            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                    }
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
                VStack(alignment: .leading, spacing: 6) {
                    Text(dump.content).font(.inter(12)).foregroundStyle(Theme.textSecondary).textSelection(.enabled)
                        .padding(12)

                    HStack {
                        Spacer()
                        Button {
                            analyzePastDump(dump)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                Text("Analyze with AI")
                            }
                            .font(.inter(10, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.plain)
                        .disabled(isAnalyzing)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
                .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Logic

    private var bulletCount: Int {
        content.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }


    private func processMagicTags(line: String) {
        MagicTagProcessor.processLine(line)
        appState.refreshCounts()
    }

    private func openMasterDoc(tagName: String) {
        guard let tag = try? Queries.getOrCreateTag(name: tagName) else { return }
        withAnimation { appState.openMasterDocPanel(tagId: tag.id) }
    }

    private func renameTag(oldName: String, newName: String) {
        if let tag = try? Queries.getTagByName(oldName) {
            try? Queries.renameTagEverywhere(id: tag.id, oldName: oldName, newName: newName)
        } else {
            // Tag doesn't exist in DB (orphaned in dump text) — just fix the text
            let normalized = newName.lowercased().trimmingCharacters(in: .whitespaces)
            let pattern = "#\(NSRegularExpression.escapedPattern(for: oldName.lowercased()))(?![\\w\\-])"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let allDumps = (try? Queries.getAllDumps()) ?? []
                for dump in allDumps {
                    let updated = regex.stringByReplacingMatches(in: dump.content, range: NSRange(dump.content.startIndex..., in: dump.content), withTemplate: "#\(normalized)")
                    if updated != dump.content {
                        try? Queries.updateDumpContent(id: dump.id, content: updated)
                    }
                }
            }
        }
        if let dump = try? Queries.getOrCreateTodayDump() {
            content = dump.content
        }
        if searchTag == oldName { searchTag = newName }
        reload()
    }

    private func deleteTag(name: String) {
        guard let tag = try? Queries.getTagByName(name) else { return }
        try? Queries.deleteTag(id: tag.id)
        if searchTag == name { searchTag = nil }
        reload()
    }

    private func resolveTagId(_ name: String) -> String? {
        (try? Queries.getOrCreateTag(name: name))?.id
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
            for bullet in bullets where bullet.tags.contains(tag) {
                results.append(TagSearchResult(id: UUID(), dumpId: dump.id, date: dump.date, dateDisplay: DailyDump.displayDate(dump.date), bulletText: bullet.text, rawLine: bullet.rawLine))
            }
        }
        return results
    }

    private func commitBulletEdit(result: TagSearchResult) {
        let newText = editedBulletText.trimmingCharacters(in: .whitespaces)
        guard !newText.isEmpty else { editingBulletId = nil; return }

        let newLine = "• \(newText)"
        let isToday = result.date == DailyDump.today()

        if isToday {
            content = content.replacingOccurrences(of: result.rawLine, with: newLine)
            saveDraft()
        } else {
            if let dump = pastDumps.first(where: { $0.id == result.dumpId }) {
                let updated = dump.content.replacingOccurrences(of: result.rawLine, with: newLine)
                try? Queries.updateDumpContent(id: dump.id, content: updated)
            }
        }
        editingBulletId = nil
        reload()
    }

    private func bulletIsInDoc(_ bulletText: String, docContent: String) -> Bool {
        guard !docContent.isEmpty else { return false }
        let stripped = stripTags(bulletText).trimmingCharacters(in: .whitespaces)
        guard stripped.count > 5 else { return false }
        return docContent.localizedCaseInsensitiveContains(stripped)
    }

    private func getMasterDocContent(for tagName: String) -> String {
        guard let tag = try? Queries.getTagByName(tagName),
              let doc = try? Queries.getMasterDoc(tagId: tag.id) else { return "" }
        return doc.content
    }

    private func appendBulletToMasterDoc(text: String, tag: String) {
        guard let tagRecord = try? Queries.getOrCreateTag(name: tag) else { return }
        let existing = try? Queries.getMasterDoc(tagId: tagRecord.id)
        let currentContent = existing?.content ?? ""
        let title = existing?.title ?? tag.replacingOccurrences(of: "-", with: " ").capitalized
        let bullet = "• \(stripTags(text))"
        let newContent = currentContent.isEmpty ? bullet : currentContent + "\n" + bullet
        try? Queries.upsertMasterDoc(tagId: tagRecord.id, content: newContent, title: title)
        docRefreshToken += 1
    }

    private func sendSelectedToDoc(tag: String) {
        let results = findBulletsByTag(tag)
        let selectedTexts = results.filter { selectedBulletIds.contains($0.id) }.map { stripTags($0.bulletText) }
        guard !selectedTexts.isEmpty else { return }

        guard let tagRecord = try? Queries.getOrCreateTag(name: tag),
              let doc = try? Queries.getMasterDoc(tagId: tagRecord.id) else { return }

        // Use AI to insert into doc
        Task {
            do {
                let result = try await AIService.insertBulletsIntoDoc(existingContent: doc.content, bullets: selectedTexts)
                try? Queries.upsertMasterDoc(tagId: tagRecord.id, content: result, title: doc.title)
                await MainActor.run {
                    selectedBulletIds.removeAll()
                    docRefreshToken += 1
                }
            } catch {}
        }
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
        if let sourceTag = try? Queries.getTagByName(source) {
            try? Queries.renameTagEverywhere(id: sourceTag.id, oldName: source, newName: target)
        }
        mergeSource = nil; mergeTarget = nil
        if let dump = try? Queries.getOrCreateTodayDump() {
            content = dump.content
        }
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

    private func analyzePastDump(_ dump: DailyDump) {
        isAnalyzing = true
        Task {
            do {
                let result = try await AIService.analyzeDump(content: dump.content)
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

    private func processLineIfNeeded(_ text: String, line: String) -> String {
        let bullet = DumpBullet.parse(from: line).first
        guard let bullet else { return text }
        for tagName in bullet.tags {
            _ = try? Queries.getOrCreateTag(name: tagName)
        }
        return text
    }

    private func saveDraft() {
        guard let dump = todayDump else { return }
        try? Queries.updateDumpContent(id: dump.id, content: content)
        ensureAllTagsRegistered()
    }

    private func ensureAllTagsRegistered() {
        let bullets = DumpBullet.parse(from: content)
        let allTags = Set(bullets.flatMap { $0.tags })
        for tagName in allTags {
            _ = try? Queries.getOrCreateTag(name: tagName)
        }
    }

    private func stripAcknowledged(_ raw: String) -> String {
        raw.components(separatedBy: "\n").map { line in
            line.replacingOccurrences(of: " [acknowledged]", with: "")
                .replacingOccurrences(of: "[acknowledged]", with: "")
                .trimmingCharacters(in: .whitespaces)
        }.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    private func reload() {
        todayDump = try? Queries.getOrCreateTodayDump()
        let raw = todayDump?.content ?? ""
        let normalized = stripAcknowledged(raw)
        content = normalized
        if normalized != raw, let dump = todayDump {
            try? Queries.updateDumpContent(id: dump.id, content: normalized)
        }
        let all = (try? Queries.getAllDumps()) ?? []
        pastDumps = all.filter { $0.date != DailyDump.today() }
        // All high-prio items + overdue/due-today
        let overdueDueToday = (try? Queries.getOverdueAndDueToday()) ?? []
        let highPrio = (try? Queries.getItems(category: nil, done: false))?.filter { $0.priority == .high } ?? []
        var combined: [Item] = []
        var seenIds = Set<String>()
        for item in (overdueDueToday + highPrio) {
            if seenIds.insert(item.id).inserted { combined.append(item) }
        }
        attentionItems = combined
    }
}

struct TagSearchResult: Identifiable {
    let id: UUID
    let dumpId: String
    let date: String
    let dateDisplay: String
    let bulletText: String
    let rawLine: String
}
