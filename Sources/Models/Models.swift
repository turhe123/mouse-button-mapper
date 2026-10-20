import Foundation
import CoreGraphics

/// A captured keyboard shortcut: virtual key code, modifier flags and a human-readable label.
struct KeyCombo: Codable, Hashable {
    var keyCode: UInt16
    var modifiers: UInt64
    var display: String

    var flags: CGEventFlags { CGEventFlags(rawValue: modifiers) }
}

/// The kinds of actions a mouse button can be assigned.
enum ActionKind: String, Codable, CaseIterable, Identifiable {
    case none, shortcut, previousSpace, nextSpace, missionControl, showDesktop
    case launchApp, middleClick, copy, paste, playPause

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Do Nothing"
        case .shortcut: return "Keyboard Shortcut"
        case .previousSpace: return "Previous Space"
        case .nextSpace: return "Next Space"
        case .missionControl: return "Mission Control"
        case .showDesktop: return "Show Desktop"
        case .launchApp: return "Launch App"
        case .middleClick: return "Middle Click"
        case .copy: return "Copy"
        case .paste: return "Paste"
        case .playPause: return "Play / Pause"
        }
    }
}

/// An action plus the extra parameters some action kinds need.
struct ButtonAction: Codable, Hashable {
    var kind: ActionKind = .none
    var combo: KeyCombo?
    var appPath: String?

    var summary: String {
        switch kind {
        case .shortcut: return combo.map { "Shortcut \($0.display)" } ?? "Shortcut (unset)"
        case .launchApp: return appPath.map { "Launch \(URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent)" } ?? "Launch App (unset)"
        default: return kind.title
        }
    }
}

/// Binds one physical mouse button number to an action.
struct Mapping: Codable, Identifiable, Hashable {
    var id = UUID()
    var button: Int
    var action = ButtonAction()

    /// Friendly name for a CoreGraphics button number (0 = left, 1 = right, 2 = middle, …).
    static func name(for button: Int) -> String {
        switch button {
        case 2: return "Middle Button"
        case 3: return "Button 4 (Back)"
        case 4: return "Button 5 (Forward)"
        default: return "Button \(button + 1)"
        }
    }
}

/// A set of mappings that applies to one app (by bundle ID) or, when `bundleID` is nil, to all apps.
struct Profile: Codable, Identifiable, Hashable {
    var id = UUID()
    var bundleID: String?
    var name: String
    var mappings: [Mapping] = []

    var isDefault: Bool { bundleID == nil }

    static func makeDefault() -> Profile { Profile(bundleID: nil, name: "Default") }
}

/// Loads and saves profiles as JSON in Application Support.
enum ProfileStore {
    static var fileURL: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        return base.appendingPathComponent("MouseButtonMapper", isDirectory: true).appendingPathComponent("profiles.json")
    }

    static func load() -> [Profile] {
        guard let url = fileURL, let data = try? Data(contentsOf: url),
              var profiles = try? JSONDecoder().decode([Profile].self, from: data) else { return [.makeDefault()] }
        // Guarantee exactly one Default profile, always first.
        let defaults = profiles.filter(\.isDefault)
        profiles.removeAll(where: \.isDefault)
        return [defaults.first ?? .makeDefault()] + profiles
    }

    static func save(_ profiles: [Profile]) {
        guard let url = fileURL else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(profiles).write(to: url, options: .atomic)
        } catch {
            NSLog("MouseButtonMapper: failed to save profiles: \(error.localizedDescription)")
        }
    }
}
