import SwiftUI

struct WinsView: View {
    @Bindable var appState: AppState
    @State private var wins: [(win: Win, item: Item?)] = []
    @State private var showAddWin = false
    @State private var newWinText = ""
    @State private var newWinArtifact = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "trophy.fill").foregroundStyle(Theme.warnColor)
                Text("Wins").font(.inter(20, weight: .bold))
                Spacer()
                Text("\(wins.count) logged").font(.inter(11)).foregroundStyle(Theme.textMuted)
                Button {
                    showAddWin.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                        Text("Log Win").font(.inter(11, weight: .semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.warnColor)
                .controlSize(.small)
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 12)

            HStack(spacing: 16) {
                howToChip(icon: "number", text: "Add #win to any bullet in your Daily Dump")
                howToChip(icon: "plus.circle", text: "Or tap \"Log Win\" to add one directly")
                howToChip(icon: "trash", text: "Right-click a win to delete it")
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 14)

            if showAddWin {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("What did you achieve?", text: $newWinText)
                        .textFieldStyle(.roundedBorder).font(.inter(13))
                    TextField("Artifact URL (optional)", text: $newWinArtifact)
                        .textFieldStyle(.roundedBorder).font(.inter(11))
                    HStack {
                        Spacer()
                        Button("Cancel") { showAddWin = false; newWinText = ""; newWinArtifact = "" }
                            .font(.inter(11)).foregroundStyle(Theme.textMuted)
                        Button("Save Win") { saveWin() }
                            .font(.inter(11, weight: .semibold))
                            .buttonStyle(.borderedProminent).tint(Theme.warnColor).controlSize(.small)
                            .disabled(newWinText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(.horizontal, 28).padding(.bottom, 12)
            }

            if wins.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "trophy").font(.system(size: 40)).foregroundStyle(Theme.warnColor.opacity(0.4))
                    Text("No wins logged yet").font(.inter(13)).foregroundStyle(Theme.textMuted)
                    Text("Use #win in your daily dump or log wins here!").font(.inter(11)).foregroundStyle(Theme.textMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(wins, id: \.win.id) { entry in
                            winCard(entry.win, item: entry.item)
                        }
                    }
                    .padding(.horizontal, 28).padding(.bottom, 28)
                }
            }
        }
        .background(Theme.canvas)
        .onAppear { loadWins() }
    }

    @ViewBuilder
    private func winCard(_ win: Win, item: Item?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill").foregroundStyle(Theme.warnColor).font(.system(size: 12))
                Text(win.text).font(.inter(13, weight: .medium)).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(win.createdAt.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.inter(10)).foregroundStyle(Theme.textMuted)
            }
            if let item {
                Text(item.text).font(.inter(11)).foregroundStyle(Theme.textMuted).lineLimit(2)
            }
            if let artifact = win.artifact, let url = URL(string: artifact) {
                SwiftUI.Link(destination: url) {
                    HStack(spacing: 6) {
                        Image(systemName: "link").font(.system(size: 10)).foregroundStyle(Theme.resourceColor)
                        Text(url.host ?? artifact).font(.inter(11)).foregroundStyle(Theme.resourceColor)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.cardBorder, lineWidth: 1))
        .contextMenu {
            Button(role: .destructive) {
                try? Queries.deleteWin(id: win.id)
                loadWins()
            } label: {
                Label("Delete Win", systemImage: "trash")
            }
        }
    }

    private func saveWin() {
        let text = newWinText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let artifact = newWinArtifact.trimmingCharacters(in: .whitespaces)
        let win = Win.new(text: text, artifact: artifact.isEmpty ? nil : artifact)
        try? Queries.addWin(win)
        newWinText = ""; newWinArtifact = ""; showAddWin = false
        appState.refreshCounts()
        loadWins()
    }

    private func loadWins() {
        let allWins = (try? Queries.getAllWins()) ?? []
        wins = allWins.map { win in (win, win.itemId.flatMap { try? Queries.getItem(id: $0) }) }
    }

    private func howToChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.warnColor)
            Text(text)
                .font(.inter(11))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.warnColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}
