import SwiftUI

struct ItemCard: View {
    let item: Item
    var tags: [Tag] = []
    var onTap: () -> Void = {}
    var onComplete: (() -> Void)?
    var onDelete: (() -> Void)?
    var onDateChanged: (() -> Void)?
    var onOpenDoc: ((String) -> Void)?

    @State private var showDatePicker = false
    @State private var editedDate = Date()

    private var displayText: String {
        item.text
            .replacingOccurrences(of: #"#[\w\-]+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        HStack(spacing: 8) {
            if item.category == .action {
                Button {
                    onComplete?()
                } label: {
                    Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundStyle(item.done ? Theme.successColor : Theme.textMuted.opacity(0.4))
                }
                .buttonStyle(.plain)
            } else {
                CategoryBadge(category: item.category)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(displayText)
                    .font(.inter(12))
                    .foregroundStyle(item.done ? Theme.textMuted : Theme.textPrimary)
                    .strikethrough(item.done)
                    .lineLimit(2)

                if !tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(tags) { tag in
                            Text("#\(tag.name)")
                                .font(.inter(9))
                                .foregroundStyle(Theme.accent)
                                .contextMenu {
                                    Button {
                                        onOpenDoc?(tag.id)
                                    } label: {
                                        Label("Open Master Doc", systemImage: "doc.text.fill")
                                    }
                                }
                        }
                    }
                }
            }

            Spacer(minLength: 4)

            if !item.done {
                dueDateControl
            }

            if !item.done {
                Menu {
                    Button { setPriority(.high) } label: { Label("High", systemImage: "arrow.up") }
                    Button { setPriority(.medium) } label: { Label("Standard", systemImage: "minus") }
                    Button { setPriority(.low) } label: { Label("Low", systemImage: "arrow.down") }
                    Button { setPriority(.backlog) } label: { Label("Backlog", systemImage: "archivebox") }
                } label: {
                    Image(systemName: item.priority == .high ? "arrow.up" : (item.priority == .backlog ? "archivebox" : "minus"))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(item.priority == .high ? .white : Theme.textMuted)
                        .frame(width: 20, height: 20)
                        .background(item.priority == .high ? Theme.actionColor : Theme.cardAlt, in: Circle())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            if let onDelete {
                Button {
                    onDelete()
                } label: {
                    Text("🗑️")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Delete item")
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.cardBorder, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .popover(isPresented: $showDatePicker) {
            VStack(spacing: 12) {
                DatePicker("Due date", selection: $editedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .frame(width: 260)
                HStack {
                    Button("Remove") {
                        var updated = item
                        updated.dueDate = nil
                        try? Queries.updateItem(updated)
                        showDatePicker = false
                        onDateChanged?()
                    }
                    .font(.inter(11))
                    .foregroundStyle(.red)
                    Spacer()
                    Button("Set") {
                        var updated = item
                        updated.dueDate = editedDate
                        try? Queries.updateItem(updated)
                        showDatePicker = false
                        onDateChanged?()
                    }
                    .font(.inter(11, weight: .semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .controlSize(.small)
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var dueDateControl: some View {
        if let dueDate = item.dueDate {
            Button {
                editedDate = dueDate
                showDatePicker = true
            } label: {
                let isOverdue = item.isOverdue
                let isToday = item.isDueToday
                Text(dueDate.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.inter(9, weight: .semibold))
                    .foregroundStyle(isOverdue ? .white : (isToday ? Theme.warnColor : Theme.textMuted))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isOverdue ? Color.red : (isToday ? Theme.warnColor.opacity(0.15) : Theme.cardAlt), in: Capsule())
            }
            .buttonStyle(.plain)
        } else {
            Button {
                editedDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                showDatePicker = true
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textMuted.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
    }

    private func setPriority(_ priority: Priority) {
        var updated = item
        updated.priority = priority
        try? Queries.updateItem(updated)
        onDateChanged?()
    }
}
