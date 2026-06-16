import SwiftUI

struct TagDetailView: View {
    @Bindable var appState: AppState
    let tagId: String

    @State private var tag: Tag?
    @State private var items: [Item] = []
    @State private var hasDoc: Bool = false
    @State private var showMasterDocPanel = false
    @State private var backlogSectionCollapsed = true

    var body: some View {
        HStack(spacing: 0) {
            itemsList
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showMasterDocPanel {
                Divider()
                MasterDocCore(
                    tagId: tagId,
                    tagDisplayName: tag?.name,
                    mode: .panel,
                    onClose: { withAnimation { showMasterDocPanel = false } },
                    onItemIncorporated: { _ in reload() }
                )
                .frame(minWidth: 300, maxWidth: .infinity)
            }
        }
        .background(Theme.canvas)
        .onAppear { reload() }
    }

    private var itemsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                if let tag {
                    HStack {
                        Button { appState.navigate(to: .tags) } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.textMuted)
                        }
                        .buttonStyle(.plain)

                        Image(systemName: "number")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.accent)
                        Text(tag.name)
                            .font(.inter(22, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("\(items.count) items")
                            .font(.inter(11))
                            .foregroundStyle(Theme.textMuted)
                        Spacer()

                        let activeCount = items.filter { $0.priority != .backlog }.count
                        if activeCount > 0 {
                            Button {
                                for var item in items where item.priority != .backlog {
                                    item.priority = .backlog
                                    try? Queries.updateItem(item)
                                }
                                appState.refreshCounts()
                                backlogSectionCollapsed = false
                                reload()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "archivebox")
                                        .font(.system(size: 9, weight: .bold))
                                    Text("Backlog All")
                                        .font(.inter(11, weight: .medium))
                                }
                                .foregroundStyle(Theme.textMuted)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Theme.cardAlt, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        if hasDoc {
                            Button {
                                withAnimation { showMasterDocPanel.toggle() }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.text.fill")
                                        .font(.system(size: 10))
                                    Text("Master Doc")
                                        .font(.inter(11, weight: .medium))
                                }
                                .foregroundStyle(showMasterDocPanel ? .white : Theme.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(showMasterDocPanel ? Theme.accent : Theme.accent.opacity(0.1), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                let title = tag.name.replacingOccurrences(of: "-", with: " ").capitalized
                                try? Queries.upsertMasterDoc(tagId: tagId, content: "", title: title)
                                hasDoc = true
                                withAnimation { showMasterDocPanel = true }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 9, weight: .bold))
                                    Text("Create Doc")
                                        .font(.inter(11, weight: .medium))
                                }
                                .foregroundStyle(Theme.textMuted)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Theme.cardAlt, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    let activeItems = items.filter { $0.priority != .backlog }.sorted { a, b in
                        if a.incorporatedIntoDoc != b.incorporatedIntoDoc { return !a.incorporatedIntoDoc }
                        return a.createdAt > b.createdAt
                    }
                    let backlogItems = items.filter { $0.priority == .backlog }.sorted { $0.createdAt > $1.createdAt }

                    LazyVStack(alignment: .leading, spacing: Theme.itemSpacing) {
                        ForEach(activeItems) { item in
                            draggableItemRow(item)
                        }
                    }

                    if !backlogItems.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    backlogSectionCollapsed.toggle()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: backlogSectionCollapsed ? "chevron.right" : "chevron.down")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(Theme.textMuted)
                                    Image(systemName: "archivebox")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(Theme.textMuted)
                                    Text("Backlogged")
                                        .font(.inter(12, weight: .semibold))
                                        .foregroundStyle(Theme.textMuted)
                                    Text("\(backlogItems.count)")
                                        .font(.inter(9))
                                        .foregroundStyle(Theme.textMuted)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 8)

                            if !backlogSectionCollapsed {
                                LazyVStack(alignment: .leading, spacing: Theme.itemSpacing) {
                                    ForEach(backlogItems) { item in
                                        draggableItemRow(item)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(28)
        }
    }

    @ViewBuilder
    private func draggableItemRow(_ item: Item) -> some View {
        HStack(spacing: 10) {
            if item.incorporatedIntoDoc {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.successColor.opacity(0.6))
            } else if item.category == .action {
                Button {
                    try? Queries.completeItem(id: item.id)
                    appState.refreshCounts()
                    reload()
                } label: {
                    Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundStyle(item.done ? Theme.successColor : Theme.textMuted.opacity(0.4))
                }
                .buttonStyle(.plain)
            } else {
                CategoryBadge(category: item.category)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if item.incorporatedIntoDoc {
                        Text("in doc")
                            .font(.inter(8, weight: .bold))
                            .foregroundStyle(Theme.successColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Theme.successColor.opacity(0.1), in: Capsule())
                    }
                    Text(item.createdAt.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.inter(10, weight: .medium))
                        .foregroundStyle(Theme.textMuted)
                }
                Text(item.text)
                    .font(.inter(13))
                    .foregroundStyle(item.incorporatedIntoDoc ? Theme.textMuted : Theme.textPrimary)
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            if !item.incorporatedIntoDoc && showMasterDocPanel {
                Image(systemName: "arrow.right.doc")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.accent.opacity(0.5))
            }
        }
        .padding(Theme.cardPadding)
        .background(
            item.incorporatedIntoDoc ? Theme.successColor.opacity(0.04) : Theme.cardBg,
            in: RoundedRectangle(cornerRadius: Theme.cornerRadius)
        )
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(
            item.incorporatedIntoDoc ? Theme.successColor.opacity(0.2) : Theme.cardBorder, lineWidth: 1
        ))
        .contentShape(Rectangle())
        .onTapGesture { appState.openDetail(itemId: item.id) }
        .draggable("itemdrag:\(item.id):\(item.text)") {
            HStack(spacing: 6) {
                Image(systemName: "arrow.right.doc")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.accent)
                Text(item.text)
                    .font(.inter(11))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
            }
            .padding(8)
            .frame(maxWidth: 280, alignment: .leading)
            .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
    }

    private func reload() {
        tag = try? Queries.getTag(id: tagId)
        items = (try? Queries.getItemsForTag(tagId: tagId, done: false)) ?? []
        hasDoc = (try? Queries.getMasterDoc(tagId: tagId)) != nil
    }
}

