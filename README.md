# ClipTypeSidebar

A docked clipboard sidebar that sorts history into text, links, images, colors and files with text transforms.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License MIT](https://img.shields.io/badge/License-MIT-green)
![GitHub release](https://img.shields.io/github/v/release/turhe123/clip-type-sidebar)

## Why

ClipTypeSidebar is a free, open-source, 100% native, backend-free alternative to paid utilities in the *Clipboard* category. It was inspired by PastePal (about $14.99 one-time Pro) and its idea of browsing history in a side panel. Everything runs locally: no accounts, no servers, no analytics. Your history stays in a JSON file on your Mac.

## Features

- **Automatic classification.** The pasteboard is polled every half second and each new item is sorted into Text, Rich Text, Links, Images, Colors (hex codes such as `#1A2B3C`) or Files.
- **Docked sidebar.** A 340 pt wide panel on the right edge of the screen, opened with a global hotkey (default ⌥⌘V, configurable), from the menu bar, or optionally by pushing the pointer against the right screen edge.
- **Type filter chips and search** to narrow the list quickly.
- **Rich rows.** Each row shows a preview (image thumbnail, color swatch, or kind icon), the source app's icon and name, and a relative time.
- **Paste back.** Return pastes the selected item into the previous app; Shift+Return pastes as plain text. Double-click also pastes.
- **Text transforms** from the row's context menu (Text, Rich Text, Links, Colors): UPPERCASE, lowercase, Title Case, Trim Whitespace, Remove Line Breaks, Sort Lines, Wrap in Quotes.
- **Pinning.** Pinned items are never expired or removed by Clear History.
- **Context actions:** Paste, Paste as Plain Text, Pin/Unpin, Open Link, Reveal in Finder, Delete.
- **Keyboard control:** ↑/↓ to move, ⌘Delete to remove, ⌘P to pin, Esc to close.
- **Privacy-minded.** Items marked concealed, transient or auto-generated (as password managers do) are skipped, and 1Password and Bitwarden are ignored by default. You can add more ignored apps in Settings.
- **Retention controls.** Keep 50–500 items and expire after 1, 7, 30, 90, 365 days or never. Orphaned image files are cleaned up automatically.
- **Images** are stored as PNGs (downscaled to at most 2560 px) in Application Support, with small cached thumbnails.
- **Missing files** are shown dimmed and struck through.
- **Menu bar app** with Show Sidebar, Pause Capture, Clear History, Settings and Quit. Capture is also paused during system sleep.
- **Launch at login** via `SMAppService`.

## Screenshots

_Screenshots coming soon._

## Install

1. Download `ClipTypeSidebar-macOS.zip` from the [latest release](https://github.com/turhe123/clip-type-sidebar/releases/latest).
2. Unzip it and move `ClipTypeSidebar.app` to `/Applications`.
3. Because the app is open source and not notarized, clear the quarantine flag:

   ```bash
   xattr -cr /Applications/ClipTypeSidebar.app
   ```

4. Right-click the app and choose **Open** the first time you launch it.

Requires macOS 14.0 or later.

## Build from source

You need Xcode with the macOS SDK and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project ClipTypeSidebar.xcodeproj -scheme ClipTypeSidebar -configuration Release -derivedDataPath ./build build
```

The app is produced at `build/Build/Products/Release/ClipTypeSidebar.app`.

## Permissions

- **Accessibility** (optional, requested on demand). Needed only to paste directly into the app you were using: ClipTypeSidebar sends a synthetic ⌘V. An explanation sheet appears before the system prompt. Without it, the item is copied to the clipboard and you paste manually with ⌘V.
- **Login item** (optional). Only if you enable "Launch at login".

ClipTypeSidebar does **not** request Screen Recording, Microphone, Camera, Contacts or network access, and the code contains no networking. The only outbound action is opening the Ko-fi page in your browser when you click the support button.

## Support ❤️

If this app saves you time, you can support its development:

[Support Or (Leo) Davidai ❤️](https://ko-fi.com/leodavidai)

The app also has a "Support / Donate ❤️" button in the menu bar and in Settings.

## License

MIT © Or Davidai Bachar
