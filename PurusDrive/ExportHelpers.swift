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
}

enum ExportHelpers {

    // MARK: - Checklist

    static func checklistText(_ checklist: Checklist) -> String {
        var lines: [String] = []
        lines.append("Checklist: \(checklist.title)")
        lines.append("Vehicle Type: \(checklist.vehicleType.displayName)")
        lines.append("Last Edited: \(ISO8601DateFormatter().string(from: checklist.lastEdited))")
        lines.append("")

        let grouped = Dictionary(grouping: checklist.items ?? [], by: { $0.section })
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
        let grouped = Dictionary(grouping: checklist.items ?? [], by: { $0.section })

        // a fragment: it is embedded in the export page, which owns <html>/<body>
        var body = "<h3>Checklist: \(escape(checklist.title))</h3>"
        body += "<p><strong>Vehicle Type:</strong> \(escape(checklist.vehicleType.displayName))<br/>"
        body += "<strong>Last Edited:</strong> \(escape(ISO8601DateFormatter().string(from: checklist.lastEdited)))</p>"

        for section in grouped.keys.sorted() {
            body += "<h4>\(escape(section))</h4><ul>"
            for item in grouped[section] ?? [] {
                let note = item.note.map { " <em>(\(escape($0)))</em>" } ?? ""
                body += "<li>[\(escape(symbol(for: item.state)))] \(escape(item.title))\(note)</li>"
            }
            body += "</ul>"
        }

        return body
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
