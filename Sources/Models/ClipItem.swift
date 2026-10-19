import Foundation

/// The content category a clipboard item was classified into.
enum ClipKind: String, Codable, CaseIterable, Identifiable {
    case text, richText, link, image, color, files

    var id: String { rawValue }

    var label: String {
        switch self {
        case .text: return "Text"
        case .richText: return "Rich Text"
        case .link: return "Links"
        case .image: return "Images"
        case .color: return "Colors"
        case .files: return "Files"
        }
    }

    var symbol: String {
        switch self {
        case .text: return "text.alignleft"
        case .richText: return "textformat"
        case .link: return "link"
        case .image: return "photo"
        case .color: return "paintpalette"
        case .files: return "doc.on.doc"
        }
    }

    /// Whether text transforms can be applied to items of this kind.
    var isTextual: Bool { self == .text || self == .richText || self == .link || self == .color }
}

/// A single recorded clipboard entry; persisted as JSON (images live in separate PNG files).
struct ClipItem: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var kind: ClipKind
    var text: String?
    var rtf: Data?
    var imageFile: String?
    var filePaths: [String]?
    var sourceBundleID: String?
    var sourceName: String?
    var date: Date = Date()
    var pinned: Bool = false

    /// One-line-ish preview used in rows and for search.
    var previewText: String {
        switch kind {
        case .image: return "Image"
        case .files:
            let names = (filePaths ?? []).map { ($0 as NSString).lastPathComponent }
            return names.joined(separator: ", ")
        default: return text ?? ""
        }
    }
}

/// Text transformations offered from a row's context menu.
enum TextTransform: String, CaseIterable, Identifiable {
    case uppercase = "UPPERCASE"
    case lowercase = "lowercase"
    case titleCase = "Title Case"
    case trim = "Trim Whitespace"
    case removeLineBreaks = "Remove Line Breaks"
    case sortLines = "Sort Lines"
    case quote = "Wrap in Quotes"

    var id: String { rawValue }

    func apply(_ s: String) -> String {
        switch self {
        case .uppercase: return s.uppercased()
        case .lowercase: return s.lowercased()
        case .titleCase: return s.capitalized
        case .trim: return s.trimmingCharacters(in: .whitespacesAndNewlines)
        case .removeLineBreaks:
            return s.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        case .sortLines:
            return s.components(separatedBy: .newlines)
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
                .joined(separator: "\n")
        case .quote: return "\"\(s)\""
        }
    }
}
