import AppKit
import ApplicationServices
import Combine

/// Central app model: profiles, scroll options, the master toggle, permission state,
/// and the event-handling logic the tap runs for every intercepted event.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var profiles: [Profile] { didSet { ProfileStore.save(profiles) } }
    @Published var enabled: Bool { didSet { defaults.set(enabled, forKey: "enabled") } }
    @Published var scrollSpeed: Double { didSet { defaults.set(scrollSpeed, forKey: "scrollSpeed") } }
    @Published var reverseScroll: Bool { didSet { defaults.set(reverseScroll, forKey: "reverseScroll") } }
    @Published var fastScrollEnabled: Bool { didSet { defaults.set(fastScrollEnabled, forKey: "fastScrollEnabled") } }
    @Published private(set) var trusted = AXIsProcessTrusted()
    @Published private(set) var frontBundleID: String?
    /// Profile currently waiting for a mouse button press, if any.
    @Published var recordingProfileID: UUID?

    /// Modifier that multiplies wheel speed while held.
    let fastScrollModifier: CGEventFlags = .maskAlternate
    let fastScrollFactor = 4.0

    private let defaults = UserDefaults.standard
    private var tap: EventTap?
    private var timer: Timer?
    private var observer: NSObjectProtocol?

    private init() {
        profiles = ProfileStore.load()
        enabled = defaults.object(forKey: "enabled") as? Bool ?? true
        scrollSpeed = defaults.object(forKey: "scrollSpeed") as? Double ?? 1.0
        reverseScroll = defaults.bool(forKey: "reverseScroll")
        fastScrollEnabled = defaults.object(forKey: "fastScrollEnabled") as? Bool ?? true
        frontBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    /// Wires up the tap, front-app tracking and the permission watchdog. Safe to call more than once.
    func start() {
        guard tap == nil else { return }
        tap = EventTap { [unowned self] type, event in
            MainActor.assumeIsolated { self.handle(type, event) }
        }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { self?.frontBundleID = app?.bundleIdentifier }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshPermission() }
        }
        refreshPermission()
    }

    /// Re-checks Accessibility access; tears the tap down if it was revoked, (re)creates it once granted.
    func refreshPermission() {
        trusted = AXIsProcessTrusted()
        guard let tap else { return }
        if trusted && !tap.isRunning { tap.start() }
        if !trusted && tap.isRunning { tap.stop() }
    }

    func requestPermission(openSettings: Bool = true) {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        trusted = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        if openSettings, !trusted, let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Profiles

    var activeProfile: Profile {
        profiles.first { $0.bundleID != nil && $0.bundleID == frontBundleID } ?? profiles[0]
    }

    func addProfile(for app: NSRunningApplication) {
        guard let id = app.bundleIdentifier, !profiles.contains(where: { $0.bundleID == id }) else { return }
        profiles.append(Profile(bundleID: id, name: app.localizedName ?? id))
    }

    func removeProfile(_ id: UUID) {
        profiles.removeAll { $0.id == id && !$0.isDefault }
    }

    /// The Default profile's action for a button when it differs from the given app-profile action.
    func defaultConflict(button: Int, action: ButtonAction, in profile: Profile) -> ButtonAction? {
        guard !profile.isDefault,
              let other = profiles[0].mappings.first(where: { $0.button == button })?.action,
              other != action else { return nil }
        return other
    }

    private func record(button: Int, into profileID: UUID) {
        recordingProfileID = nil
        guard let i = profiles.firstIndex(where: { $0.id == profileID }),
              !profiles[i].mappings.contains(where: { $0.button == button }) else { return }
        profiles[i].mappings.append(Mapping(button: button))
        profiles[i].mappings.sort { $0.button < $1.button }
    }

    // MARK: Event handling

    private func handle(_ type: CGEventType, _ event: CGEvent) -> CGEvent? {
        // Escape hatch: ⌃⌥⌘M always toggles mapping, even when paused.
        if type == .keyDown {
            let required: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]
            let mods = event.flags.intersection([.maskControl, .maskAlternate, .maskCommand, .maskShift])
            if event.getIntegerValueField(.keyboardEventKeycode) == 46, mods == required {
                enabled.toggle()
                return nil
            }
            return event
        }
        if type == .scrollWheel { return enabled ? adjustScroll(event) : event }

        let button = Int(event.getIntegerValueField(.mouseEventButtonNumber))
        // Primary and secondary buttons are never touched; absurd numbers are ignored.
        guard button >= 2, button < 256 else { return event }

        if let profileID = recordingProfileID {
            if type == .otherMouseDown { record(button: button, into: profileID) }
            return nil
        }
        guard enabled, let mapping = activeProfile.mappings.first(where: { $0.button == button }) else { return event }
        if type == .otherMouseDown { ActionPerformer.perform(mapping.action, at: event.location) }
        return nil
    }

    private func adjustScroll(_ event: CGEvent) -> CGEvent {
        // Continuous events come from trackpads / Magic Mouse; only tune real wheels.
        guard event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0 else { return event }
        var factor = scrollSpeed
        if fastScrollEnabled && event.flags.contains(fastScrollModifier) { factor *= fastScrollFactor }
        if reverseScroll { factor = -factor }
        guard factor != 1 else { return event }

        let lines = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        if lines != 0 {
            var scaled = (Double(lines) * factor).rounded()
            if scaled == 0 { scaled = factor * Double(lines) < 0 ? -1 : 1 }
            event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: Int64(scaled))
        }
        let fixed = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: fixed * factor)
        let points = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: Int64((Double(points) * factor).rounded()))
        return event
    }
}
