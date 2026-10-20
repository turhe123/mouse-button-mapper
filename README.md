# MouseButtonMapper

Give every extra mouse button a job, with per-app profiles, scroll speed and pointer speed settings.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License MIT](https://img.shields.io/badge/License-MIT-green)
![GitHub release](https://img.shields.io/github/v/release/turhe123/mouse-button-mapper)

## Why

MouseButtonMapper is a free, open-source, 100% native, backend-free alternative to paid utilities in the *Text & Input* category. It was inspired by SteerMouse ($19.99 one-time), a long-standing favorite for getting the side buttons of non-Apple mice working on a Mac. This app covers a focused subset of that idea: button remapping with per-app profiles, plus a few wheel-scrolling options.

## Features

- **Menu bar app plus a settings window.** The menu shows an Enabled toggle, the active profile and Open Settings.
- **Record a button, then assign it.** Click Record, press a mouse button, and the app learns its number. Buttons 3 and up are supported (middle, back, forward and beyond).
- **Actions:** Keyboard Shortcut (recorded with a small key-combo field), Previous Space, Next Space, Mission Control, Show Desktop, Launch App, Middle Click, Copy, Paste, Play / Pause, or Do Nothing.
- **Per-app profiles.** Profiles are keyed by app bundle identifier, with a Default profile as the fallback. The active profile follows the frontmost app. Add a profile from the list of running apps.
- **Conflict warning.** A warning icon appears when an app profile overrides a different action set in the Default profile.
- **Scrolling (mouse wheels only, trackpads are untouched):** line-speed multiplier (0.5× to 5×), reverse scroll direction for mouse only, and hold ⌥ Option to scroll 4× faster.
- **Master toggle and escape hatch.** Pause all mapping from the menu, or press ⌃⌥⌘M at any time, even while paused.
- **Safety:** the left and right buttons are never remapped. The event tap re-enables itself after a system timeout, and if Accessibility access is revoked the app shows a warning instead of crashing.
- **General settings:** launch at login, Show in Dock, and a shortcut to System Settings › Mouse.
- **Local storage.** Profiles are saved as JSON in `~/Library/Application Support/MouseButtonMapper/profiles.json`.

### Pointer speed

MouseButtonMapper does **not** change hardware pointer acceleration, because public macOS APIs don't allow it. The General tab says so and links to System Settings › Mouse, where you can adjust tracking speed.

## Screenshots

_Screenshots coming soon._

## Install

1. Download `MouseButtonMapper-macOS.zip` from the [latest release](https://github.com/turhe123/mouse-button-mapper/releases/latest).
2. Unzip it and move `MouseButtonMapper.app` to `/Applications`.
3. Because the app is open source and not notarized, clear the quarantine flag:

   ```bash
   xattr -cr /Applications/MouseButtonMapper.app
   ```

4. Right-click the app and choose **Open** the first time you launch it.

## Build from source

Requires macOS 14+ and Xcode with Swift 5.9+.

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project MouseButtonMapper.xcodeproj -scheme MouseButtonMapper -configuration Release -derivedDataPath ./build build
```

The app is produced at `build/Build/Products/Release/MouseButtonMapper.app`.

## Permissions

- **Accessibility (required).** MouseButtonMapper installs an active event tap to see extra mouse buttons and scroll-wheel events, swallow the ones you remapped, and post the replacement keystrokes, clicks and media keys. It also watches for the ⌃⌥⌘M hotkey. macOS gates this behind Accessibility. Grant it in System Settings › Privacy & Security › Accessibility. Mapping resumes automatically once access is granted.

That is the only permission the code requests. It does not ask for Screen Recording or Microphone access, and it makes no network connections.

## Built with AI

MouseButtonMapper was written by [Claude Code](https://claude.com/claude-code) inside an automated pipeline, from a plain-English spec. No code, binaries or assets from any commercial app were used; it is a clean-room reimplementation of a feature set, not a copy.

What that means in practice:

- The full source is in this repo under the MIT license. Read it before you run it.
- No network calls, no analytics, no third-party dependencies. Only Apple frameworks.
- Ad-hoc signed and not notarized, which is why Gatekeeper warns on first launch.
- It has had less human review than a hand-written app. Bug reports and pull requests are welcome.

## Support ❤️

If this saved you some clicks, you can support the author: [Support Or (Leo) Davidai ❤️](https://ko-fi.com/leodavidai)

## License

MIT © Or Davidai Bachar
