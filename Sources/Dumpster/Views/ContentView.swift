import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(appState: appState)

            Divider().background(Theme.border)

            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.canvas)

            if appState.detailPanelItemId != nil {
                Divider().background(Theme.divider)

                detailPanel
                    .frame(minWidth: 320, idealWidth: 380, maxWidth: 400)
                    .background(Theme.cardBg)
                    .transition(.move(edge: .trailing))
            }

            if let tagId = appState.masterDocPanelTagId {
                Divider().background(Theme.divider)

                MasterDocCore(
                    tagId: tagId,
                    tagDisplayName: (try? Queries.getTag(id: tagId))?.name,
                    mode: .panel,
                    siblingTagIds: appState.masterDocSiblingTagIds,
                    onClose: { withAnimation { appState.closeMasterDocPanel() } },
                    onSwitchTag: { newTagId in
                        withAnimation {
                            let remainingSiblings = ([tagId] + appState.masterDocSiblingTagIds).filter { $0 != newTagId }
                            appState.openMasterDocPanel(tagId: newTagId, siblingTagIds: remainingSiblings)
                        }
                    }
                )
                .frame(minWidth: 340, idealWidth: 420, maxWidth: 500)
                .background(Theme.cardBg)
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.detailPanelItemId)
        .animation(.easeInOut(duration: 0.25), value: appState.masterDocPanelTagId)
        .frame(minWidth: 800, minHeight: 560)
        .preferredColorScheme(Theme.colorScheme)
        .id(appState.broMode)
        .sheet(isPresented: $appState.showEditSheet) {
            if let item = appState.editingItem {
                EditSheet(appState: appState, item: item)
            }
        }
        .onAppear { appState.refreshCounts() }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch appState.selectedDestination {
        case .dump:
            DumpView(appState: appState)
        case .items:
            ItemsView(appState: appState)
        case .tags:
            TagsView(appState: appState)
        case .tagDetail(let tagId):
            TagDetailView(appState: appState, tagId: tagId)
        case .wins:
            WinsView(appState: appState)
        case .docs:
            DocsListView(appState: appState)
        case .masterDoc(let tagId):
            MasterDocEditor(appState: appState, tagId: tagId)
        case .guide:
            GuideView()
        }
    }

    @ViewBuilder
    private var detailPanel: some View {
        if let itemId = appState.detailPanelItemId {
            ItemDetailPanel(appState: appState, itemId: itemId)
                .padding(20)
        }
    }
}
