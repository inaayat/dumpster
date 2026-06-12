import SwiftUI

struct ItemsView: View {
    @Bindable var appState: AppState
    @State private var items: [Item] = []
    @State private var itemTags: [String: [Tag]] = [:]
    @State private var selectedCategory: Category? = .action
    @State private var showCompleted = false
    @State private var searchQuery = ""
    @State private var counts: [String: Int] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Items")
                    .font(.inter(24, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Toggle("Completed", isOn: $showCompleted)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .font(.inter(11))
                    .onChange(of: showCompleted) { _, _ in reload() }
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // Filter tabs
            HStack {
                FilterTabs(selected: $selectedCategory, counts: counts)
                    .onChange(of: selectedCategory) { _, _ in reload() }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 12)

            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textMuted)
                TextField("Search items...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.inter(12))
                    .onChange(of: searchQuery) { _, _ in reload() }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.cardAlt, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .padding(.horizontal, 28)
            .padding(.bottom, 16)

            // Items list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.itemSpacing) {
                    ForEach(sortedItems) { item in
                        ItemCard(
                            item: item,
                            tags: itemTags[item.id] ?? [],
                            onTap: { appState.openDetail(itemId: item.id) },
                            onComplete: {
                                try? Queries.completeItem(id: item.id)
                                appState.refreshCounts()
                                reload()
                            }
                        )
                    }

                    if sortedItems.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.system(size: 28))
                                .foregroundStyle(Theme.textMuted.opacity(0.4))
                            Text("No items yet")
                                .font(.inter(13))
                                .foregroundStyle(Theme.textMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
        }
        .background(Theme.canvas)
        .onAppear { reload() }
    }

    private var sortedItems: [Item] {
        items.sorted { a, b in
            if a.priority.sortOrder != b.priority.sortOrder {
                return a.priority.sortOrder < b.priority.sortOrder
            }
            if let aDate = a.dueDate, let bDate = b.dueDate {
                return aDate < bDate
            }
            if a.dueDate != nil { return true }
            if b.dueDate != nil { return false }
            return a.createdAt > b.createdAt
        }
    }

    private func reload() {
        if !searchQuery.isEmpty {
            items = (try? Queries.searchItems(query: searchQuery)) ?? []
        } else if showCompleted {
            items = (try? Queries.getItems(category: selectedCategory, done: true)) ?? []
        } else {
            items = (try? Queries.getItems(category: selectedCategory, done: false)) ?? []
        }

        var tagMap: [String: [Tag]] = [:]
        for item in items {
            tagMap[item.id] = (try? Queries.getTagsForItem(itemId: item.id)) ?? []
        }
        itemTags = tagMap

        counts = (try? Queries.getCategoryCounts()) ?? [:]
    }
}
