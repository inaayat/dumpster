import SwiftUI

struct ItemCard: View {
    let item: Item
    var tags: [Tag] = []
    var onTap: () -> Void = {}
    var onComplete: (() -> Void)?
    var onDateChanged: (() -> Void)?

    @State private var showDatePicker = false
    @State private var editedDate = Date()

    private var displayText: String {
        item.text
            .replacingOccurrences(of: #"#[\w\-]+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        HStack(spacing: 10) {
            if item.category == .action {
                Button {
                    onComplete?()
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
                Text(displayText)
                    .font(.inter(13))
                    .foregroundStyle(item.done ? Theme.textMuted : Theme.textPrimary)
                    .strikethrough(item.done)
                    .lineLimit(2)

                if !tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(tags) { tag in
                            Text("#\(tag.name)")
                                .font(.inter(9))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }
            }

            Spacer(minLength: 4)

            if !item.done {
                dueDateControl
            }

            if item.priority == .high && !item.done {
                Image(systemName: "arrow.up")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(Theme.brainstormColor, in: Circle())
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
}
