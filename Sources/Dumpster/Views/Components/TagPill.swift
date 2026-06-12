import SwiftUI

struct TagPill: View {
    let tag: String
    var isSelected: Bool = false
    var action: () -> Void
    var onRename: ((String, String) -> Void)?

    @State private var isEditing = false
    @State private var editText = ""

    var body: some View {
        if isEditing {
            HStack(spacing: 3) {
                Image(systemName: "number")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Theme.accent)
                TextField("", text: $editText)
                    .textFieldStyle(.plain)
                    .font(.inter(10, weight: .medium))
                    .frame(minWidth: 40, maxWidth: 120)
                    .onSubmit { commitRename() }
                    .onExitCommand { isEditing = false }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.accent.opacity(0.15), in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.accent, lineWidth: 1))
            .onAppear {
                editText = tag
            }
        } else {
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
            .onTapGesture(count: 2) {
                if onRename != nil {
                    editText = tag
                    isEditing = true
                }
            }
            .onTapGesture(count: 1) {
                action()
            }
        }
    }

    private func commitRename() {
        let newName = editText.lowercased().trimmingCharacters(in: .whitespaces)
        isEditing = false
        guard !newName.isEmpty, newName != tag.lowercased() else { return }
        onRename?(tag, newName)
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
