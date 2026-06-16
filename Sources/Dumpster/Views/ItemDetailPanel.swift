import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(subviews: subviews, width: proposal.width ?? 0).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, width: bounds.width)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
        }
    }
    private func layout(subviews: Subviews, width: CGFloat) -> (size: CGSize, frames: [CGRect]) {
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x + size.width)
            x += size.width + spacing
        }
        return (CGSize(width: maxX, height: y + rowHeight), frames)
    }
}

struct ItemDetailPanel: View {
    @Bindable var appState: AppState
    let itemId: String

    @State private var item: Item?
    @State private var tags: [Tag] = []
    @State private var linkedItems: [Item] = []
    @State private var notesText = ""
    @State private var notesDirty = false
    @State private var confirmDelete = false
    @State private var addingTag = false
    @State private var newTagText = ""
    @State private var allTags: [Tag] = []

    var body: some View {
        if let item {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerBar(item: item)
                    metaRow(item: item)
                    textContent(item: item)
                    tagsRow
                    urlRow(item: item)
                    notesSection
                    resourcesSection
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.categoryTint(item.category).opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius + 4))
            .onAppear { loadData() }
            .onChange(of: itemId) { _, _ in loadData() }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear { loadData() }
        }
    }

    private func headerBar(item: Item) -> some View {
        HStack(spacing: 8) {
            Button {
                withAnimation { appState.closeDetail() }
            } label: {
                Image(systemName: "xmark")
                    .font(.inter(11, weight: .bold))
                    .foregroundStyle(Theme.textMuted)
                    .frame(width: 26, height: 26)
                    .background(Theme.cardBg.opacity(0.8), in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            if !item.done {
                Button {
                    try? Queries.completeItem(id: item.id)
                    loadData()
                    appState.refreshCounts()
                } label: {
                    Label("Complete", systemImage: "checkmark")
                        .font(.inter(12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.successColor)
                .controlSize(.small)
            }

            Button("Edit") {
                appState.editingItem = item
                appState.showEditSheet = true
            }
            .font(.inter(12, weight: .medium))
            .controlSize(.small)

            Button(confirmDelete ? "Confirm?" : "Delete") {
                if confirmDelete {
                    try? Queries.deleteItem(id: item.id)
                    withAnimation { appState.closeDetail() }
                    appState.refreshCounts()
                } else {
                    confirmDelete = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { confirmDelete = false }
                }
            }
            .font(.inter(12, weight: .medium))
            .foregroundStyle(confirmDelete ? Theme.brainstormColor : Theme.textMuted)
            .controlSize(.small)
        }
        .padding(.top, 18)
    }

    private func metaRow(item: Item) -> some View {
        HStack(spacing: 8) {
            Text(item.category.label.uppercased())
                .font(.inter(10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Theme.categoryColor(item.category), in: Capsule())
            if item.done {
                Text("Completed").font(.inter(11, weight: .semibold)).foregroundStyle(Theme.successColor)
            }
            Text(item.createdAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                .font(.inter(11)).foregroundStyle(Theme.textMuted)
            Spacer()
            Menu {
                ForEach(Priority.allCases, id: \.rawValue) { p in
                    Button {
                        var updated = item
                        updated.priority = p
                        try? Queries.updateItem(updated)
                        loadData()
                        appState.refreshCounts()
                    } label: {
                        Label(p.rawValue.capitalized, systemImage: priorityIcon(p))
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: priorityIcon(item.priority))
                        .font(.system(size: 9, weight: .bold))
                    Text(item.priority.rawValue.capitalized)
                        .font(.inter(10, weight: .medium))
                }
                .foregroundStyle(priorityColor(item.priority))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(priorityColor(item.priority).opacity(0.12), in: Capsule())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private func priorityIcon(_ p: Priority) -> String {
        switch p {
        case .high: return "arrow.up.circle.fill"
        case .medium: return "minus.circle"
        case .low: return "arrow.down.circle"
        case .backlog: return "archivebox"
        }
    }

    private func priorityColor(_ p: Priority) -> Color {
        switch p {
        case .high: return Theme.brainstormColor
        case .medium: return Theme.textMuted
        case .low: return Theme.textMuted.opacity(0.6)
        case .backlog: return Theme.textMuted.opacity(0.5)
        }
    }

    private func textContent(item: Item) -> some View {
        Text(item.text).font(.inter(15)).foregroundStyle(Theme.textPrimary).textSelection(.enabled)
    }

    private var tagsRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            FlowLayout(spacing: 4) {
                ForEach(tags) { tag in
                    HStack(spacing: 3) {
                        Text("#\(tag.name)")
                            .font(.inter(10, weight: .medium))
                            .foregroundStyle(Theme.accent)
                        Button {
                            try? Queries.untagItem(itemId: itemId, tagId: tag.id)
                            loadData()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(Theme.accent.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.accent.opacity(0.1), in: Capsule())
                    .contextMenu {
                        Button {
                            openMasterDoc(tagId: tag.id)
                        } label: {
                            Label("Open Master Doc", systemImage: "doc.text.fill")
                        }
                    }
                }

                if addingTag {
                    HStack(spacing: 4) {
                        Text("#").font(.inter(10)).foregroundStyle(Theme.textMuted)
                        TextField("tag", text: $newTagText)
                            .font(.inter(10))
                            .textFieldStyle(.plain)
                            .frame(width: 80)
                            .onSubmit { commitNewTag() }
                        Button {
                            commitNewTag()
                        } label: {
                            Image(systemName: "return")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.plain)
                        Button {
                            addingTag = false
                            newTagText = ""
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Theme.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.cardBg, in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.3), lineWidth: 1))
                } else {
                    Button {
                        addingTag = true
                        newTagText = ""
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 20, height: 20)
                            .background(Theme.accent.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            if addingTag && !newTagText.isEmpty {
                let currentTagIds = Set(tags.map(\.id))
                let suggestions = allTags.filter {
                    $0.name.localizedCaseInsensitiveContains(newTagText) &&
                    !currentTagIds.contains($0.id)
                }.prefix(4)
                if !suggestions.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(suggestions)) { tag in
                            Button(tag.name) {
                                try? Queries.tagItem(itemId: itemId, tagId: tag.id)
                                addingTag = false
                                newTagText = ""
                                loadData()
                            }
                            .font(.inter(9))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.accent.opacity(0.08), in: Capsule())
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func commitNewTag() {
        let name = newTagText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !name.isEmpty else { addingTag = false; return }
        if let tag = try? Queries.getOrCreateTag(name: name) {
            try? Queries.tagItem(itemId: itemId, tagId: tag.id)
        }
        addingTag = false
        newTagText = ""
        loadData()
    }

    @ViewBuilder
    private func urlRow(item: Item) -> some View {
        if let urlString = item.url, let url = URL(string: urlString) {
            SwiftUI.Link(destination: url) {
                HStack(spacing: 6) {
                    Image(systemName: "link").font(.inter(11)).foregroundStyle(Theme.resourceColor)
                    Text(url.host?.replacingOccurrences(of: "www.", with: "") ?? urlString)
                        .font(.inter(13, weight: .medium)).foregroundStyle(Theme.resourceColor)
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().padding(.top, 4)
            Text("NOTES").font(.inter(10, weight: .bold)).foregroundStyle(Theme.textMuted)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $notesText)
                    .font(.inter(13))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 200)
                    .padding(6)
                    .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                    .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.border, lineWidth: 1))
                    .onChange(of: notesText) { _, _ in notesDirty = true }
                if notesText.isEmpty {
                    Text("Add notes...")
                        .font(.inter(13)).foregroundStyle(Theme.textMuted)
                        .padding(.horizontal, 10).padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
            }

            if notesDirty {
                HStack {
                    Spacer()
                    Button("Save") { saveNotes() }
                        .font(.inter(11, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var resourcesSection: some View {
        if !linkedItems.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("LINKED").font(.inter(10, weight: .bold)).foregroundStyle(Theme.textMuted)
                ForEach(linkedItems) { linked in
                    HStack(spacing: 8) {
                        CategoryBadge(category: linked.category)
                        Text(linked.text).font(.inter(11)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func saveNotes() {
        guard var current = item else { return }
        current.notes = notesText.trimmingCharacters(in: .whitespaces)
        try? Queries.updateItem(current)
        notesDirty = false
        loadData()
    }

    private func openMasterDoc(tagId: String) {
        withAnimation { appState.openMasterDocPanel(tagId: tagId) }
    }

    private func loadData() {
        item = try? Queries.getItem(id: itemId)
        notesText = item?.notes ?? ""
        notesDirty = false
        tags = (try? Queries.getTagsForItem(itemId: itemId)) ?? []
        linkedItems = (try? Queries.getLinkedItems(itemId: itemId)) ?? []
        allTags = (try? Queries.getAllTags()) ?? []
    }
}
