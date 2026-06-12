import SwiftUI

struct FilterTabs: View {
    @Binding var selected: Category?
    let counts: [String: Int]

    var body: some View {
        HStack(spacing: 6) {
            filterTab(label: "All", category: nil, count: counts["all"] ?? 0)
            filterTab(label: "Actions", category: .action, count: counts["action"] ?? 0)
            filterTab(label: "Brainstorms", category: .brainstorm, count: counts["brainstorm"] ?? 0)
            filterTab(label: "Resources", category: .resource, count: counts["resource"] ?? 0)
        }
    }

    @ViewBuilder
    private func filterTab(label: String, category: Category?, count: Int) -> some View {
        let isActive = selected == category
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { selected = category }
        } label: {
            HStack(spacing: 4) {
                Text(label)
                    .font(.inter(11, weight: .medium))
                Text("\(count)")
                    .font(.inter(10))
                    .foregroundStyle(isActive ? .white.opacity(0.7) : Theme.textMuted)
            }
            .foregroundStyle(isActive ? .white : Theme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isActive ? Theme.accent : Theme.cardAlt, in: Capsule())
            .overlay(Capsule().strokeBorder(isActive ? Color.clear : Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
