import SwiftUI

struct TagPill: View {
    let tag: String
    var isSelected: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: "number")
                    .font(.system(size: 8, weight: .bold))
                Text(tag)
                    .font(.inter(10, weight: .medium))
            }
            .foregroundStyle(isSelected ? .white : Theme.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Theme.accent : Theme.accent.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct CategoryBadge: View {
    let category: Category

    var body: some View {
        Image(systemName: category.icon)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(Theme.categoryColor(category))
            .frame(width: 18, height: 18)
            .background(Theme.categoryTint(category), in: Circle())
    }
}
