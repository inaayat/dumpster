import SwiftUI

struct MasterDocCore: View {
    let tagId: String
    var tagDisplayName: String? = nil
    var mode: Mode = .panel
    var showSubTagSettings: Bool = false
    var onClose: (() -> Void)? = nil
    var onBack: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onDocUpdated: (() -> Void)? = nil
    var onItemIncorporated: ((String) -> Void)? = nil

    enum Mode { case panel, page }

    @State private var content = ""
    @State private var title = ""
    @State private var isSynthesizing = false
    @State private var isInserting = false
    @State private var isDragOver = false
    @State private var fontSize: CGFloat = 13
    @State private var synthesizedPreview: String?
    @State private var showEmptyDocPrompt = false
    @State private var pendingBullets: [String] = []
    @State private var pendingItemId: String?
    @State private var confirmDelete = false
    @State private var showSubTagSheet = false
    @StateObject private var editorHandle = RichMarkdownEditorHandle()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            toolbar
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

            editorWithDropZone
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
                    onItemIncorporated?(itemId)
                }
                pendingBullets = []
                pendingItemId = nil
                onDocUpdated?()
            }
            Button("Cancel", role: .cancel) { pendingBullets = []; pendingItemId = nil }
        } message: {
            Text("This doc has no content yet. Should AI create sections from these bullets, or just append them as a list?")
        }
        .confirmationDialog("Delete this document?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { onDelete?() }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showSubTagSheet) {
            subTagSettingsSheet
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        switch mode {
        case .panel:
            panelHeader
        case .page:
            pageHeader
        }
    }

    private var panelHeader: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                TextField("Title", text: $title)
                    .font(.inter(16, weight: .bold))
                    .textFieldStyle(.plain)
                    .onSubmit { saveDoc() }
                if let name = tagDisplayName {
                    Text("#\(name)")
                        .font(.inter(10, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
            Spacer()

            if showSubTagSettings {
                Button { showSubTagSheet = true } label: {
                    Image(systemName: "gearshape").font(.system(size: 12)).foregroundStyle(Theme.textMuted)
                }
                .buttonStyle(.plain)
                .help("Sub-tag settings")
            }

            synthesizeButton

            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundStyle(Theme.textMuted.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.cardBg)
    }

    private var pageHeader: some View {
        HStack(spacing: 10) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.textMuted)
                }
                .buttonStyle(.plain)
            }

            if let name = tagDisplayName {
                Image(systemName: "number").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.accent)
                Text(name).font(.inter(14, weight: .semibold)).foregroundStyle(Theme.accent)
            }

            TextField("Document title", text: $title)
                .textFieldStyle(.plain)
                .font(.inter(16, weight: .bold))
                .onChange(of: title) { saveDoc() }

            Spacer()

            if onDelete != nil {
                Button { confirmDelete = true } label: {
                    Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(Theme.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 2) {
            toolbarBtn(icon: "bold") { editorHandle.toggleBold() }
            toolbarBtn(icon: "italic") { editorHandle.toggleItalic() }
            toolbarBtn(icon: "list.bullet") { editorHandle.toggleBullet() }
            toolbarBtn(icon: "number") { editorHandle.toggleHeading() }
            Divider().frame(height: 14).padding(.horizontal, 4)
            toolbarBtn(icon: "textformat.size.smaller") { if fontSize > 10 { fontSize -= 1 } }
            Text("\(Int(fontSize))").font(.inter(9)).foregroundStyle(Theme.textMuted).frame(width: 16)
            toolbarBtn(icon: "textformat.size.larger") { if fontSize < 20 { fontSize += 1 } }

            if mode == .page {
                Divider().frame(height: 14).padding(.horizontal, 4)
                synthesizeButton
            }

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

    private var synthesizeButton: some View {
        Button { synthesize() } label: {
            HStack(spacing: 3) {
                if isSynthesizing { ProgressView().controlSize(.mini) }
                else { Image(systemName: "sparkles") }
                Text(isSynthesizing ? "..." : "Synthesize")
            }
            .font(.inter(10, weight: .semibold))
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.accent)
        .controlSize(.small)
        .disabled(isSynthesizing || content.isEmpty)
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

    // MARK: - Editor + Drop Zone

    private var editorWithDropZone: some View {
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

    // MARK: - Sub-tag Settings

    @ViewBuilder
    private var subTagSettingsSheet: some View {
        let tagRecord = try? Queries.getTag(id: tagId)
        let subTags = tagRecord.flatMap { try? Queries.getSubTags(parentTagId: $0.id) } ?? []
        VStack(alignment: .leading, spacing: 16) {
            Text("Sub-tag Settings").font(.inter(16, weight: .bold)).foregroundStyle(Theme.textPrimary)
            Text("Sub-tags of #\(tagDisplayName ?? tagRecord?.name ?? "")").font(.inter(12)).foregroundStyle(Theme.textMuted)

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
                            Button {
                                try? Queries.removeSubTag(parentTagId: tagId, childTagId: sub.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundStyle(Theme.textMuted)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Theme.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            Spacer()
            HStack {
                Spacer()
                Button("Done") { showSubTagSheet = false }
                    .font(.inter(12, weight: .semibold)).buttonStyle(.borderedProminent).tint(Theme.accent)
            }
        }
        .padding(24)
        .frame(width: 340, height: 320)
    }

    // MARK: - Logic

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
                        onItemIncorporated?(itemId)
                    }
                    pendingBullets = []
                    pendingItemId = nil
                    onDocUpdated?()
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
                var bulletsStr = content
                if let name = tagDisplayName {
                    let allDumps = (try? Queries.getAllDumps()) ?? []
                    var bulletTexts: [String] = []
                    for dump in allDumps {
                        let bullets = DumpBullet.parse(from: dump.content)
                        for bullet in bullets where bullet.tags.contains(name.lowercased()) {
                            bulletTexts.append(bullet.text)
                        }
                    }
                    if !bulletTexts.isEmpty { bulletsStr = bulletTexts.joined(separator: "\n") }
                }
                let result = try await AIService.synthesizeMasterDoc(existingContent: content, bullets: bulletsStr)
                await MainActor.run { synthesizedPreview = result; isSynthesizing = false }
            } catch {
                await MainActor.run { isSynthesizing = false }
            }
        }
    }

    private func saveDoc() {
        guard !tagId.isEmpty else { return }
        let docTitle = title.isEmpty ? (tagDisplayName ?? "Untitled").replacingOccurrences(of: "-", with: " ").capitalized : title
        try? Queries.upsertMasterDoc(tagId: tagId, content: content, title: docTitle)
    }

    private func loadDoc() {
        let doc = try? Queries.getMasterDoc(tagId: tagId)
        let tag = try? Queries.getTag(id: tagId)
        content = doc?.content ?? ""
        title = doc?.title ?? (tagDisplayName ?? tag?.name ?? "Untitled").replacingOccurrences(of: "-", with: " ").capitalized
        if doc == nil {
            try? Queries.upsertMasterDoc(tagId: tagId, content: "", title: title)
        }
    }
}
