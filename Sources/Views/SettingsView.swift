import SwiftUI
import AppKit
import ServiceManagement

/// Tabbed settings window: button mappings & scrolling, and general preferences.
struct SettingsView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            if !state.trusted { PermissionBanner() }
            TabView {
                ButtonsTab().tabItem { Label("Buttons", systemImage: "computermouse") }
                GeneralTab().tabItem { Label("General", systemImage: "gearshape") }
            }
            .padding()
        }
        .frame(width: 760, height: 560)
    }
}

/// Explains why Accessibility access is needed and links to System Settings.
struct PermissionBanner: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.shield.fill").foregroundStyle(.orange).font(.title2)
            VStack(alignment: .leading) {
                Text("Accessibility access needed").bold()
                Text("Open System Settings › Privacy & Security › Accessibility and switch on MouseButtonMapper. Mapping resumes automatically.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Grant Access…") { state.requestPermission() }
        }
        .padding(10)
        .background(.orange.opacity(0.12))
    }
}

/// Profile list on the left, the selected profile's buttons and the scroll options on the right.
struct ButtonsTab: View {
    @EnvironmentObject private var state: AppState
    @State private var selection: UUID?

    private var selectedIndex: Int {
        state.profiles.firstIndex { $0.id == selection } ?? 0
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                List(state.profiles, selection: $selection) { profile in
                    Label(profile.name, systemImage: profile.isDefault ? "star" : "app")
                        .tag(profile.id)
                }
                HStack {
                    Menu {
                        ForEach(addableApps, id: \.processIdentifier) { app in
                            Button(app.localizedName ?? app.bundleIdentifier ?? "App") { state.addProfile(for: app) }
                        }
                    } label: { Image(systemName: "plus") }
                    .menuStyle(.borderlessButton).fixedSize()
                    .help("Add a profile for a running app")
                    Button {
                        if let selection { state.removeProfile(selection) }
                        selection = state.profiles.first?.id
                    } label: { Image(systemName: "minus") }
                    .buttonStyle(.borderless)
                    .disabled(state.profiles[selectedIndex].isDefault)
                    Spacer()
                }
                .padding(6)
            }
            .frame(width: 190)
            .border(Color.secondary.opacity(0.3))

            VStack(alignment: .leading, spacing: 12) {
                MappingsEditor(profileIndex: selectedIndex)
                ScrollSettings()
            }
        }
        .onAppear { if selection == nil { selection = state.profiles.first?.id } }
    }

    /// Regular running apps that don't have a profile yet.
    private var addableApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { app in
                guard app.activationPolicy == .regular, let id = app.bundleIdentifier,
                      id != Bundle.main.bundleIdentifier else { return false }
                return !state.profiles.contains { $0.bundleID == id }
            }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }
}

/// Table of recorded buttons for one profile, with an action popup per row and a Record button.
struct MappingsEditor: View {
    @EnvironmentObject private var state: AppState
    let profileIndex: Int

    var body: some View {
        let profile = state.profiles[profileIndex]
        let recording = state.recordingProfileID == profile.id
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(profile.isDefault ? "Default (all apps)" : profile.name).font(.headline)
                Spacer()
                if recording { Text("Click a mouse button…").foregroundStyle(.secondary) }
                Button(recording ? "Cancel" : "Record") {
                    state.recordingProfileID = recording ? nil : profile.id
                }
                .disabled(!state.trusted)
            }
            if profile.mappings.isEmpty {
                ContentUnavailableView("No buttons yet", systemImage: "computermouse",
                                       description: Text("Press Record, then click a mouse button."))
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach($state.profiles[profileIndex].mappings) { $mapping in
                        MappingRow(mapping: $mapping, conflict: state.defaultConflict(
                            button: mapping.button, action: mapping.action, in: profile)) {
                            state.profiles[profileIndex].mappings.removeAll { $0.id == mapping.id }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
            Text("Left and right buttons are never remapped. Press ⌃⌥⌘M anytime to pause or resume mapping.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// One button → action row.
struct MappingRow: View {
    @Binding var mapping: Mapping
    let conflict: ButtonAction?
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Text(Mapping.name(for: mapping.button)).frame(width: 140, alignment: .leading)
            Picker("", selection: $mapping.action.kind) {
                ForEach(ActionKind.allCases) { Text($0.title).tag($0) }
            }
            .labelsHidden().frame(width: 170)
            switch mapping.action.kind {
            case .shortcut: ShortcutRecorder(combo: $mapping.action.combo)
            case .launchApp:
                Button(mapping.action.appPath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Choose App…") {
                    if let path = chooseApp() { mapping.action.appPath = path }
                }
            default: EmptyView()
            }
            Spacer()
            if let conflict {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    .help("Overrides the Default profile, which maps this button to \(conflict.summary).")
            }
            Button(action: onDelete) { Image(systemName: "trash") }.buttonStyle(.borderless)
        }
    }

    private func chooseApp() -> String? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        return panel.runModal() == .OK ? panel.url?.path : nil
    }
}

/// Wheel speed, reverse direction and modifier fast-scroll options (mouse wheels only).
struct ScrollSettings: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        GroupBox("Scrolling (mouse wheels only — trackpads are untouched)") {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Line speed")
                    Slider(value: $state.scrollSpeed, in: 0.5...5, step: 0.25)
                    Text(String(format: "%.2g×", state.scrollSpeed)).monospacedDigit().frame(width: 40)
                }
                Toggle("Reverse scroll direction for mouse", isOn: $state.reverseScroll)
                Toggle("Hold ⌥ Option to scroll \(Int(state.fastScrollFactor))× faster", isOn: $state.fastScrollEnabled)
            }
            .padding(4)
        }
    }
}

/// Launch at login, Dock visibility, pointer-speed note and support link.
struct GeneralTab: View {
    @AppStorage("showInDock") private var showInDock = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in
                    do {
                        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        loginError = nil
                    } catch {
                        loginError = error.localizedDescription
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
            if let loginError { Text(loginError).font(.caption).foregroundStyle(.red) }
            Toggle("Show in Dock", isOn: $showInDock)
                .onChange(of: showInDock) { _, on in
                    NSApp.setActivationPolicy(on ? .regular : .accessory)
                    NSApp.activate(ignoringOtherApps: true)
                }
            Section("Pointer speed") {
                Text("MouseButtonMapper does not change hardware pointer acceleration — public macOS APIs don't allow it. Adjust tracking speed in System Settings › Mouse.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Open Mouse Settings…") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Mouse-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            Section {
                Button("Support / Donate ❤️") { openDonationPage() }
            }
        }
        .formStyle(.grouped)
    }
}
