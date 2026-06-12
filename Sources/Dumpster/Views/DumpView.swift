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
    @State private var showRetiredSection = false

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

            if showMasterDocPanel, let tag = searchTag {
                Divider()
                MasterDocPanelView(tag: tag, onClose: {
                    withAnimation { showMasterDocPanel = false }
                }, onDocUpdated: {
                    docRefreshToken += 1
                })
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
                                })
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
                DumpTextEditor(text: $content, fontSize: 13)
                    .frame(minHeight: 300)
                    .fixedSize(horizontal: false, vertical: true)
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
                                }
                            }
                            updated += "• "
                        }

                        // Space after #tag — check current line for new tags/magic tags
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

                        // Retire button
                        Button {
                            retireBullet(result: result)
                        } label: {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textMuted.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                        .help("Retire this bullet")

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
                    .draggable(result.bulletText)
                }

                // Retired section
                let retired = findRetiredBulletsByTag(tag)
                if !retired.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { showRetiredSection.toggle() }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: showRetiredSection ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(Theme.textMuted)
                                Text("Retired")
                                    .font(.inter(11, weight: .medium))
                                    .foregroundStyle(Theme.textMuted)
                                Text("\(retired.count)")
                                    .font(.inter(9))
                                    .foregroundStyle(Theme.textMuted.opacity(0.6))
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 16)

                        if showRetiredSection {
                            ForEach(retired, id: \.id) { result in
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Theme.textMuted.opacity(0.3))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.dateDisplay)
                                            .font(.inter(9))
                                            .foregroundStyle(Theme.textMuted.opacity(0.5))
                                        Text(stripTags(result.bulletText))
                                            .font(.inter(12))
                                            .foregroundStyle(Theme.textMuted.opacity(0.5))
                                            .strikethrough()
                                    }
                                    Spacer()
                                }
                                .padding(8)
                                .background(Theme.cardAlt.opacity(0.5), in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                            }
                        }
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
        let bullet = DumpBullet.parse(from: line).first
        guard let bullet, !bullet.magicTags.isEmpty else { return }

        let cleanText = stripTags(bullet.text)
        guard !cleanText.isEmpty else { return }

        let isHighPrio = bullet.magicTags.contains(.prio)

        for magic in bullet.magicTags {
            switch magic {
            case .action:
                let item = Item.new(text: cleanText, category: .action, priority: isHighPrio ? .high : .medium)
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
            case .prio:
                // If used alone (without #action), auto-create as high-prio action
                if !bullet.magicTags.contains(.action) && !bullet.magicTags.contains(.brainstorm) {
                    let item = Item.new(text: cleanText, category: .action, priority: .high)
                    try? Queries.addItem(item)
                    try? Queries.tagItemWithNames(itemId: item.id, tagNames: bullet.tags)
                    appState.refreshCounts()
                }
            case .delete:
                // Find and delete items matching this bullet's text
                if let allItems = try? Queries.searchItems(query: cleanText) {
                    for item in allItems where stripTags(item.text).trimmingCharacters(in: .whitespaces) == cleanText {
                        try? Queries.deleteItem(id: item.id)
                    }
                    appState.refreshCounts()
                }
            }
        }
    }

    private func renameTag(oldName: String, newName: String) {
        guard let tag = try? Queries.getTagByName(oldName) else { return }
        try? Queries.renameTagEverywhere(id: tag.id, oldName: oldName, newName: newName)
        // Update local content if today's dump was affected
        if let dump = try? Queries.getOrCreateTodayDump() {
            content = dump.content
        }
        if searchTag == oldName { searchTag = newName }
        reload()
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
                results.append(TagSearchResult(id: UUID(), dumpId: dump.id, date: dump.date, dateDisplay: DailyDump.displayDate(dump.date), bulletText: bullet.text, rawLine: bullet.rawLine))
            }
        }
        return results
    }

    private func findRetiredBulletsByTag(_ tag: String) -> [TagSearchResult] {
        var results: [TagSearchResult] = []
        var allDumps = pastDumps
        if let today = todayDump { allDumps.insert(today, at: 0) }
        for dump in allDumps {
            let bullets = DumpBullet.parse(from: dump.content)
            for bullet in bullets where bullet.tags.contains(tag) && bullet.isRetired {
                results.append(TagSearchResult(id: UUID(), dumpId: dump.id, date: dump.date, dateDisplay: DailyDump.displayDate(dump.date), bulletText: bullet.text, rawLine: bullet.rawLine))
            }
        }
        return results
    }

    private func retireBullet(result: TagSearchResult) {
        let marker = DumpBullet.retiredMarker
        let isToday = result.date == DailyDump.today()

        if isToday {
            content = content.replacingOccurrences(of: result.rawLine, with: result.rawLine + marker)
            saveDraft()
        } else {
            if let dump = pastDumps.first(where: { $0.id == result.dumpId }) {
                let updated = dump.content.replacingOccurrences(of: result.rawLine, with: result.rawLine + marker)
                try? Queries.updateDumpContent(id: dump.id, content: updated)
                reload()
            }
        }
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
        var updated = text
        let bullet = DumpBullet.parse(from: line).first
        guard let bullet else { return updated }

        // Register any regular tags
        for tagName in bullet.tags {
            _ = try? Queries.getOrCreateTag(name: tagName)
        }

        if bullet.isRetired {
            // Already processed — but check if new tags were added that need associating
            let cleanText = stripTags(bullet.text).trimmingCharacters(in: .whitespaces)
            if !cleanText.isEmpty && !bullet.tags.isEmpty {
                // Find the item by text match and associate new tags
                if let items = try? Queries.searchItems(query: cleanText),
                   let item = items.first(where: { stripTags($0.text) == cleanText }) {
                    try? Queries.tagItemWithNames(itemId: item.id, tagNames: bullet.tags)
                }
            }
        } else if !bullet.magicTags.isEmpty {
            // Has unprocessed magic tags — create item + retire
            processMagicTags(line: line)
            let retiredLine = line + DumpBullet.retiredMarker
            updated = updated.replacingOccurrences(of: line, with: retiredLine)
        }

        return updated
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

        // Process any non-retired bullets with magic tags (catches edge cases)
        var contentChanged = false
        var updatedContent = content
        for bullet in bullets where !bullet.isRetired && !bullet.magicTags.isEmpty {
            processMagicTags(line: bullet.rawLine)
            let retiredLine = bullet.rawLine + DumpBullet.retiredMarker
            updatedContent = updatedContent.replacingOccurrences(of: bullet.rawLine, with: retiredLine)
            contentChanged = true
        }

        if contentChanged {
            content = updatedContent
            if let dump = todayDump {
                try? Queries.updateDumpContent(id: dump.id, content: content)
            }
        }
    }

    private func reload() {
        todayDump = try? Queries.getOrCreateTodayDump()
        content = todayDump?.content ?? ""
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

// MARK: - Master Doc Panel (slides in from right)

struct MasterDocPanelView: View {
    let tag: String
    var onClose: () -> Void
    var onDocUpdated: (() -> Void)? = nil

    @State private var content = ""
    @State private var title = ""
    @State private var isSynthesizing = false
    @State private var isInserting = false
    @State private var isDragOver = false
    @State private var fontSize: CGFloat = 13
    @State private var highlightInsertions = false
    @State private var synthesizedPreview: String?
    @State private var showEmptyDocPrompt = false
    @State private var pendingBullets: [String] = []
    @State private var showSubTagSettings = false
    @StateObject private var editorHandle = RichMarkdownEditorHandle()

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider()
            panelToolbar
            Divider()

            if isInserting {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("AI is placing bullets into the doc...")
                        .font(.inter(11)).foregroundStyle(Theme.textMuted)
                }
                .padding(12)
                Divider()
            }

            if let preview = synthesizedPreview {
                synthesizePreviewSection(preview)
                Divider()
            }

            // Editor with drop zone
            ZStack {
                RichMarkdownEditorWithHandle(markdown: $content, handle: editorHandle, fontSize: fontSize)
                    .onChange(of: content) { saveDoc() }
                    .opacity(highlightInsertions ? 0.85 : 1.0)
                    .allowsHitTesting(!isDragOver)

                if isDragOver {
                    VStack(spacing: 10) {
                        Image(systemName: "arrow.down.doc.fill").font(.system(size: 28)).foregroundStyle(Theme.accent)
                        Text("Drop to AI-sort into doc").font(.inter(13, weight: .semibold)).foregroundStyle(Theme.accent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.accent.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius)
                            .strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 2, dash: [8]))
                            .padding(8)
                    )
                }
            }
            .dropDestination(for: String.self) { dropped, _ in
                isDragOver = false
                let bullets = dropped.flatMap { $0.components(separatedBy: "\n") }.filter { !$0.isEmpty }
                guard !bullets.isEmpty else { return false }
                handleDroppedBullets(bullets)
                return true
            } isTargeted: { targeted in
                isDragOver = targeted
            }
        }
        .background(Theme.canvas)
        .onAppear { loadDoc() }
        .alert("Empty Document", isPresented: $showEmptyDocPrompt) {
            Button("Create Sections") {
                aiInsertBullets(pendingBullets, createStructure: true)
            }
            Button("Just Append") {
                let joined = pendingBullets.map { "• \($0)" }.joined(separator: "\n")
                content = joined
                saveDoc()
                onDocUpdated?()
                pendingBullets = []
            }
            Button("Cancel", role: .cancel) { pendingBullets = [] }
        } message: {
            Text("This doc has no content yet. Should AI create sections from these bullets, or just append them as a list?")
        }
        .sheet(isPresented: $showSubTagSettings) {
            subTagSettingsSheet
        }
    }

    // MARK: - Header

    private var panelHeader: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                TextField("Title", text: $title)
                    .font(.inter(16, weight: .bold))
                    .textFieldStyle(.plain)
                    .onSubmit { saveDoc() }
                Text("#\(tag)")
                    .font(.inter(10, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            Spacer()

            Button { showSubTagSettings = true } label: {
                Image(systemName: "gearshape").font(.system(size: 12)).foregroundStyle(Theme.textMuted)
            }
            .buttonStyle(.plain)
            .help("Sub-tag settings")

            Button { synthesize() } label: {
                HStack(spacing: 3) {
                    Image(systemName: "sparkles")
                    Text(isSynthesizing ? "..." : "Synthesize")
                }
                .font(.inter(10, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .controlSize(.small)
            .disabled(isSynthesizing || content.isEmpty)

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundStyle(Theme.textMuted.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.cardBg)
    }

    // MARK: - Toolbar

    private var panelToolbar: some View {
        HStack(spacing: 2) {
            toolbarBtn(icon: "bold") { editorHandle.toggleBold() }
            toolbarBtn(icon: "italic") { editorHandle.toggleItalic() }
            toolbarBtn(icon: "list.bullet") { editorHandle.toggleBullet() }
            toolbarBtn(icon: "number") { editorHandle.toggleHeading() }
            Divider().frame(height: 14).padding(.horizontal, 4)
            toolbarBtn(icon: "textformat.size.smaller") { if fontSize > 10 { fontSize -= 1 } }
            Text("\(Int(fontSize))").font(.inter(9)).foregroundStyle(Theme.textMuted).frame(width: 16)
            toolbarBtn(icon: "textformat.size.larger") { if fontSize < 20 { fontSize += 1 } }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Theme.cardBg)
    }

    @ViewBuilder
    private func toolbarBtn(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Synthesize Preview

    @ViewBuilder
    private func synthesizePreviewSection(_ preview: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AI Synthesized (preview)")
                .font(.inter(10, weight: .semibold))
                .foregroundStyle(Theme.successColor)
            ScrollView {
                Text(preview)
                    .font(.inter(12))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 150)
            .padding(8)
            .background(Theme.successColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            HStack(spacing: 10) {
                Button("Accept") {
                    content = preview
                    synthesizedPreview = nil
                    saveDoc()
                    onDocUpdated?()
                }
                .font(.inter(10, weight: .semibold))
                .buttonStyle(.borderedProminent)
                .tint(Theme.successColor)
                .controlSize(.mini)
                Button("Dismiss") { synthesizedPreview = nil }
                    .font(.inter(10)).foregroundStyle(Theme.textMuted).buttonStyle(.plain)
            }
        }
        .padding(12)
    }

    // MARK: - Sub-tag Settings

    @ViewBuilder
    private var subTagSettingsSheet: some View {
        let tagRecord = try? Queries.getTagByName(tag)
        let subTags = tagRecord.flatMap { try? Queries.getSubTags(parentTagId: $0.id) } ?? []
        VStack(alignment: .leading, spacing: 16) {
            Text("Sub-tag Settings").font(.inter(16, weight: .bold)).foregroundStyle(Theme.textPrimary)
            Text("Sub-tags of #\(tag)").font(.inter(12)).foregroundStyle(Theme.textMuted)

            if subTags.isEmpty {
                Text("No sub-tags yet. Drag a tag onto this one in the Daily Dump tag bar.")
                    .font(.inter(11)).foregroundStyle(Theme.textMuted).fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 6) {
                    ForEach(subTags) { sub in
                        HStack {
                            Image(systemName: "number").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.accent)
                            Text(sub.name).font(.inter(12, weight: .medium)).foregroundStyle(Theme.textPrimary)
                            Spacer()
                            if let parentId = tagRecord?.id {
                                Button {
                                    try? Queries.removeSubTag(parentTagId: parentId, childTagId: sub.id)
                                } label: {
                                    Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundStyle(Theme.textMuted)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Theme.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            Spacer()
            HStack {
                Spacer()
                Button("Done") { showSubTagSettings = false }
                    .font(.inter(12, weight: .semibold)).buttonStyle(.borderedProminent).tint(Theme.accent)
            }
        }
        .padding(24)
        .frame(width: 340, height: 320)
    }

    // MARK: - Logic

    private func handleDroppedBullets(_ bullets: [String]) {
        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            pendingBullets = bullets
            showEmptyDocPrompt = true
        } else {
            aiInsertBullets(bullets, createStructure: false)
        }
    }

    private func aiInsertBullets(_ bullets: [String], createStructure: Bool) {
        isInserting = true
        let existing = createStructure ? "" : content
        Task {
            do {
                let result = try await AIService.insertBulletsIntoDoc(existingContent: existing, bullets: bullets)
                await MainActor.run {
                    content = result
                    saveDoc()
                    isInserting = false
                    highlightInsertions = true
                    onDocUpdated?()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { highlightInsertions = false }
                    pendingBullets = []
                }
            } catch {
                await MainActor.run { isInserting = false; pendingBullets = [] }
            }
        }
    }

    private func synthesize() {
        isSynthesizing = true
        Task {
            do {
                // Gather ALL bullets with this tag from all dumps
                let allDumps = (try? Queries.getAllDumps()) ?? []
                var bulletTexts: [String] = []
                for dump in allDumps {
                    let bullets = DumpBullet.parse(from: dump.content)
                    for bullet in bullets where !bullet.isRetired && bullet.tags.contains(tag.lowercased()) {
                        bulletTexts.append(bullet.text)
                    }
                }
                let bulletsStr = bulletTexts.isEmpty ? content : bulletTexts.joined(separator: "\n")
                let result = try await AIService.synthesizeMasterDoc(existingContent: content, bullets: bulletsStr)
                await MainActor.run {
                    synthesizedPreview = result
                    isSynthesizing = false
                }
            } catch {
                await MainActor.run { isSynthesizing = false }
            }
        }
    }

    private func saveDoc() {
        guard let tagRecord = try? Queries.getTagByName(tag) ?? Queries.getOrCreateTag(name: tag) else { return }
        let docTitle = title.isEmpty ? tag.replacingOccurrences(of: "-", with: " ").capitalized : title
        try? Queries.upsertMasterDoc(tagId: tagRecord.id, content: content, title: docTitle)
    }

    private func loadDoc() {
        if let tagRecord = try? Queries.getTagByName(tag),
           let doc = try? Queries.getMasterDoc(tagId: tagRecord.id) {
            content = doc.content
            title = doc.title
        } else {
            title = tag.replacingOccurrences(of: "-", with: " ").capitalized
            // Auto-create the doc so it's ready
            if let tagRecord = try? Queries.getOrCreateTag(name: tag) {
                try? Queries.upsertMasterDoc(tagId: tagRecord.id, content: "", title: title)
            }
        }
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
