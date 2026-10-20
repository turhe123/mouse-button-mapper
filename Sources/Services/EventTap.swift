import AppKit
import CoreGraphics

/// Owns the active CGEventTap and forwards every intercepted event to a handler.
/// The handler returns the event to let it through, or nil to swallow it.
final class EventTap {
    typealias Handler = (CGEventType, CGEvent) -> CGEvent?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private let handler: Handler

    var isRunning: Bool { tap != nil }

    init(handler: @escaping Handler) { self.handler = handler }

    /// Creates the tap on the main run loop. Returns false if Accessibility access is missing.
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let types: [CGEventType] = [.otherMouseDown, .otherMouseUp, .otherMouseDragged, .scrollWheel, .keyDown]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let me = Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue()
            // The system disables slow taps; turn ourselves back on immediately.
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = me.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            // Never re-process events this app synthesized.
            if event.getIntegerValueField(.eventSourceUserData) == ActionPerformer.marker {
                return Unmanaged.passUnretained(event)
            }
            guard let result = me.handler(type, event) else { return nil }
            return Unmanaged.passUnretained(result)
        }
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                           options: .defaultTap, eventsOfInterest: mask,
                                           callback: callback,
                                           userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        tap = port
        source = src
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }
}

/// Synthesizes the replacement input for each action kind.
enum ActionPerformer {
    /// Tag stamped on synthesized events so the tap lets them pass untouched.
    static let marker: Int64 = 0x4D424D // "MBM"

    private static let arrowFlags: CGEventFlags = [.maskSecondaryFn, .maskNumericPad]

    static func perform(_ action: ButtonAction, at location: CGPoint) {
        switch action.kind {
        case .none: break
        case .shortcut:
            guard let c = action.combo else { break }
            // Arrow keys carry the fn/numpad flags on real keyboards; apps such as Spaces expect them.
            postKey(c.keyCode, flags: (123...126).contains(c.keyCode) ? c.flags.union(arrowFlags) : c.flags)
        case .previousSpace: postKey(123, flags: arrowFlags.union(.maskControl))
        case .nextSpace: postKey(124, flags: arrowFlags.union(.maskControl))
        case .missionControl: openApp(at: "/System/Applications/Mission Control.app")
        case .showDesktop: postKey(103, flags: .maskSecondaryFn) // F11
        case .launchApp: if let path = action.appPath { openApp(at: path) }
        case .middleClick: postMiddleClick(at: location)
        case .copy: postKey(8, flags: .maskCommand)
        case .paste: postKey(9, flags: .maskCommand)
        case .playPause: postMediaKey(16) // NX_KEYTYPE_PLAY
        }
    }

    static func postKey(_ code: UInt16, flags: CGEventFlags) {
        let src = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: down) else { continue }
            e.flags = flags
            e.setIntegerValueField(.eventSourceUserData, value: marker)
            e.post(tap: .cghidEventTap)
        }
    }

    private static func postMiddleClick(at location: CGPoint) {
        let src = CGEventSource(stateID: .hidSystemState)
        for type in [CGEventType.otherMouseDown, .otherMouseUp] {
            guard let e = CGEvent(mouseEventSource: src, mouseType: type, mouseCursorPosition: location, mouseButton: .center) else { continue }
            e.setIntegerValueField(.eventSourceUserData, value: marker)
            e.post(tap: .cghidEventTap)
        }
    }

    private static func postMediaKey(_ key: Int) {
        for down in [true, false] {
            let state = down ? 0xA00 : 0xB00
            let event = NSEvent.otherEvent(with: .systemDefined, location: .zero,
                                           modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state)),
                                           timestamp: 0, windowNumber: 0, context: nil,
                                           subtype: 8, data1: (key << 16) | state, data2: -1)
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
    }

    private static func openApp(at path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error { NSLog("MouseButtonMapper: could not open \(path): \(error.localizedDescription)") }
        }
    }
}
