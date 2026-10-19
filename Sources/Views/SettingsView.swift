import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers

/// Preferences window: hotkey, edge reveal, retention, ignored apps, paste behavior and login item.
struct SettingsView: View {
    @AppStorage("hotKeyCode") private var hotKeyCode = 9
    @AppStorage("hotKeyMods") private var hotKeyMods = 2304
    @AppStorage("hotKeyLabel") private var hotKeyLabel = "⌥⌘V"
    @AppStorage("edgeReveal") private var edgeReveal = false
    @AppStorage("historySize") private var historySize = 500
    @AppStorage("daysToKeep") private var daysToKeep = 30
    @AppStorage("ignoredApps") private var ignoredApps = ""
    @AppStorage("pasteBehavior") private var pasteBehavior = "paste"
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var recording = false
    @State private var monitor: Any?
    @State private var axTrusted = PasteService.isTrusted
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("Sidebar") {
                LabeledContent("Global hotkey") {
                    Button(recording ? "Press keys…" : hotKeyLabel) { recording ? stopRecording() : startRecording() }
                }
                Toggle("Reveal when pointer touches the right screen edge", isOn: $edgeReveal)
                    .onChange(of: edgeReveal) { SidebarController.shared.updateEdgeReveal() }
            }
            Section("History") {
                Stepper("Keep up to \(historySize) items", value: $historySize, in: 50...500, step: 50)
                Picker("Days to keep", selection: $daysToKeep) {
                    ForEach([1, 7, 30, 90, 365], id: \.self) { Text("\($0) days").tag($0) }
                    Text("Forever").tag(0)
                }
                .onChange(of: historySize) { ClipStore.shared.prune() }
                .onChange(of: daysToKeep) { ClipStore.shared.prune() }
                VStack(alignment: .leading) {
                    Text("Ignored apps (bundle identifiers, one per line)")
                    TextEditor(text: $ignoredApps).font(.system(.caption, design: .monospaced)).frame(height: 70)
                    Button("Add App…", action: addIgnoredApp)
                }
            }
            Section("Pasting") {
                Picker("Return key", selection: $pasteBehavior) {
                    Text("Paste into previous app").tag("paste")
                    Text("Copy to clipboard only").tag("copy")
                }
                LabeledContent("Accessibility") {
                    if axTrusted {
                        Label("Granted", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button("Grant Access…") { PasteService.requestAccess(); PasteService.openAccessibilitySettings() }
                    }
                }
                if !axTrusted {
                    Text("Without Accessibility, items are copied and you paste them manually with ⌘V.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in setLaunchAtLogin(on) }
                if let loginError { Text(loginError).font(.caption).foregroundStyle(.red) }
                Button("Support / Donate ❤️") {
                    NSWorkspace.shared.open(URL(string: "https://ko-fi.com/leodavidai")!)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 620)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in axTrusted = PasteService.isTrusted }
        .onDisappear(perform: stopRecording)
    }

    private func startRecording() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            if event.keyCode == 53 { stopRecording(); return nil }
            guard !flags.isDisjoint(with: [.command, .option, .control]),
                  let chars = event.charactersIgnoringModifiers, !chars.isEmpty else { return nil }
            hotKeyCode = Int(event.keyCode)
            hotKeyMods = HotKeyManager.carbonModifiers(flags)
            hotKeyLabel = HotKeyManager.label(flags, key: chars)
            HotKeyManager.shared.register(keyCode: hotKeyCode, modifiers: hotKeyMods)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
    }

    private func addIgnoredApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url,
              let bid = Bundle(url: url)?.bundleIdentifier else { return }
        let existing = ignoredApps.split(whereSeparator: \.isNewline).map(String.init)
        if !existing.contains(bid) { ignoredApps = (existing + [bid]).joined(separator: "\n") }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Couldn't update login item: \(error.localizedDescription)"
        }
    }
}
