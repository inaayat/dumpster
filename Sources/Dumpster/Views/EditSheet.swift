import SwiftUI

struct EditSheet: View {
    @Bindable var appState: AppState
    let item: Item
    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    @State private var category: Category = .brainstorm
    @State private var priority: Priority = .medium
    @State private var hasDueDate = false
    @State private var dueDate = Date()

    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Item")
                .font(.inter(18, weight: .bold))
                .foregroundStyle(Theme.textPrimary)

            TextEditor(text: $text)
                .font(.inter(14))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80, maxHeight: 150)
                .padding(10)
                .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.border, lineWidth: 1))

            HStack(spacing: 12) {
                Picker("Category", selection: $category) {
                    ForEach(Category.allCases, id: \.self) { cat in
                        Text(cat.label).tag(cat)
                    }
                }
                .frame(maxWidth: 140)

                Picker("Priority", selection: $priority) {
                    ForEach(Priority.allCases, id: \.self) { p in
                        Text(p.rawValue.capitalized).tag(p)
                    }
                }
                .frame(maxWidth: 120)
            }

            HStack {
                Toggle("Due date", isOn: $hasDueDate)
                    .font(.inter(12))
                if hasDueDate {
                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                        .labelsHidden()
                        .controlSize(.small)
                }
                Spacer()
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .font(.inter(12))
                    .foregroundStyle(Theme.textMuted)
                Spacer()
                Button("Save") { save() }
                    .font(.inter(12, weight: .semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
            }
        }
        .padding(24)
        .frame(width: 420)
        .onAppear {
            text = item.text
            category = item.category
            priority = item.priority
            hasDueDate = item.dueDate != nil
            dueDate = item.dueDate ?? Date()
        }
    }

    private func save() {
        var updated = item
        updated.text = text.trimmingCharacters(in: .whitespaces)
        updated.category = category
        updated.priority = priority
        updated.dueDate = hasDueDate ? dueDate : nil
        try? Queries.updateItem(updated)
        appState.refreshCounts()
        dismiss()
    }
}
