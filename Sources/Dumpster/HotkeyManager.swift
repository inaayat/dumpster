import Cocoa
import Carbon

final class HotkeyManager {
    static let shared = HotkeyManager()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    var onNotepadHotkey: (() -> Void)?

    func register() {
        let mask: CGEventMask = 1 << CGEventType.keyDown.rawValue

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard type == .keyDown else { return Unmanaged.passRetained(event) }

                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                let flags = event.flags

                let hasCtrlOpt = flags.contains(.maskControl) && flags.contains(.maskAlternate)
                let noExtraModifiers = !flags.contains(.maskShift) && !flags.contains(.maskCommand)

                // N key = keycode 45, Ctrl+Option
                if keyCode == 45 && hasCtrlOpt && noExtraModifiers {
                    DispatchQueue.main.async {
                        HotkeyManager.shared.onNotepadHotkey?()
                    }
                    return nil
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: nil
        )

        guard let eventTap else {
            print("Could not create event tap. Enable Accessibility in System Settings > Privacy & Security.")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func unregister() {
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes) }
        eventTap = nil
        runLoopSource = nil
    }
}
