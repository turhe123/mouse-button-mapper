import SwiftUI
import AppKit

/// Small recorder field: click it, then press a key combination to capture it. Esc cancels.
struct ShortcutRecorder: View {
    @Binding var combo: KeyCombo?
    @State private var monitor: Any?

    var body: some View {
        Button(monitor != nil ? "Type shortcut…" : (combo?.display ?? "Record Shortcut")) {
            monitor == nil ? begin() : end()
        }
        .frame(minWidth: 110)
        .onDisappear(perform: end)
    }

    private func begin() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
            if event.keyCode != 53 || !mods.isEmpty { // plain Esc cancels
                combo = KeyCombo(keyCode: event.keyCode, modifiers: Self.cgFlags(mods).rawValue,
                                 display: Self.symbols(mods) + Self.keyName(event))
            }
            end()
            return nil
        }
    }

    private func end() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private static func cgFlags(_ m: NSEvent.ModifierFlags) -> CGEventFlags {
        var f: CGEventFlags = []
        if m.contains(.command) { f.insert(.maskCommand) }
        if m.contains(.option) { f.insert(.maskAlternate) }
        if m.contains(.control) { f.insert(.maskControl) }
        if m.contains(.shift) { f.insert(.maskShift) }
        return f
    }

    private static func symbols(_ m: NSEvent.ModifierFlags) -> String {
        (m.contains(.control) ? "⌃" : "") + (m.contains(.option) ? "⌥" : "")
            + (m.contains(.shift) ? "⇧" : "") + (m.contains(.command) ? "⌘" : "")
    }

    private static func keyName(_ e: NSEvent) -> String {
        let named: [UInt16: String] = [123: "←", 124: "→", 125: "↓", 126: "↑", 36: "↩", 48: "⇥",
                                       49: "Space", 51: "⌫", 53: "⎋", 117: "⌦", 115: "↖", 119: "↘",
                                       116: "⇞", 121: "⇟", 122: "F1", 120: "F2", 99: "F3", 118: "F4",
                                       96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
                                       103: "F11", 111: "F12"]
        if let name = named[e.keyCode] { return name }
        return (e.charactersIgnoringModifiers ?? "?").uppercased()
    }
}
