import SwiftUI

struct ItemsView: View {
    @Bindable var appState: AppState
    @State private var items: [Item] = []
    @State private var itemTags: [String: [Tag]] = [:]
    @State private var selectedCategory: Category? = {
        if let raw = UserDefaults.standard.string(forKey: "items.category") {
            return Category(rawValue: raw)
        }
        return .action
    }()
    @State private var showCompleted = UserDefaults.standard.bool(forKey: "items.showCompleted")
    @State private var groupByTag = UserDefaults.standard.bool(forKey: "items.groupByTag")
    @State private var highPrioOnly = UserDefaults.standard.bool(forKey: "items.highPrioOnly")
    @State private var searchQuery = ""
    @State private var counts: [String: Int] = [:]
    @State private var collapsedTags: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Items")
                    .font(.inter(24, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Toggle("High prio", isOn: $highPrioOnly)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .font(.inter(11))
                    .onChange(of: highPrioOnly) { _, v in UserDefaults.standard.set(v, forKey: "items.highPrioOnly"); reload() }

                Toggle("By tag", isOn: $groupByTag)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .font(.inter(11))
                    .onChange(of: groupByTag) { _, v in UserDefaults.standard.set(v, forKey: "items.groupByTag") }

                if groupByTag {
                    let allGroupIds = Set(groupItemsByTag(excludeHighPrio: true).map(\.id))
                    let allCollapsed = !allGroupIds.isEmpty && allGroupIds.isSubset(of: collapsedTags)

                    if allCollapsed {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { collapsedTags.removeAll() }
                        } label: {
                            Text("Expand All")
                                .font(.inter(10, weight: .medium))
                                .foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { collapsedTags = allGroupIds }
                        } label: {
                            Text("Collapse All")
                                .font(.inter(10, weight: .medium))
                                .foregroundStyle(Theme.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Toggle("Done", isOn: $showCompleted)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .font(.inter(11))
                    .onChange(of: showCompleted) { _, v in UserDefaults.standard.set(v, forKey: "items.showCompleted"); reload() }
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // Filter tabs
            HStack {
                FilterTabs(selected: $selectedCategory, counts: counts)
                    .onChange(of: selectedCategory) { _, v in
                        UserDefaults.standard.set(v?.rawValue ?? "", forKey: "items.category")
                        reload()
                    }
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
                    if groupByTag {
                        groupedByTagContent
                    } else {
                        flatContent
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
        }
        .background(Theme.canvas)
        .onAppear { reload() }
        .onChange(of: appState.showEditSheet) { _, showing in
            if !showing { reload() }
        }
    }

    @ViewBuilder
    private var flatContent: some View {
        if !newItems.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkle").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.accent)
                    Text("New").font(.inter(12, weight: .semibold)).foregroundStyle(Theme.accent)
                    Text("\(newItems.count)").font(.inter(9)).foregroundStyle(Theme.textMuted)
                }
                ForEach(newItems) { item in
                    ItemCard(item: item, tags: itemTags[item.id] ?? [],
                        onTap: { appState.openDetail(itemId: item.id) },
                        onComplete: { try? Queries.completeItem(id: item.id); appState.refreshCounts(); reload() },
                        onDateChanged: { reload() })
                }
            }
        }
        ForEach(sortedItems) { item in
            ItemCard(
                item: item,
                tags: itemTags[item.id] ?? [],
                onTap: { appState.openDetail(itemId: item.id) },
                onComplete: {
                    try? Queries.completeItem(id: item.id)
                    appState.refreshCounts()
                    reload()
                },
                onDateChanged: { reload() }
            )
        }
        if sortedItems.isEmpty && newItems.isEmpty { emptyState }
    }

    @ViewBuilder
    private var groupedByTagContent: some View {
        // High-prio items always at top, regardless of tag
        let highPrioItems = sortedItems.filter { $0.priority == .high }
        if !highPrioItems.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.brainstormColor)
                    Text("High Priority")
                        .font(.inter(12, weight: .semibold))
                        .foregroundStyle(Theme.brainstormColor)
                    Text("\(highPrioItems.count)")
                        .font(.inter(9))
                        .foregroundStyle(Theme.textMuted)
                }
                .padding(.top, 4)

                ForEach(highPrioItems) { item in
                    ItemCard(
                        item: item,
                        tags: itemTags[item.id] ?? [],
                        onTap: { appState.openDetail(itemId: item.id) },
                        onComplete: {
                            try? Queries.completeItem(id: item.id)
                            appState.refreshCounts()
                            reload()
                        },
                        onDateChanged: { reload() }
                    )
                }
            }
        }

        // Remaining items grouped by tag
        let grouped = groupItemsByTag(excludeHighPrio: true)
        ForEach(grouped) { group in
            let isCollapsed = collapsedTags.contains(group.id)
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isCollapsed { collapsedTags.remove(group.id) }
                        else { collapsedTags.insert(group.id) }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Theme.textMuted)
                        if let tag = group.tag {
                            Image(systemName: "number")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Theme.accent)
                            Text(tag.name)
                                .font(.inter(12, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                        } else {
                            Text("Untagged")
                                .font(.inter(12, weight: .semibold))
                                .foregroundStyle(Theme.textMuted)
                        }
                        Text("\(group.items.count)")
                            .font(.inter(9))
                            .foregroundStyle(Theme.textMuted)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, group.tag == nil ? 12 : 16)

                if !isCollapsed {
                    ForEach(group.items) { item in
                        ItemCard(
                            item: item,
                            tags: [],
                            onTap: { appState.openDetail(itemId: item.id) },
                            onComplete: {
                                try? Queries.completeItem(id: item.id)
                                appState.refreshCounts()
                                reload()
                            },
                            onDateChanged: { reload() }
                        )
                    }
                }
            }
        }
        if sortedItems.isEmpty { emptyState }
    }

    @ViewBuilder
    private var emptyState: some View {
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

    private struct TagGroup: Identifiable {
        let id: String
        let tag: Tag?
        let items: [Item]
    }

    private func groupItemsByTag(excludeHighPrio: Bool = false) -> [TagGroup] {
        var taggedGroups: [String: (tag: Tag, items: [Item])] = [:]
        var untagged: [Item] = []

        let source = excludeHighPrio ? sortedItems.filter { $0.priority != .high } : sortedItems
        for item in source {
            let tags = itemTags[item.id] ?? []
            if let firstTag = tags.first {
                if taggedGroups[firstTag.id] == nil {
                    taggedGroups[firstTag.id] = (tag: firstTag, items: [])
                }
                taggedGroups[firstTag.id]?.items.append(item)
            } else {
                untagged.append(item)
            }
        }

        var result = taggedGroups.values
            .sorted { $0.items.count > $1.items.count }
            .map { TagGroup(id: $0.tag.id, tag: $0.tag, items: $0.items) }

        if !untagged.isEmpty {
            result.append(TagGroup(id: "untagged", tag: nil, items: untagged))
        }
        return result
    }

    private let recentThreshold = Date().addingTimeInterval(-300) // 5 minutes

    private var newItems: [Item] {
        // New items show at top REGARDLESS of filters — all recently created unsorted items
        let allRecent = (try? Queries.getAllItems(done: false)) ?? []
        return allRecent.filter { $0.createdAt > recentThreshold && $0.priority == .medium && $0.dueDate == nil }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var sortedItems: [Item] {
        let newIds = Set(newItems.map(\.id))
        return items.filter { !newIds.contains($0.id) }.sorted { a, b in
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

        if highPrioOnly {
            items = items.filter { $0.priority == .high }
        }

        var tagMap: [String: [Tag]] = [:]
        for item in items {
            tagMap[item.id] = (try? Queries.getTagsForItem(itemId: item.id)) ?? []
        }
        itemTags = tagMap

        counts = (try? Queries.getCategoryCounts()) ?? [:]
    }
}
