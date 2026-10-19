import SwiftUI

/// Root view of the sidebar panel: search field, type chips, and the history list.
struct SidebarView: View {
    @EnvironmentObject var controller: SidebarController
    @EnvironmentObject var store: ClipStore
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search history", text: $controller.search)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                if store.paused {
                    Label("Paused", systemImage: "pause.circle.fill").labelStyle(.iconOnly).foregroundStyle(.orange)
                        .help("Capture is paused")
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))

            chips
            Divider()
            list
            if let notice = controller.notice {
                Label(notice, systemImage: "doc.on.clipboard")
                    .font(.callout)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.18)))
            }
        }
        .padding(12)
        .frame(width: SidebarController.width)
        .frame(maxHeight: .infinity)
        .background(.regularMaterial)
        .overlay { if controller.showAccessibilitySheet { AccessibilitySheet() } }
        .onAppear { searchFocused = true }
        .onChange(of: controller.filter) { controller.selectedID = controller.visibleItems.first?.id }
        .onChange(of: controller.search) { controller.selectedID = controller.visibleItems.first?.id }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip("All", symbol: "tray.full", kind: nil)
                ForEach(ClipKind.allCases) { chip($0.label, symbol: $0.symbol, kind: $0) }
            }
        }
    }

    private func chip(_ title: String, symbol: String, kind: ClipKind?) -> some View {
        let active = controller.filter == kind
        return Button { controller.filter = kind } label: {
            Label(title, systemImage: symbol)
                .font(.caption)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Capsule().fill(active ? Color.accentColor : Color.secondary.opacity(0.15)))
                .foregroundStyle(active ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var list: some View {
        let items = controller.visibleItems
        if store.items.isEmpty {
            emptyState("Copy something to start your history", symbol: "doc.on.clipboard")
        } else if items.isEmpty {
            emptyState(controller.search.isEmpty ? "No \(controller.filter?.label ?? "") items yet" : "No matches",
                       symbol: controller.filter?.symbol ?? "magnifyingglass")
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(items) { item in
                            ClipRow(item: item, selected: item.id == controller.selectedID).id(item.id)
                        }
                    }
                }
                .onChange(of: controller.selectedID) { _, id in
                    if let id { withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo(id) } }
                }
            }
        }
    }

    private func emptyState(_ text: String, symbol: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.largeTitle).foregroundStyle(.tertiary)
            Text(text).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A single history row: preview, source app icon, relative time, and context menu actions.
struct ClipRow: View {
    let item: ClipItem
    let selected: Bool
    @EnvironmentObject var controller: SidebarController
    @EnvironmentObject var store: ClipStore

    private var filesMissing: Bool {
        guard item.kind == .files, let paths = item.filePaths else { return false }
        return !paths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            preview.frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.previewText.trimmingCharacters(in: .whitespacesAndNewlines))
                    .lineLimit(item.kind == .image ? 1 : 3)
                    .font(.system(size: 12, design: item.kind == .color ? .monospaced : .default))
                    .strikethrough(filesMissing)
                HStack(spacing: 4) {
                    if let icon = store.appIcon(item.sourceBundleID) {
                        Image(nsImage: icon).resizable().frame(width: 12, height: 12)
                    }
                    Text(item.sourceName ?? "Unknown")
                    Text("·")
                    Text(item.date.formatted(.relative(presentation: .named)))
                    if filesMissing { Text("· missing") }
                }
                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            if item.pinned { Image(systemName: "pin.fill").font(.caption).foregroundStyle(.orange) }
        }
        .padding(8)
        .opacity(filesMissing ? 0.45 : 1)
        .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Color.accentColor.opacity(0.25) : Color.clear))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { controller.paste(item, plain: false) }
        .onTapGesture { controller.selectedID = item.id }
        .contextMenu { menu }
    }

    @ViewBuilder private var preview: some View {
        switch item.kind {
        case .image:
            if let thumb = store.thumbnail(for: item) {
                Image(nsImage: thumb).resizable().scaledToFill()
                    .frame(width: 40, height: 40).clipShape(RoundedRectangle(cornerRadius: 6))
            } else { kindIcon }
        case .color:
            RoundedRectangle(cornerRadius: 6).fill(Color(hex: item.text ?? "") ?? .gray)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.secondary.opacity(0.4)))
        default: kindIcon
        }
    }

    private var kindIcon: some View {
        Image(systemName: item.kind.symbol)
            .frame(width: 40, height: 40)
            .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary))
    }

    @ViewBuilder private var menu: some View {
        Button("Paste") { controller.paste(item, plain: false) }
        Button("Paste as Plain Text") { controller.paste(item, plain: true) }
        Button(item.pinned ? "Unpin" : "Pin") { store.togglePin(item.id) }
        if item.kind.isTextual {
            Menu("Transform") {
                ForEach(TextTransform.allCases) { t in Button(t.rawValue) { store.transform(item.id, with: t) } }
            }
        }
        if item.kind == .link, let url = URL(string: item.text ?? "") {
            Button("Open Link") { NSWorkspace.shared.open(url) }
        }
        if item.kind == .files, let first = item.filePaths?.first, !filesMissing {
            Button("Reveal in Finder") { NSWorkspace.shared.selectFile(first, inFileViewerRootedAtPath: "") }
        }
        Divider()
        Button("Delete", role: .destructive) { controller.removeSelected(item.id) }
    }
}

/// Explains why Accessibility access is needed before prompting for it.
struct AccessibilitySheet: View {
    @EnvironmentObject var controller: SidebarController

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
            VStack(spacing: 12) {
                Image(systemName: "accessibility").font(.largeTitle).foregroundStyle(Color.accentColor)
                Text("Allow Paste-Back").font(.headline)
                Text("To paste directly into the app you were using, ClipTypeSidebar sends ⌘V on your behalf. macOS requires Accessibility access for that.\n\nUntil then, items are copied and you can paste them manually with ⌘V.")
                    .font(.callout).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Not Now") { controller.dismissAccessibilitySheet() }
                    Button("Grant Access") {
                        controller.dismissAccessibilitySheet()
                        PasteService.requestAccess()
                        PasteService.openAccessibilitySettings()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 12).fill(.background))
            .padding(20)
        }
    }
}

extension Color {
    /// Parses #RGB, #RRGGBB or #RRGGBBAA hex strings.
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespaces)
        if h.hasPrefix("#") { h.removeFirst() }
        if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
        guard h.count == 6 || h.count == 8, let v = UInt64(h, radix: 16) else { return nil }
        let rgb = h.count == 8 ? v >> 8 : v
        let a = h.count == 8 ? Double(v & 0xFF) / 255 : 1
        self.init(.sRGB, red: Double((rgb >> 16) & 0xFF) / 255, green: Double((rgb >> 8) & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255, opacity: a)
    }
}
