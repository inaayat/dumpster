import SwiftUI

struct MasterDocEditor: View {
    @Bindable var appState: AppState
    let tagId: String

    @State private var tag: Tag?
    @State private var doc: MasterDoc?

    var body: some View {
        MasterDocCore(
            tagId: tagId,
            tagDisplayName: tag?.name,
            mode: .page,
            onBack: { appState.navigate(to: .docs) },
            onDelete: {
                if let doc { try? Queries.deleteMasterDoc(id: doc.id) }
                appState.navigate(to: .docs)
            }
        )
        .onAppear {
            tag = try? Queries.getTag(id: tagId)
            doc = try? Queries.getMasterDoc(tagId: tagId)
        }
    }
}
