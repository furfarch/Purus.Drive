import Foundation
import SwiftData

enum ExportService {

    static func exportData(scope: ExportScope, format: ExportFormat, vehicles: [Vehicle], trailers: [Trailer], logs: [DriveLog], checklists: [Checklist]) throws -> (fileName: String, data: Data) {
        switch format {
        case .json:
            let data = try jsonExport(scope: scope, vehicles: vehicles, trailers: trailers, logs: logs, checklists: checklists)
            return (fileName(scope: scope, ext: format.fileExtension), data)
        case .txt:
            let text = textExport(scope: scope, vehicles: vehicles, trailers: trailers, logs: logs, checklists: checklists)
            return (fileName(scope: scope, ext: format.fileExtension), Data(text.utf8))
        case .html:
            let html = htmlExport(scope: scope, vehicles: vehicles, trailers: trailers, logs: logs, checklists: checklists)
            return (fileName(scope: scope, ext: format.fileExtension), Data(html.utf8))
        }
    }

    // MARK: - JSON

    private static func jsonExport(scope: ExportScope, vehicles: [Vehicle], trailers: [Trailer], logs: [DriveLog], checklists: [Checklist]) throws -> Data {
        let iso = ISO8601DateFormatter()

        func vehicleDTO(_ v: Vehicle) -> ExportPayload.VehicleDTO {
            .init(
                id: v.id,
                type: v.type.rawValue,
                brandModel: v.brandModel,
                color: v.color,
                plate: v.plate,
                notes: v.notes,
                trailerID: v.trailer?.id,
                lastEditedISO8601: iso.string(from: v.lastEdited)
            )
        }

        func trailerDTO(_ t: Trailer) -> ExportPayload.TrailerDTO {
            .init(
                id: t.id,
                brandModel: t.brandModel,
                color: t.color,
                plate: t.plate,
                notes: t.notes,
                lastEditedISO8601: iso.string(from: t.lastEdited)
            )
        }

        func logDTO(_ l: DriveLog) -> ExportPayload.DriveLogDTO {
            .init(
                id: l.id,
                vehicleID: l.vehicle?.id ?? UUID(),
                dateISO8601: iso.string(from: l.date),
                reason: l.reason,
                kmStart: l.kmStart,
                kmEnd: l.kmEnd,
                notes: l.notes,
                checklistID: l.checklist?.id,
                usedChecklist: nil,
                lastEditedISO8601: iso.string(from: l.lastEdited)
            )
        }

        func checklistDTO(_ c: Checklist) -> ExportPayload.ChecklistDTO {
            .init(
                id: c.id,
                vehicleID: nil,
                vehicleType: c.vehicleType.rawValue,
                title: c.title,
                lastEditedISO8601: iso.string(from: c.lastEdited),
                items: c.items.map { .init(id: $0.id, section: $0.section, title: $0.title, state: $0.state.rawValue, note: $0.note) }
            )
        }

        var payload = ExportPayload(
            generatedAtISO8601: iso.string(from: .now),
            scope: scope.rawValue,
            vehicles: nil,
            trailers: nil,
            driveLogs: nil,
            checklists: nil
        )

        switch scope {
        case .all:
            payload.vehicles = vehicles.map(vehicleDTO)
            payload.trailers = trailers.map(trailerDTO)
            payload.driveLogs = logs.map(logDTO)
            payload.checklists = checklists.map(checklistDTO)
        case .vehicles:
            payload.vehicles = vehicles.map(vehicleDTO)
            payload.trailers = trailers.map(trailerDTO)
        case .logs:
            payload.driveLogs = logs.map(logDTO)
            // include minimal vehicle info
            payload.vehicles = vehicles.map(vehicleDTO)
            payload.trailers = trailers.map(trailerDTO)
        case .checklists:
            payload.checklists = checklists.map(checklistDTO)
            payload.vehicles = vehicles.map(vehicleDTO)
            payload.trailers = trailers.map(trailerDTO)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    // MARK: - TXT

    private static func textExport(scope: ExportScope, vehicles: [Vehicle], trailers: [Trailer], logs: [DriveLog], checklists: [Checklist]) -> String {
        var lines: [String] = []
        lines.append("Export: \(scope.title)")
        lines.append("Generated: \(Date().formatted(date: .abbreviated, time: .standard))")
        lines.append("")

        switch scope {
        case .all, .vehicles, .logs, .checklists:
            if scope == .all || scope == .vehicles || scope == .logs || scope == .checklists {
                lines.append("VEHICLES")
                for v in vehicles {
                    lines.append("- [\(v.type.displayName)] \(v.brandModel) \(v.plate)")
                    if let t = v.trailer {
                        lines.append("    trailer: \(t.brandModel) \(t.plate)")
                    }
                }
                lines.append("\nTRAILERS")
                for t in trailers {
                    lines.append("- \(t.brandModel) \(t.plate)")
                }
                lines.append("")
            }

            if scope == .all || scope == .logs {
                lines.append("DRIVE LOGS")
                for l in logs {
                    let vehicleText: String
                    if let v = l.vehicle {
                        vehicleText = "\(v.brandModel) \(v.plate)"
                    } else {
                        vehicleText = "(no vehicle)"
                    }
                    lines.append("- \(l.date.formatted(date: .abbreviated, time: .shortened)) • \(vehicleText) • \(l.reason)")
                }
                lines.append("")
            }

            if scope == .all || scope == .checklists {
                lines.append("CHECKLISTS")
                for c in checklists {
                    lines.append("- \(c.title) • \(c.vehicleType.displayName)")
                    lines.append(ExportHelpers.checklistText(c))
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - HTML

    private static func htmlExport(scope: ExportScope, vehicles: [Vehicle], trailers: [Trailer], logs: [DriveLog], checklists: [Checklist]) -> String {
        var body = "<h1>Export: \(escape(scope.title))</h1>"
        body += "<p><strong>Generated:</strong> \(escape(Date().formatted(date: .abbreviated, time: .standard)))</p>"

        body += "<h2>Vehicles</h2><ul>"
        for v in vehicles {
            body += "<li>[\(escape(v.type.displayName))] \(escape(v.brandModel)) \(escape(v.plate))"
            if let t = v.trailer {
                body += "<br/><em>Trailer:</em> \(escape(t.brandModel)) \(escape(t.plate))"
            }
            body += "</li>"
        }
        body += "</ul>"

        body += "<h2>Trailers</h2><ul>"
        for t in trailers {
            body += "<li>\(escape(t.brandModel)) \(escape(t.plate))</li>"
        }
        body += "</ul>"

        if scope == .all || scope == .logs {
            body += "<h2>Drive Logs</h2><ul>"
            for l in logs {
                let vehicleText: String
                if let v = l.vehicle {
                    vehicleText = "\(escape(v.brandModel)) \(escape(v.plate))"
                } else {
                    vehicleText = "(no vehicle)"
                }
                body += "<li>\(escape(l.date.formatted(date: .abbreviated, time: .shortened))) • \(vehicleText) • \(escape(l.reason))</li>"
            }
            body += "</ul>"
        }

        if scope == .all || scope == .checklists {
            body += "<h2>Checklists</h2>"
            for c in checklists {
                body += ExportHelpers.checklistHTML(c)
            }
        }

        return """
        <!doctype html>
        <html><head><meta charset=\"utf-8\"><title>Export</title></head>
        <body>\(body)</body></html>
        """
    }

    private static func fileName(scope: ExportScope, ext: String) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmmss"
        return "simplydrive_export_\(scope.rawValue)_\(df.string(from: .now)).\(ext)"
    }

    private static func escape(_ s: String) -> String {
        s
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
