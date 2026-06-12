import SwiftUI

struct MasterDocEditor: View {
    @Bindable var appState: AppState
    let tagId: String

    @State private var tag: Tag?
    @State private var doc: MasterDoc?
    @State private var content = ""
    @State private var title = ""
    @State private var isSynthesizing = false
    @State private var isInserting = false
    @State private var synthesizedPreview: String?
    @State private var fontSize: CGFloat = 13
    @State private var isDragOver = false
    @State private var confirmDelete = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            toolbar
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

            ZStack {
                TextEditor(text: $content)
                    .font(.inter(fontSize))
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .onChange(of: content) { saveDoc() }

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
                aiInsertBullets(bullets)
                return true
            } isTargeted: { targeted in
                isDragOver = targeted
            }
        }
        .background(Theme.canvas)
        .onAppear { loadDoc() }
        .confirmationDialog("Delete this document?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                if let doc { try? Queries.deleteMasterDoc(id: doc.id) }
                appState.navigate(to: .docs)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var headerBar: some View {
        HStack(spacing: 10) {
            Button { appState.navigate(to: .docs) } label: {
                Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.textMuted)
            }
            .buttonStyle(.plain)

            if let tag {
                Image(systemName: "number").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.accent)
                Text(tag.name).font(.inter(14, weight: .semibold)).foregroundStyle(Theme.accent)
            }

            TextField("Document title", text: $title)
                .textFieldStyle(.plain)
                .font(.inter(16, weight: .bold))
                .onChange(of: title) { saveDoc() }

            Spacer()

            Button { confirmDelete = true } label: {
                Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(Theme.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button { synthesize() } label: {
                HStack(spacing: 4) {
                    if isSynthesizing { ProgressView().controlSize(.mini) }
                    else { Image(systemName: "sparkles").font(.system(size: 10)) }
                    Text("AI Synthesize").font(.inter(10, weight: .medium))
                }
                .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
            .disabled(isSynthesizing || content.isEmpty)

            Spacer()

            HStack(spacing: 4) {
                Button { fontSize = max(10, fontSize - 1) } label: {
                    Image(systemName: "textformat.size.smaller").font(.system(size: 10))
                }
                .buttonStyle(.plain)
                Text("\(Int(fontSize))").font(.inter(9)).foregroundStyle(Theme.textMuted)
                Button { fontSize = min(20, fontSize + 1) } label: {
                    Image(systemName: "textformat.size.larger").font(.system(size: 10))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(Theme.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func synthesizePreviewSection(_ preview: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AI Synthesis Preview").font(.inter(11, weight: .semibold)).foregroundStyle(Theme.accent)
                Spacer()
                Button("Accept") {
                    content = preview
                    synthesizedPreview = nil
                    saveDoc()
                }
                .font(.inter(10, weight: .semibold))
                .buttonStyle(.borderedProminent).tint(Theme.successColor).controlSize(.mini)
                Button("Dismiss") { synthesizedPreview = nil }
                    .font(.inter(10)).foregroundStyle(Theme.textMuted)
            }
            Text(preview).font(.inter(11)).foregroundStyle(Theme.textSecondary).lineLimit(10)
        }
        .padding(12)
        .background(Theme.accent.opacity(0.05))
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

    private func aiInsertBullets(_ bullets: [String]) {
        isInserting = true
        Task {
            do {
                let result = try await AIService.insertBulletsIntoDoc(existingContent: content, bullets: bullets)
                await MainActor.run { content = result; saveDoc(); isInserting = false }
            } catch {
                await MainActor.run { isInserting = false }
            }
        }
    }

    private func saveDoc() {
        guard !tagId.isEmpty else { return }
        try? Queries.upsertMasterDoc(tagId: tagId, content: content, title: title)
    }

    private func loadDoc() {
        tag = try? Queries.getTag(id: tagId)
        doc = try? Queries.getMasterDoc(tagId: tagId)
        content = doc?.content ?? ""
        title = doc?.title ?? tag?.name.replacingOccurrences(of: "-", with: " ").capitalized ?? "Untitled"
    }
}
