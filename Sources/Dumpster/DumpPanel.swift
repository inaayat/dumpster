import SwiftUI
import AppKit

final class DumpPanel {
    static let shared = DumpPanel()
    private var panel: NSPanel?

    func toggle() {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
        } else {
            show()
        }
    }

    private func show() {
        if panel == nil {
            let hostingView = NSHostingView(rootView: DumpPanelContent(onDismiss: { [weak self] in
                self?.panel?.orderOut(nil)
            }))

            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 120),
                styleMask: [.titled, .closable, .nonactivatingPanel, .hudWindow],
                backing: .buffered,
                defer: false
            )
            panel.contentView = hostingView
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isMovableByWindowBackground = true
            panel.center()
            self.panel = panel
        }

        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct DumpPanelContent: View {
    var onDismiss: () -> Void
    @State private var text = ""
    @State private var saved = false

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "tray.fill")
                    .foregroundStyle(Theme.accent)
                Text("Quick Dump")
                    .font(.inter(13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if saved {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.successColor)
                        .transition(.opacity)
                }
            }

            TextField("Add a bullet to today's dump...", text: $text)
                .textFieldStyle(.plain)
                .font(.inter(14))
                .padding(10)
                .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Theme.border, lineWidth: 1))
                .onSubmit { save() }
        }
        .padding(16)
        .frame(width: 400)
        .background(Theme.canvas)
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        try? Queries.appendToDump(date: DailyDump.today(), bullet: trimmed)
        text = ""
        withAnimation { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            saved = false
            onDismiss()
        }
    }
}
