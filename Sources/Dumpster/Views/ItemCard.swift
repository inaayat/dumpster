import SwiftUI

struct ItemCard: View {
    let item: Item
    var tags: [Tag] = []
    var onTap: () -> Void = {}
    var onComplete: (() -> Void)?

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
                Text(item.text)
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

            Spacer()

            if let dueDate = item.dueDate, !item.done {
                dueBadge(dueDate)
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
    }

    @ViewBuilder
    private func dueBadge(_ date: Date) -> some View {
        let isOverdue = item.isOverdue
        let isToday = item.isDueToday
        Text(date.formatted(.dateTime.month(.abbreviated).day()))
            .font(.inter(9, weight: .semibold))
            .foregroundStyle(isOverdue ? .white : (isToday ? Theme.warnColor : Theme.textMuted))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isOverdue ? Color.red : (isToday ? Theme.warnColor.opacity(0.15) : Theme.cardAlt), in: Capsule())
    }
}
