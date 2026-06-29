import SwiftUI

struct WinsView: View {
    @Bindable var appState: AppState
    @State private var wins: [(win: Win, item: Item?)] = []
    @State private var filter: WinKind = .all
    @State private var showAddForm = false
    @State private var newText = ""
    @State private var newArtifact = ""
    @State private var newKind: WinKind = .win
    @State private var selectedWinId: String?
    @State private var starS = ""
    @State private var starT = ""
    @State private var starA = ""
    @State private var starR = ""

    enum WinKind: String, CaseIterable {
        case all = "All"
        case win = "Wins"
        case scenario = "Scenarios"

        var apiValue: String? {
            switch self {
            case .all: return nil
            case .win: return "win"
            case .scenario: return "scenario"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "star.fill").foregroundStyle(Theme.warnColor)
                Text("Wins & Scenarios").font(.inter(20, weight: .bold))
                Spacer()
                Text("\(wins.count) logged").font(.inter(11)).foregroundStyle(Theme.textMuted)
                Button {
                    newKind = .win
                    showAddForm.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                        Text("Log Win").font(.inter(11, weight: .semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.warnColor)
                .controlSize(.small)

                Button {
                    newKind = .scenario
                    showAddForm.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                        Text("Log Scenario").font(.inter(11, weight: .semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .controlSize(.small)
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 10)

            // Filter chips
            HStack(spacing: 8) {
                ForEach(WinKind.allCases, id: \.self) { kind in
                    filterChip(kind.rawValue, selected: filter == kind) {
                        filter = kind
                        reload()
                    }
                }
                Spacer()
                howToChip(icon: "number", text: "#win or #scenario in Daily Dump")
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 14)

            // Add form
            if showAddForm {
                VStack(alignment: .leading, spacing: 8) {
                    Text(newKind == .scenario ? "New Scenario" : "New Win")
                        .font(.inter(12, weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                    TextField("What did you achieve?", text: $newText)
                        .textFieldStyle(.roundedBorder).font(.inter(13))
                    if newKind == .win {
                        TextField("Artifact URL (optional)", text: $newArtifact)
                            .textFieldStyle(.roundedBorder).font(.inter(11))
                    }
                    HStack {
                        Spacer()
                        Button("Cancel") {
                            showAddForm = false; newText = ""; newArtifact = ""
                        }
                        .font(.inter(11)).foregroundStyle(Theme.textMuted)
                        Button("Save") { saveEntry() }
                            .font(.inter(11, weight: .semibold))
                            .buttonStyle(.borderedProminent)
                            .tint(newKind == .scenario ? Theme.accent : Theme.warnColor)
                            .controlSize(.small)
                            .disabled(newText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(.horizontal, 28).padding(.bottom, 12)
            }

            if wins.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "star").font(.system(size: 40)).foregroundStyle(Theme.warnColor.opacity(0.4))
                    Text("No wins or scenarios yet").font(.inter(13)).foregroundStyle(Theme.textMuted)
                    Text("Use #win or #scenario in your daily dump").font(.inter(11)).foregroundStyle(Theme.textMuted)
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
        .onAppear { reload() }
    }

    @ViewBuilder
    private func winCard(_ win: Win, item: Item?) -> some View {
        let isSelected = selectedWinId == win.id
        VStack(alignment: .leading, spacing: 0) {
            // Card header — click to expand/collapse STAR
            Button {
                if isSelected {
                    selectedWinId = nil
                } else {
                    selectWin(win)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: win.kind == "scenario" ? "person.fill.questionmark" : "trophy.fill")
                        .foregroundStyle(win.kind == "scenario" ? Theme.accent : Theme.warnColor)
                        .font(.system(size: 12))
                    Text(win.text)
                        .font(.inter(13, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(win.createdAt.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.inter(10)).foregroundStyle(Theme.textMuted)
                    Image(systemName: isSelected ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10)).foregroundStyle(Theme.textMuted)
                }
                .padding(12)
            }
            .buttonStyle(.plain)

            if let item {
                Text(item.text)
                    .font(.inter(11)).foregroundStyle(Theme.textMuted).lineLimit(1)
                    .padding(.horizontal, 12).padding(.bottom, 6)
            }

            if let artifact = win.artifact, let url = URL(string: artifact) {
                SwiftUI.Link(destination: url) {
                    HStack(spacing: 6) {
                        Image(systemName: "link").font(.system(size: 10)).foregroundStyle(Theme.resourceColor)
                        Text(url.host ?? artifact).font(.inter(11)).foregroundStyle(Theme.resourceColor)
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, 8)
            }

            // STAR fields (expanded)
            if isSelected {
                Divider().padding(.horizontal, 12)
                VStack(alignment: .leading, spacing: 10) {
                    starField(label: "S", title: "Situation", binding: $starS, win: win)
                    starField(label: "T", title: "Task", binding: $starT, win: win)
                    starField(label: "A", title: "Action", binding: $starA, win: win)
                    starField(label: "R", title: "Result", binding: $starR, win: win)
                }
                .padding(12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .strokeBorder(isSelected ? Theme.accent.opacity(0.4) : Theme.cardBorder, lineWidth: 1)
        )
        .contextMenu {
            Button(role: .destructive) {
                try? Queries.deleteWin(id: win.id)
                if selectedWinId == win.id { selectedWinId = nil }
                reload()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func starField(label: String, title: String, binding: Binding<String>, win: Win) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.inter(10, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 16, height: 16)
                    .background(Theme.accentTint, in: Circle())
                Text(title)
                    .font(.inter(11, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
            }
            TextEditor(text: binding)
                .font(.inter(12))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 52)
                .padding(8)
                .background(Theme.canvas, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.border, lineWidth: 1))
                .onChange(of: binding.wrappedValue) { _, _ in saveSTAR(for: win) }
        }
    }

    private func selectWin(_ win: Win) {
        selectedWinId = win.id
        let fields = StarFields.from(win.star)
        starS = fields.s; starT = fields.t; starA = fields.a; starR = fields.r
    }

    private func saveSTAR(for win: Win) {
        guard let idx = wins.firstIndex(where: { $0.win.id == win.id }) else { return }
        let fields = StarFields(s: starS, t: starT, a: starA, r: starR)
        var updated = wins[idx].win
        updated.star = fields.toJSON()
        try? Queries.updateWin(updated)
        wins[idx] = (win: updated, item: wins[idx].item)
    }

    private func saveEntry() {
        let text = newText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let artifact = newArtifact.trimmingCharacters(in: .whitespaces)
        let win = Win.new(text: text, artifact: artifact.isEmpty ? nil : artifact, kind: newKind.apiValue ?? "win")
        try? Queries.addWin(win)
        newText = ""; newArtifact = ""; showAddForm = false
        appState.refreshCounts()
        reload()
    }

    private func reload() {
        let allWins = (try? Queries.getAllWins(kind: filter.apiValue)) ?? []
        wins = allWins.map { win in (win, win.itemId.flatMap { try? Queries.getItem(id: $0) }) }
    }

    private func filterChip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.inter(11, weight: .semibold))
                .foregroundStyle(selected ? .white : Theme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(selected ? Theme.accent : Theme.accent.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
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
