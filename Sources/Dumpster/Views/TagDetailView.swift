import SwiftUI

struct TagDetailView: View {
    @Bindable var appState: AppState
    let tagId: String

    @State private var tag: Tag?
    @State private var items: [Item] = []
    @State private var hasDoc: Bool = false

    var body: some View {
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
                                appState.navigate(to: .masterDoc(tagId))
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.text.fill")
                                        .font(.system(size: 10))
                                    Text("Master Doc")
                                        .font(.inter(11, weight: .medium))
                                }
                                .foregroundStyle(Theme.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Theme.accent.opacity(0.1), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                let title = tag.name.replacingOccurrences(of: "-", with: " ").capitalized
                                try? Queries.upsertMasterDoc(tagId: tagId, content: "", title: title)
                                hasDoc = true
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

                    LazyVStack(alignment: .leading, spacing: Theme.itemSpacing) {
                        ForEach(items) { item in
                            ItemCard(
                                item: item,
                                onTap: { appState.openDetail(itemId: item.id) },
                                onComplete: {
                                    try? Queries.completeItem(id: item.id)
                                    appState.refreshCounts()
                                    reload()
                                }
                            )
                        }
                    }
                }
            }
            .padding(28)
        }
        .background(Theme.canvas)
        .onAppear { reload() }
    }

    private func reload() {
        tag = try? Queries.getTag(id: tagId)
        items = (try? Queries.getItemsForTag(tagId: tagId, done: false)) ?? []
        hasDoc = (try? Queries.getMasterDoc(tagId: tagId)) != nil
    }
}
