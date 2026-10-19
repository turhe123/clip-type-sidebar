import SwiftUI

/// App entry point: a menu bar extra plus the Settings scene.
@main
struct ClipTypeSidebarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        UserDefaults.standard.register(defaults: [
            "hotKeyCode": 9, "hotKeyMods": 2304, "hotKeyLabel": "⌥⌘V",
            "historySize": 500, "daysToKeep": 30, "pasteBehavior": "paste",
            "ignoredApps": "com.1password.1password\ncom.agilebits.onepassword7\ncom.bitwarden.desktop",
        ])
    }

    var body: some Scene {
        MenuBarExtra("ClipTypeSidebar", systemImage: "sidebar.right") {
            MenuContent()
        }
        Settings { SettingsView() }
    }
}

/// Starts capture, the hotkey, and edge reveal once the app has launched.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            ClipStore.shared.start()
            SidebarController.shared.updateEdgeReveal()
        }
        let d = UserDefaults.standard
        HotKeyManager.shared.action = { MainActor.assumeIsolated { SidebarController.shared.toggle() } }
        HotKeyManager.shared.register(keyCode: d.integer(forKey: "hotKeyCode"), modifiers: d.integer(forKey: "hotKeyMods"))
    }
}

/// Items shown in the menu bar extra's dropdown.
struct MenuContent: View {
    @ObservedObject private var store = ClipStore.shared
    @Environment(\.openSettings) private var openSettings
    @AppStorage("hotKeyLabel") private var hotKeyLabel = "⌥⌘V"

    var body: some View {
        Button("Show Sidebar (\(hotKeyLabel))") { SidebarController.shared.show() }
        Toggle("Pause Capture", isOn: $store.paused)
        Button("Clear History") { store.clear() }
        Divider()
        Button("Settings…") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        .keyboardShortcut(",")
        Button("Support / Donate ❤️") {
            NSWorkspace.shared.open(URL(string: "https://ko-fi.com/leodavidai")!)
        }
        Divider()
        Button("Quit ClipTypeSidebar") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
