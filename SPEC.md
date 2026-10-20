# MouseButtonMapper — specification

**Tagline:** Give every extra mouse button a job, with per-app profiles, scroll speed and pointer speed settings.

**Category:** Text & Input

**Inspired by (paid):** SteerMouse ($19.99 one-time)

**Frameworks:** SwiftUI, AppKit, CoreGraphics, ApplicationServices, ServiceManagement

**Donation URL (Support button):** https://ko-fi.com/leodavidai

## Spec

What the paid app does and evidence of demand. SteerMouse is a driver-free mouse customization utility that remaps buttons, changes pointer acceleration and tunes scrolling for third-party mice. It is sold at about 19.99 dollars, has been a go-to recommendation for people using gaming and productivity mice on a Mac for many years, and appears in nearly every thread asking how to use the side buttons of a non-Apple mouse. Our version covers the most requested subset: button remapping with per-app profiles and a few scrolling options.

Feature set for our clean-room version. A menu bar app plus a settings window. The user clicks Record next to a button slot, presses a mouse button, and the app learns its number. Each recorded button can be assigned an action: send a keyboard shortcut (for example Command Left bracket for Back), switch to previous or next Space, open Mission Control, show the desktop, launch an app, middle click, copy, paste, play and pause media or do nothing. Profiles are keyed by app bundle identifier with a Default profile as fallback, and the active profile follows the frontmost app. Extra options: reverse scroll direction for mouse only, scroll line speed multiplier, and a modifier-held fast scroll. A master toggle in the menu pauses all mapping.

UI spec. A MenuBarExtra shows the Enabled toggle, the name of the active profile and Open Settings. The settings window has a profile list at left with an add-app button that picks from running apps, and at right a table of recorded buttons with an action popup per row and a Record button. A scrolling section has a speed slider and the reverse toggle. A General tab contains launch at login and a Show in Dock toggle. Empty state: no buttons yet, with the message Press Record, then click a mouse button. Keyboard shortcut recording uses a small recorder field that captures the next key combination.

Technical approach. Create an active CGEventTap, which needs the Accessibility permission, on otherMouseDown, otherMouseUp, otherMouseDragged and scrollWheel events. Read the button number from the mouseEventButtonNumber field. If a mapping exists for the front app profile, swallow the event by returning nil and post the replacement action: build keyboard events with CGEvent keyboardEventSource and post them to the HID event tap, or for system actions post the right shortcut that those actions already have. Resolve the frontmost app with NSWorkspace and update the profile when the activation notification fires. For scrolling, modify the scroll delta fields of the event in place, and for reverse scrolling negate the vertical delta only when the event is not continuous, which distinguishes wheels from trackpads. Store profiles as Codable JSON in Application Support. Use SMAppService for launch at login. Request permission with AXIsProcessTrustedWithOptions and guide the user.

Edge cases and error handling. Re-enable the tap automatically when the system disables it for timeouts. Never remap the primary and secondary buttons to avoid locking the user out, and keep an escape hatch by letting the master toggle hotkey, Control Option Command M, always work. Warn if two profiles bind the same button to conflicting actions. Handle mice that report more than 16 buttons gracefully. If Accessibility access is revoked while running, show a menu warning instead of crashing. Do not claim to change hardware-level pointer acceleration beyond what public APIs allow, and say so in the settings. Keep the code near 500 lines.
