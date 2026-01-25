import Foundation

enum ExportFormat: String, CaseIterable, Identifiable {
    case json
    case txt
    case html

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .json: return "JSON"
        case .txt: return "Text"
        case .html: return "HTML"
        }
    }

    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .txt: return "txt"
        case .html: return "html"
        }
    }

    var mimeType: String {
        switch self {
        case .json: return "application/json"
        case .txt: return "text/plain"
        case .html: return "text/html"
        }
    }
}

enum ExportHelpers {

    // MARK: - Checklist

    static func checklistText(_ checklist: Checklist) -> String {
        var lines: [String] = []
        lines.append("Checklist: \(checklist.title)")
        lines.append("Vehicle Type: \(checklist.vehicleType.displayName)")
        lines.append("Last Edited: \(ISO8601DateFormatter().string(from: checklist.lastEdited))")
        lines.append("")

        let grouped = Dictionary(grouping: checklist.items, by: { $0.section })
        for section in grouped.keys.sorted() {
            lines.append("== \(section) ==")
            for item in grouped[section] ?? [] {
                lines.append("- [\(symbol(for: item.state))] \(item.title)\(item.note.map { " (\($0))" } ?? "")")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    static func checklistHTML(_ checklist: Checklist) -> String {
        let grouped = Dictionary(grouping: checklist.items, by: { $0.section })

        var body = "<h1>Checklist: \(escape(checklist.title))</h1>"
        body += "<p><strong>Vehicle Type:</strong> \(escape(checklist.vehicleType.displayName))<br/>"
        body += "<strong>Last Edited:</strong> \(escape(ISO8601DateFormatter().string(from: checklist.lastEdited)))</p>"

        for section in grouped.keys.sorted() {
            body += "<h2>\(escape(section))</h2><ul>"
            for item in grouped[section] ?? [] {
                let note = item.note.map { " <em>(\(escape($0)))</em>" } ?? ""
                body += "<li>[\(escape(symbol(for: item.state)))] \(escape(item.title))\(note)</li>"
            }
            body += "</ul>"
        }

        return """
        <!doctype html>
        <html><head><meta charset=\"utf-8\"><title>\(escape(checklist.title))</title></head>
        <body>\(body)</body></html>
        """
    }

    static func checklistJSONData(_ checklist: Checklist) throws -> Data {
        // Encode a simplified shape so we don't rely on SwiftData model encoding.
        struct DTO: Codable {
            struct ItemDTO: Codable {
                var id: UUID
                var section: String
                var title: String
                var state: String
                var note: String?
            }
            var id: UUID
            var title: String
            var vehicleType: String
            var lastEdited: String
            var items: [ItemDTO]
        }

        let dto = DTO(
            id: checklist.id,
            title: checklist.title,
            vehicleType: checklist.vehicleType.rawValue,
            lastEdited: ISO8601DateFormatter().string(from: checklist.lastEdited),
            items: checklist.items.map {
                .init(id: $0.id, section: $0.section, title: $0.title, state: $0.state.rawValue, note: $0.note)
            }
        )

        return try JSONEncoder().encode(dto)
    }

    // MARK: - Helpers

    private static func symbol(for state: ChecklistItemState) -> String {
        switch state {
        case .notSelected: return " "
        case .selected: return "OK"
        case .notApplicable: return "NA"
        case .notOk: return "NO"
        }
    }

    private static func escape(_ s: String) -> String {
        s
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
