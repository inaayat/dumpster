import SwiftUI

struct DocsListView: View {
    @Bindable var appState: AppState
    @State private var docs: [(doc: MasterDoc, tag: Tag?)] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                HStack {
                    Text("Master Docs")
                        .font(.inter(24, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(docs.count)")
                        .font(.inter(11, weight: .bold))
                        .foregroundStyle(Theme.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.cardAlt, in: Capsule())
                    Spacer()
                }

                if docs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 36))
                            .foregroundStyle(Theme.textMuted.opacity(0.4))
                        Text("No documents yet")
                            .font(.inter(14))
                            .foregroundStyle(Theme.textMuted)
                        Text("Create a doc from any tag's detail view, or use #save in your daily dump.")
                            .font(.inter(12))
                            .foregroundStyle(Theme.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    VStack(alignment: .leading, spacing: Theme.itemSpacing) {
                        ForEach(docs, id: \.doc.id) { entry in
                            docRow(entry.doc, tag: entry.tag)
                        }
                    }
                }
            }
            .padding(28)
        }
        .background(Theme.canvas)
        .onAppear { reload() }
    }

    @ViewBuilder
    private func docRow(_ doc: MasterDoc, tag: Tag?) -> some View {
        Button {
            appState.navigate(to: .masterDoc(doc.tagId))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(doc.title)
                        .font(.inter(14, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    HStack(spacing: 8) {
                        if let tag {
                            Text("#\(tag.name)")
                                .font(.inter(10, weight: .medium))
                                .foregroundStyle(Theme.accent)
                        }
                        Text("Updated \(doc.updatedAt.formatted(.dateTime.month(.abbreviated).day()))")
                            .font(.inter(10))
                            .foregroundStyle(Theme.textMuted)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.textMuted)
            }
            .padding(Theme.cardPadding)
            .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func reload() {
        let allDocs = (try? Queries.getAllMasterDocs()) ?? []
        docs = allDocs.map { doc in (doc, try? Queries.getTag(id: doc.tagId)) }
    }
}
