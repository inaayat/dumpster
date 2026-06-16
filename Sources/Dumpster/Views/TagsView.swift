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
        let hasChildren = !(subTagsMap[tag.id]?.isEmpty ?? true)
        let isExpanded = expandedTags.contains(tag.id)
        let count = itemCounts[tag.id] ?? 0

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                if hasChildren {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isExpanded { expandedTags.remove(tag.id) } else { expandedTags.insert(tag.id) }
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Theme.textMuted)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: 16, height: 16)
                }

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
                    }
                }
            }

            if isExpanded, let children = subTagsMap[tag.id] {
                VStack(alignment: .leading, spacing: 4) {
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
                                Text("\(childCount)")
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
                .padding(.top, 4)
            }
        }
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

    private func reload() {
        let all = (try? Queries.getTopLevelTags()) ?? []
        var subs: [String: [Tag]] = [:]
        var counts: [String: Int] = [:]
        for tag in all {
            subs[tag.id] = (try? Queries.getSubTags(parentTagId: tag.id)) ?? []
            counts[tag.id] = (try? Queries.getItemCountForTag(tagId: tag.id)) ?? 0
            for child in subs[tag.id] ?? [] {
                counts[child.id] = (try? Queries.getItemCountForTag(tagId: child.id)) ?? 0
            }
        }
        // Hide tags with 0 items (and no children with items), sort by descending item count
        topLevelTags = all.filter { tag in
            let ownCount = counts[tag.id] ?? 0
            let childCount = (subs[tag.id] ?? []).reduce(0) { $0 + (counts[$1.id] ?? 0) }
            return ownCount > 0 || childCount > 0
        }.sorted { (counts[$0.id] ?? 0) > (counts[$1.id] ?? 0) }
        subTagsMap = subs
        itemCounts = counts
    }
}
