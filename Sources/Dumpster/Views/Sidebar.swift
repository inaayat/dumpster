import SwiftUI

struct Sidebar: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Logo — tap to open Guide
            Button {
                appState.navigate(to: .guide)
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 36, height: 36)
                    .background(Theme.accentTint.opacity(0.4), in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Guide & Instructions")
            .padding(.top, 20)
            .padding(.bottom, 24)

            VStack(spacing: 16) {
                sidebarIcon(.dump, icon: "flame.fill", tooltip: "Dump")
                sidebarIcon(.items, icon: "square.stack.fill", tooltip: "Items")
                sidebarIcon(.tags, icon: "number", tooltip: "Tags")
                sidebarIcon(.wins, icon: "star.fill", tooltip: "Wins")
                sidebarIcon(.docs, icon: "doc.text.fill", tooltip: "Docs")
            }

            Spacer()

            // Bro mode toggle
            VStack(spacing: 6) {
                Text(appState.broMode ? "lights\non" : "lights\noff")
                    .font(.inter(7, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.sidebarMuted)
                    .lineLimit(2)

                Toggle("", isOn: $appState.broMode)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.mini)
                    .tint(.gray)
            }
            .frame(width: 56)
            .padding(.bottom, 16)
        }
        .frame(width: 64)
        .background(Theme.sidebarBg)
    }

    @ViewBuilder
    private func sidebarIcon(_ dest: NavigationDestination, icon: String, tooltip: String) -> some View {
        let isSelected = isActive(dest)

        Button {
            appState.navigate(to: dest)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isSelected ? Theme.sidebarBg : Theme.sidebarMuted)
                .frame(width: 38, height: 38)
                .background(isSelected ? Theme.accent : Color.clear, in: Circle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    private func isActive(_ dest: NavigationDestination) -> Bool {
        switch (appState.selectedDestination, dest) {
        case (.dump, .dump), (.items, .items), (.tags, .tags), (.wins, .wins), (.docs, .docs):
            return true
        case (.tagDetail, .tags), (.masterDoc, .docs):
            return true
        default:
            return false
        }
    }
}
