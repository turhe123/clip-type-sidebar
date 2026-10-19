# ClipTypeSidebar — specification

**Tagline:** A docked clipboard sidebar that sorts history into text, links, images, colors and files with text transforms.

**Category:** Clipboard

**Inspired by (paid):** PastePal (about $14.99 one-time Pro)

**Frameworks:** SwiftUI, AppKit, UniformTypeIdentifiers, ServiceManagement

**Donation URL (Support button):** https://ko-fi.com/leodavidai

## Spec

What the paid app does: PastePal is a Mac App Store clipboard manager that shows history in a side panel with automatic categories, collections for saved items, a queue mode and text transformations, unlocked by a one-time Pro purchase. Review sites such as CleanClip and Paste comparison posts list it among the main one-time-purchase clipboard managers, and its App Store listing carries strong ratings. Our clean-room version differs from a bottom strip by focusing on a vertical sidebar with type filters and in-place transforms.

Feature set: Poll the general pasteboard change count every half second and record each new item with its type: plain text, rich text, link, image, color string, file list. Keep up to 500 items, with image data saved as PNG files in Application Support and metadata in a JSON file. A sidebar panel slides in from the right screen edge by hotkey or by moving the pointer to the edge when enabled. A row of type filter chips filters the list. Each row shows a preview, source app icon and time. Return pastes the selected item into the previous app, Shift Return pastes as plain text. A context menu applies transforms to text: uppercase, lowercase, title case, trim whitespace, remove line breaks, sort lines, and wrap in quotes. Pin items to keep them from expiring. Around 550 lines.

UI spec: MenuBarExtra with Show Sidebar, Pause Capture, Clear History, Settings, Quit. The sidebar is a 340 point wide borderless panel full height of the visible screen, with a search field on top, type chips below, then the list. Settings fields: global hotkey, edge reveal toggle, history size, days to keep, ignored apps list, paste behavior, launch at login. Empty states: an empty history shows a hint to copy something, and a filter with no items shows the filter name with no items yet. Keyboard: up and down move selection, Command Delete removes, Command P pins, Escape closes.

Technical approach: NSPasteboard changeCount polling on a timer, reading types with UniformTypeIdentifiers conformance checks to classify content. Link detection uses NSDataDetector. Color detection uses a regular expression for hex codes. The source app comes from NSWorkspace frontmostApplication at capture time. Respect the concealed and transient pasteboard type markers used by password managers by skipping those items. The panel is an NSPanel with nonactivating style hosting SwiftUI. Paste back by setting the pasteboard and sending Command V through CGEvent, which requires Accessibility granted on demand with an explanation sheet. The hotkey uses Carbon. Settings use AppStorage. Launch at login uses SMAppService.

Edge cases: Avoid recording items the app itself writes by remembering the change count after its own write. Limit image size stored and downscale thumbnails. Remove orphaned image files when items expire. Handle file lists whose files were deleted by showing a dimmed row. Pause polling during sleep. If the user disables Accessibility, fall back to copying the item and showing a small notice that it is ready to paste manually.
