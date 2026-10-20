import SwiftUI
import AppKit

/// App entry point: a menu bar extra plus a settings window.
@main
struct MouseButtonMapperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @ObservedObject private var state = AppState.shared

    var body: some Scene {
        MenuBarExtra("MouseButtonMapper", systemImage: state.enabled ? "computermouse.fill" : "computermouse") {
            MenuContent()
                .environmentObject(state)
        }
        Window("MouseButtonMapper Settings", id: "settings") {
            SettingsView()
                .environmentObject(state)
        }
        .windowResizability(.contentSize)
    }
}

/// Starts the event tap on launch and applies the Dock visibility preference.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let showInDock = UserDefaults.standard.bool(forKey: "showInDock")
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
        Task { @MainActor in
            AppState.shared.start()
            if !AppState.shared.trusted { AppState.shared.requestPermission(openSettings: false) }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

/// Opens the developer's donation page.
func openDonationPage() {
    NSWorkspace.shared.open(URL(string: "https://ko-fi.com/leodavidai")!)
}

/// Items shown in the menu bar extra's menu.
struct MenuContent: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Toggle("Enabled  (⌃⌥⌘M)", isOn: $state.enabled)
        Text("Active profile: \(state.activeProfile.name)")
        if !state.trusted {
            Divider()
            Text("⚠️ Accessibility access is off — mapping paused")
            Button("Grant Accessibility Access…") { state.requestPermission() }
        }
        Divider()
        Button("Open Settings…") {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")
        Button("Support / Donate ❤️") { openDonationPage() }
        Divider()
        Button("Quit MouseButtonMapper") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
