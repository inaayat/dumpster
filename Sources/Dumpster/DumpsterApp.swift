import SwiftUI

@main
struct DumpsterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("Dumpster", id: "main") {
            ContentView()
        }
        .defaultSize(width: 1000, height: 700)

        MenuBarExtra("Dumpster", systemImage: "tray.fill") {
            Button("Add Note") {
                DumpPanel.shared.toggle()
            }
            .keyboardShortcut("n", modifiers: [.control, .option])

            Divider()

            Button("Open Dumpster") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.title == "Dumpster" }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }

            Divider()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        FontLoader.registerFonts()
        _ = DatabaseManager.shared

        try? Queries.promoteDueSoonToHigh()

        HotkeyManager.shared.onNotepadHotkey = {
            DumpPanel.shared.toggle()
        }
        HotkeyManager.shared.register()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
