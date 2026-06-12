import SwiftUI

struct TagDetailView: View {
    @Bindable var appState: AppState
    let tagId: String

    @State private var tag: Tag?
    @State private var items: [Item] = []
    @State private var hasDoc: Bool = false
    @State private var showMasterDocPanel = false

    var body: some View {
        HStack(spacing: 0) {
            itemsList
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showMasterDocPanel {
                Divider()
                TagMasterDocPanel(
                    tagId: tagId,
                    onClose: { withAnimation { showMasterDocPanel = false } },
                    onItemIncorporated: { reload() }
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

                    let sorted = items.sorted { a, b in
                        if a.incorporatedIntoDoc != b.incorporatedIntoDoc {
                            return !a.incorporatedIntoDoc
                        }
                        return a.createdAt > b.createdAt
                    }

                    LazyVStack(alignment: .leading, spacing: Theme.itemSpacing) {
                        ForEach(sorted) { item in
                            draggableItemRow(item)
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
        .draggable("itemdrag:\(item.id):\(item.text)")
    }

    private func reload() {
        tag = try? Queries.getTag(id: tagId)
        items = (try? Queries.getItemsForTag(tagId: tagId, done: false)) ?? []
        hasDoc = (try? Queries.getMasterDoc(tagId: tagId)) != nil
    }
}

// MARK: - Tag Master Doc Panel (right panel for TagDetailView)

struct TagMasterDocPanel: View {
    let tagId: String
    var onClose: () -> Void
    var onItemIncorporated: () -> Void

    @State private var content = ""
    @State private var title = ""
    @State private var isInserting = false
    @State private var isDragOver = false
    @State private var fontSize: CGFloat = 13
    @State private var isSynthesizing = false
    @State private var synthesizedPreview: String?
    @State private var showEmptyDocPrompt = false
    @State private var pendingBullets: [String] = []
    @State private var pendingItemId: String?
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
                    Text("AI is placing into the doc...")
                        .font(.inter(11)).foregroundStyle(Theme.textMuted)
                }
                .padding(12)
                Divider()
            }

            if let preview = synthesizedPreview {
                synthesizePreviewSection(preview)
                Divider()
            }

            ZStack {
                RichMarkdownEditorWithHandle(markdown: $content, handle: editorHandle, fontSize: fontSize)
                    .onChange(of: content) { saveDoc() }
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
                handleDrop(dropped)
                return true
            } isTargeted: { targeted in
                isDragOver = targeted
            }
        }
        .background(Theme.canvas)
        .onAppear { loadDoc() }
        .alert("Empty Document", isPresented: $showEmptyDocPrompt) {
            Button("Create Sections") {
                aiInsertBullets(pendingBullets, createStructure: true, itemId: pendingItemId)
            }
            Button("Just Append") {
                let joined = pendingBullets.map { "• \($0)" }.joined(separator: "\n")
                content = joined
                saveDoc()
                if let itemId = pendingItemId {
                    try? Queries.markItemIncorporated(id: itemId)
                    onItemIncorporated()
                }
                pendingBullets = []
                pendingItemId = nil
            }
            Button("Cancel", role: .cancel) { pendingBullets = []; pendingItemId = nil }
        } message: {
            Text("This doc has no content yet. Should AI create topic sections from this, or just append as a list?")
        }
    }

    private var panelHeader: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                TextField("Title", text: $title)
                    .font(.inter(16, weight: .bold))
                    .textFieldStyle(.plain)
                    .onSubmit { saveDoc() }
            }
            Spacer()

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

    private var panelToolbar: some View {
        HStack(spacing: 2) {
            toolbarBtn(icon: "bold") { editorHandle.toggleBold() }
            toolbarBtn(icon: "italic") { /* italic toggle placeholder */ }
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

    // MARK: - Drop Handling

    private func handleDrop(_ dropped: [String]) {
        var itemId: String?
        var bullets: [String] = []

        for item in dropped {
            if item.hasPrefix("itemdrag:") {
                let parts = item.dropFirst("itemdrag:".count).components(separatedBy: ":")
                if parts.count >= 2 {
                    itemId = parts[0]
                    let text = parts.dropFirst().joined(separator: ":")
                    bullets.append(text)
                }
            } else {
                bullets.append(contentsOf: item.components(separatedBy: "\n").filter { !$0.isEmpty })
            }
        }

        guard !bullets.isEmpty else { return }

        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            pendingBullets = bullets
            pendingItemId = itemId
            showEmptyDocPrompt = true
        } else {
            aiInsertBullets(bullets, createStructure: false, itemId: itemId)
        }
    }

    // MARK: - AI

    private func aiInsertBullets(_ bullets: [String], createStructure: Bool, itemId: String?) {
        isInserting = true
        let existing = createStructure ? "" : content
        Task {
            do {
                let result = try await AIService.insertBulletsIntoDoc(existingContent: existing, bullets: bullets)
                await MainActor.run {
                    content = result
                    saveDoc()
                    isInserting = false
                    if let itemId {
                        try? Queries.markItemIncorporated(id: itemId)
                        onItemIncorporated()
                    }
                    pendingBullets = []
                    pendingItemId = nil
                }
            } catch {
                await MainActor.run { isInserting = false; pendingBullets = []; pendingItemId = nil }
            }
        }
    }

    private func synthesize() {
        isSynthesizing = true
        Task {
            do {
                let result = try await AIService.synthesizeMasterDoc(existingContent: content, bullets: content)
                await MainActor.run { synthesizedPreview = result; isSynthesizing = false }
            } catch {
                await MainActor.run { isSynthesizing = false }
            }
        }
    }

    private func saveDoc() {
        guard !tagId.isEmpty else { return }
        try? Queries.upsertMasterDoc(tagId: tagId, content: content, title: title)
    }

    private func loadDoc() {
        let doc = try? Queries.getMasterDoc(tagId: tagId)
        let tag = try? Queries.getTag(id: tagId)
        content = doc?.content ?? ""
        title = doc?.title ?? tag?.name.replacingOccurrences(of: "-", with: " ").capitalized ?? "Untitled"
    }
}
