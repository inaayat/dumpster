import SwiftUI

struct ItemDetailPanel: View {
    @Bindable var appState: AppState
    let itemId: String

    @State private var item: Item?
    @State private var tags: [Tag] = []
    @State private var linkedItems: [Item] = []
    @State private var notesText = ""
    @State private var notesDirty = false
    @State private var confirmDelete = false

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
        }
    }

    private func textContent(item: Item) -> some View {
        Text(item.text).font(.inter(15)).foregroundStyle(Theme.textPrimary).textSelection(.enabled)
    }

    @ViewBuilder
    private var tagsRow: some View {
        if !tags.isEmpty {
            HStack(spacing: 4) {
                ForEach(tags) { tag in
                    Text("#\(tag.name)")
                        .font(.inter(10, weight: .medium))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.accent.opacity(0.1), in: Capsule())
                }
            }
        }
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

    private func loadData() {
        item = try? Queries.getItem(id: itemId)
        notesText = item?.notes ?? ""
        notesDirty = false
        tags = (try? Queries.getTagsForItem(itemId: itemId)) ?? []
        linkedItems = (try? Queries.getLinkedItems(itemId: itemId)) ?? []
    }
}
