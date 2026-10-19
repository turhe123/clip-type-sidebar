import AppKit
import SwiftUI

/// Borderless, non-activating panel that can take keyboard focus without activating the app.
final class SidebarPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .statusBar
        isFloatingPanel = true
        hidesOnDeactivate = false
        hasShadow = true
        isOpaque = false
        backgroundColor = .clear
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Shows/hides the sidebar, owns its UI state, keyboard handling, edge reveal and paste-back.
@MainActor
final class SidebarController: ObservableObject {
    static let shared = SidebarController()
    static let width: CGFloat = 340

    @Published var search = ""
    @Published var filter: ClipKind?
    @Published var selectedID: UUID?
    @Published var notice: String?
    @Published var showAccessibilitySheet = false
    @Published private(set) var isVisible = false

    private let store = ClipStore.shared
    private lazy var panel: SidebarPanel = {
        let p = SidebarPanel()
        p.contentView = NSHostingView(rootView: SidebarView().environmentObject(self).environmentObject(store))
        return p
    }()
    private var previousApp: NSRunningApplication?
    private var keyMonitor: Any?
    private var edgeTimer: Timer?
    private var edgeDwell = 0
    private var revealedByEdge = false

    var visibleItems: [ClipItem] {
        store.items.filter { item in
            (filter == nil || item.kind == filter)
                && (search.isEmpty || item.previewText.localizedCaseInsensitiveContains(search)
                    || (item.sourceName ?? "").localizedCaseInsensitiveContains(search))
        }
    }

    private init() {
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: nil, queue: .main) { [weak self] note in
            MainActor.assumeIsolated {
                guard let self, let win = note.object as? NSWindow, win === self.panel, self.isVisible else { return }
                if !self.showAccessibilitySheet { self.hide() }
            }
        }
    }

    // MARK: Show / hide

    func toggle() { isVisible ? hide() : show() }

    func show(fromEdge: Bool = false) {
        guard !isVisible else { return }
        let front = NSWorkspace.shared.frontmostApplication
        if front?.bundleIdentifier != Bundle.main.bundleIdentifier { previousApp = front }
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else { return }
        let vf = screen.visibleFrame
        let target = NSRect(x: vf.maxX - Self.width, y: vf.minY, width: Self.width, height: vf.height)
        panel.setFrame(target.offsetBy(dx: Self.width, dy: 0), display: false)
        isVisible = true
        revealedByEdge = fromEdge
        selectedID = visibleItems.first?.id
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            panel.animator().setFrame(target, display: true)
        }
        installKeyMonitor()
    }

    func hide() {
        guard isVisible else { return }
        isVisible = false
        showAccessibilitySheet = false
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        let out = panel.frame.offsetBy(dx: Self.width, dy: 0)
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            panel.animator().setFrame(out, display: true)
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.isVisible else { return }
                self.panel.orderOut(nil)
            }
        })
    }

    // MARK: Keyboard

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let (code, flags, number) = (event.keyCode, event.modifierFlags, event.windowNumber)
            let handled = MainActor.assumeIsolated {
                guard let self, number == self.panel.windowNumber else { return false }
                return self.handleKey(code: code, flags: flags)
            }
            return handled ? nil : event
        }
    }

    private func handleKey(code: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        let cmd = flags.contains(.command)
        switch code {
        case 125: moveSelection(1); return true
        case 126: moveSelection(-1); return true
        case 53:
            if showAccessibilitySheet { dismissAccessibilitySheet() } else { hide() }
            return true
        case 36, 76:
            if let item = selectedItem { paste(item, plain: flags.contains(.shift)) }
            return true
        case 51 where cmd:
            if let id = selectedID { removeSelected(id) }
            return true
        case 35 where cmd:
            if let id = selectedID { store.togglePin(id) }
            return true
        default: return false
        }
    }

    var selectedItem: ClipItem? { visibleItems.first { $0.id == selectedID } }

    private func moveSelection(_ delta: Int) {
        let list = visibleItems
        guard !list.isEmpty else { return }
        let idx = list.firstIndex { $0.id == selectedID } ?? -delta
        selectedID = list[min(max(idx + delta, 0), list.count - 1)].id
    }

    func removeSelected(_ id: UUID) {
        let list = visibleItems
        if let idx = list.firstIndex(where: { $0.id == id }) {
            let next = idx + 1 < list.count ? list[idx + 1] : (idx > 0 ? list[idx - 1] : nil)
            selectedID = next?.id
        }
        store.remove(id)
    }

    // MARK: Paste

    func paste(_ item: ClipItem, plain: Bool) {
        store.copyToPasteboard(item, plain: plain)
        if UserDefaults.standard.string(forKey: "pasteBehavior") == "copy" {
            hide()
            return
        }
        guard PasteService.isTrusted else {
            flash("Copied — ready to paste manually with ⌘V")
            if !UserDefaults.standard.bool(forKey: "axExplained") { showAccessibilitySheet = true }
            return
        }
        hide()
        previousApp?.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { PasteService.sendCommandV() }
    }

    func dismissAccessibilitySheet() {
        UserDefaults.standard.set(true, forKey: "axExplained")
        showAccessibilitySheet = false
    }

    func flash(_ message: String) {
        notice = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            if self?.notice == message { self?.notice = nil }
        }
    }

    // MARK: Edge reveal

    func updateEdgeReveal() {
        edgeTimer?.invalidate()
        edgeTimer = nil
        guard UserDefaults.standard.bool(forKey: "edgeReveal") else { return }
        edgeTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkEdge() }
        }
    }

    private func checkEdge() {
        let mouse = NSEvent.mouseLocation
        if isVisible {
            if revealedByEdge, mouse.x < panel.frame.minX - 60 { hide() }
            return
        }
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) else { return }
        edgeDwell = mouse.x >= screen.frame.maxX - 2 ? edgeDwell + 1 : 0
        if edgeDwell >= 2 { edgeDwell = 0; show(fromEdge: true) }
    }
}
