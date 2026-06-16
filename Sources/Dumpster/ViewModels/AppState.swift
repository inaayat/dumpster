import Foundation
import SwiftUI

enum NavigationDestination: Hashable {
    case dump
    case items
    case tags
    case tagDetail(String) // tag ID
    case wins
    case docs
    case masterDoc(String) // tag ID
    case guide
}

@Observable
final class AppState {
    var selectedDestination: NavigationDestination = .dump
    var broMode: Bool = UserDefaults.standard.bool(forKey: "broMode") {
        didSet { UserDefaults.standard.set(broMode, forKey: "broMode") }
    }
    var detailPanelItemId: String?
    var masterDocPanelTagId: String?
    var showEditSheet = false
    var editingItem: Item?
    var searchQuery = ""
    var counts: [String: Int] = [:]

    func navigate(to dest: NavigationDestination) {
        if case .tagDetail = dest {
            selectedDestination = dest
        } else if case .masterDoc = dest {
            selectedDestination = dest
        } else {
            selectedDestination = dest
            detailPanelItemId = nil
        }
    }

    func openDetail(itemId: String) {
        detailPanelItemId = itemId
    }

    func closeDetail() {
        detailPanelItemId = nil
    }

    func openMasterDocPanel(tagId: String) {
        if (try? Queries.getMasterDoc(tagId: tagId)) == nil {
            let tag = try? Queries.getTag(id: tagId)
            let title = (tag?.name ?? "Untitled").replacingOccurrences(of: "-", with: " ").capitalized
            try? Queries.upsertMasterDoc(tagId: tagId, content: "", title: title)
        }
        masterDocPanelTagId = tagId
    }

    func closeMasterDocPanel() {
        masterDocPanelTagId = nil
    }

    func refreshCounts() {
        Task {
            do {
                var counts = try Queries.getCategoryCounts()
                counts["wins"] = try Queries.getWinCount()
                let final = counts
                await MainActor.run { self.counts = final }
            } catch {}
        }
    }
}
