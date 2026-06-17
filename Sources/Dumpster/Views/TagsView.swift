import SwiftUI

struct TagsView: View {
    @Bindable var appState: AppState
    @State private var topLevelTags: [Tag] = []
    @State private var expandedTags: Set<String> = []
    @State private var subTagsMap: [String: [Tag]] = [:]
    @State private var itemCounts: [String: Int] = [:]
    @State private var renamingTagId: String?
    @State private var renameText = ""
    @State private var showMergeConfirm = false
    @State private var mergeSource: Tag? = nil
    @State private var mergeTarget: Tag? = nil
    @State private var dropTargetId: String? = nil
    @State private var hiddenTags: [Tag] = []
    @State private var showHiddenTags = false
    @State private var tagBullets: [String: [String]] = [:]
    @State private var tagItems: [String: [Item]] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                HStack {
                    Text("Tags")
                        .font(.inter(24, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(topLevelTags.count)")
                        .font(.inter(11, weight: .bold))
                        .foregroundStyle(Theme.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.cardAlt, in: Capsule())
                    Spacer()
                }

                HStack(spacing: 8) {
                    howToChip(icon: "number", text: "Click a tag to see its bullets")
                    howToChip(icon: "arrow.triangle.merge", text: "Drag one tag onto another to merge")
                    howToChip(icon: "cursorarrow.click", text: "Right-click for Master Doc, rename, delete")
                }

                if topLevelTags.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "number")
                            .font(.system(size: 36))
                            .foregroundStyle(Theme.textMuted.opacity(0.4))
                        Text("No tags yet")
                            .font(.inter(14))
                            .foregroundStyle(Theme.textMuted)
                        Text("Tags are created automatically when you use #hashtags in your daily dump.")
                            .font(.inter(12))
                            .foregroundStyle(Theme.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(topLevelTags) { tag in
                            tagRow(tag)
                        }

                        // Hidden tags section
                        if !hiddenTags.isEmpty {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { showHiddenTags.toggle() }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: showHiddenTags ? "chevron.down" : "chevron.right")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(Theme.textMuted)
                                    Image(systemName: "eye.slash")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Theme.textMuted)
                                    Text("Hidden (\(hiddenTags.count))")
                                        .font(.inter(12, weight: .medium))
                                        .foregroundStyle(Theme.textMuted)
                                }
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)

                            if showHiddenTags {
                                ForEach(hiddenTags) { tag in
                                    tagRow(tag)
                                        .opacity(0.55)
                                }
                            }
                        }
                    }
                    .confirmationDialog("Merge Tags", isPresented: $showMergeConfirm) {
                        Button("Merge #\(mergeSource?.name ?? "") → #\(mergeTarget?.name ?? "")") {
                            performMerge()
                        }
                        Button("Cancel", role: .cancel) { mergeSource = nil; mergeTarget = nil }
                    } message: {
                        if let src = mergeSource, let tgt = mergeTarget {
                            Text("Rename #\(src.name) to #\(tgt.name) everywhere — items, dumps, and tags. Cannot be undone.")
                        }
                    }
                }
            }
            .padding(28)
        }
        .background(Theme.canvas)
        .onAppear { reload() }
    }

    @ViewBuilder
    private func tagRow(_ tag: Tag) -> some View {
        let isExpanded = expandedTags.contains(tag.id)
        let count = itemCounts[tag.id] ?? 0
        let bullets = tagBullets[tag.id] ?? []
        let items = tagItems[tag.id] ?? []

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isExpanded {
                            expandedTags.remove(tag.id)
                        } else {
                            expandedTags.insert(tag.id)
                            loadTagDetail(tag)
                        }
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)

                if renamingTagId == tag.id {
                    HStack(spacing: 8) {
                        Image(systemName: "number")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.accent)
                        TextField("", text: $renameText)
                            .textFieldStyle(.plain)
                            .font(.inter(13, weight: .medium))
                            .onSubmit {
                                let newName = renameText.lowercased().trimmingCharacters(in: .whitespaces)
                                if !newName.isEmpty && newName != tag.name {
                                    try? Queries.renameTagEverywhere(id: tag.id, oldName: tag.name, newName: newName)
                                }
                                renamingTagId = nil
                                reload()
                            }
                            .onExitCommand { renamingTagId = nil }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                    .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.accent, lineWidth: 1))
                } else {
                    Button {
                        appState.navigate(to: .tagDetail(tag.id))
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "number")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.accent)
                            Text(tag.name)
                                .font(.inter(13, weight: .medium))
                                .foregroundStyle(Theme.textPrimary)
                            Text("\(count) items")
                                .font(.inter(10))
                                .foregroundStyle(Theme.textMuted)
                            let bulletCount = (tagBullets[tag.id] ?? []).count
                            if isExpanded && bulletCount > 0 {
                                Text("· \(bulletCount) bullets")
                                    .font(.inter(10))
                                    .foregroundStyle(Theme.textMuted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.textMuted)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.cardBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .onTapGesture(count: 2) {
                        renameText = tag.name
                        renamingTagId = tag.id
                    }
                    .onTapGesture(count: 1) {
                        appState.navigate(to: .tagDetail(tag.id))
                    }
                    .draggable(tag.name) {
                        Text("#\(tag.name)")
                            .font(.inter(12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Theme.accent, in: Capsule())
                    }
                    .dropDestination(for: String.self) { dropped, _ in
                        guard let sourceName = dropped.first,
                              sourceName != tag.name,
                              let source = topLevelTags.first(where: { $0.name == sourceName }) else { return false }
                        mergeSource = source
                        mergeTarget = tag
                        showMergeConfirm = true
                        dropTargetId = nil
                        return true
                    } isTargeted: { targeted in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            dropTargetId = targeted ? tag.id : (dropTargetId == tag.id ? nil : dropTargetId)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius)
                            .strokeBorder(Theme.accent, lineWidth: dropTargetId == tag.id ? 2 : 0)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius)
                            .fill(dropTargetId == tag.id ? Theme.accent.opacity(0.08) : Color.clear)
                    )
                    .scaleEffect(dropTargetId == tag.id ? 1.01 : 1.0)
                    .contextMenu {
                        Button {
                            openMasterDoc(tag: tag)
                        } label: {
                            Label("Open Master Doc", systemImage: "doc.text.fill")
                        }
                        Button {
                            renameText = tag.name
                            renamingTagId = tag.id
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        Divider()
                        Button(role: .destructive) {
                            try? Queries.deleteTag(id: tag.id)
                            reload()
                        } label: {
                            Label("Delete Tag", systemImage: "trash")
                        }
                    }
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    // Sub-tags
                    if let children = subTagsMap[tag.id], !children.isEmpty {
                        ForEach(children) { child in
                            let childCount = itemCounts[child.id] ?? 0
                            Button {
                                appState.navigate(to: .tagDetail(child.id))
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "number")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(Theme.accent.opacity(0.7))
                                    Text(child.name)
                                        .font(.inter(12, weight: .medium))
                                        .foregroundStyle(Theme.textSecondary)
                                    Text("\(childCount) items")
                                        .font(.inter(9))
                                        .foregroundStyle(Theme.textMuted)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Theme.cardAlt, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 44)
                        }
                    }

                    // Items
                    if !items.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Items").font(.inter(10, weight: .semibold)).foregroundStyle(Theme.textMuted)
                                .padding(.leading, 44)
                            ForEach(items) { item in
                                HStack(spacing: 8) {
                                    Image(systemName: item.category == .action ? "checkmark.circle" : item.category == .brainstorm ? "lightbulb" : "link")
                                        .font(.system(size: 10))
                                        .foregroundStyle(item.priority == .high ? Theme.warnColor : Theme.accent.opacity(0.6))
                                    Text(item.text)
                                        .font(.inter(12))
                                        .foregroundStyle(item.done ? Theme.textMuted : Theme.textPrimary)
                                        .strikethrough(item.done)
                                        .lineLimit(2)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Theme.cardAlt, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                                .padding(.leading, 44)
                            }
                        }
                    }

                    // Bullets
                    if !bullets.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Bullets").font(.inter(10, weight: .semibold)).foregroundStyle(Theme.textMuted)
                                .padding(.leading, 44)
                            ForEach(bullets, id: \.self) { bullet in
                                HStack(spacing: 8) {
                                    Text("•").font(.inter(11)).foregroundStyle(Theme.textMuted)
                                    Text(bullet)
                                        .font(.inter(12))
                                        .foregroundStyle(Theme.textSecondary)
                                        .lineLimit(2)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Theme.canvas, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                                .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.cardBorder.opacity(0.5), lineWidth: 1))
                                .padding(.leading, 44)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func loadTagDetail(_ tag: Tag) {
        let allDumps = (try? Queries.getAllDumps()) ?? []
        var bullets: [String] = []
        for dump in allDumps {
            for bullet in DumpBullet.parse(from: dump.content) where bullet.tags.contains(tag.name) {
                let clean = bullet.text.replacingOccurrences(of: #"#[\w\-]+"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
                if !clean.isEmpty { bullets.append(clean) }
            }
        }
        tagBullets[tag.id] = bullets
        tagItems[tag.id] = (try? Queries.getItemsForTag(tagId: tag.id, done: nil)) ?? []
    }

    private func performMerge() {
        guard let source = mergeSource, let target = mergeTarget else { return }
        try? Queries.renameTagEverywhere(id: source.id, oldName: source.name, newName: target.name)
        mergeSource = nil; mergeTarget = nil
        reload()
    }

    private func openMasterDoc(tag: Tag) {
        withAnimation { appState.openMasterDocPanel(tagId: tag.id) }
    }

    private func howToChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text(text)
                .font(.inter(11))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private func reload() {
        let all = (try? Queries.getTopLevelTags()) ?? []
        let hiddenTexts = (try? Queries.getHiddenBulletTexts()) ?? []
        let allDumps = (try? Queries.getAllDumps()) ?? []

        var subs: [String: [Tag]] = [:]
        var counts: [String: Int] = [:]
        for tag in all {
            subs[tag.id] = (try? Queries.getSubTags(parentTagId: tag.id)) ?? []
            counts[tag.id] = (try? Queries.getItemCountForTag(tagId: tag.id)) ?? 0
            for child in subs[tag.id] ?? [] {
                counts[child.id] = (try? Queries.getItemCountForTag(tagId: child.id)) ?? 0
            }
        }

        // A tag is "hidden" when it has no active items AND all its dump bullets are hidden
        func allBulletsHidden(_ tag: Tag) -> Bool {
            var tagBullets: [String] = []
            for dump in allDumps {
                let bullets = DumpBullet.parse(from: dump.content)
                for bullet in bullets where bullet.tags.contains(tag.name) {
                    tagBullets.append(bullet.text)
                }
            }
            guard !tagBullets.isEmpty else { return false }
            return tagBullets.allSatisfy { hiddenTexts.contains($0) }
        }

        let activeItemCount: (Tag) -> Int = { tag in
            let own = counts[tag.id] ?? 0
            let child = (subs[tag.id] ?? []).reduce(0) { $0 + (counts[$1.id] ?? 0) }
            return own + child
        }

        let (active, hidden) = all.reduce(into: ([Tag](), [Tag]())) { result, tag in
            let noActiveItems = activeItemCount(tag) == 0
            if noActiveItems && allBulletsHidden(tag) {
                result.1.append(tag)
            } else if activeItemCount(tag) > 0 {
                result.0.append(tag)
            }
        }

        topLevelTags = active.sorted { (counts[$0.id] ?? 0) > (counts[$1.id] ?? 0) }
        hiddenTags = hidden.sorted { $0.name < $1.name }
        subTagsMap = subs
        itemCounts = counts
    }
}
