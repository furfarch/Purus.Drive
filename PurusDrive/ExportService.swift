import Foundation
import SwiftData

enum ExportService {

    static func exportData(scope: ExportScope, format: ExportFormat, vehicles: [Vehicle], trailers: [Trailer], logs: [DriveLog], checklists: [Checklist], workBlocks: [WorkBlock] = []) throws -> (fileName: String, data: Data) {
        let workBlocks = workBlocks.sorted { $0.start < $1.start }
        switch format {
        case .json:
            let data = try jsonExport(scope: scope, vehicles: vehicles, trailers: trailers, logs: logs, checklists: checklists, workBlocks: workBlocks)
            return (fileName(scope: scope, ext: format.fileExtension), data)
        case .txt:
            let text = textExport(scope: scope, vehicles: vehicles, trailers: trailers, logs: logs, checklists: checklists, workBlocks: workBlocks)
            return (fileName(scope: scope, ext: format.fileExtension), Data(text.utf8))
        case .html:
            let html = htmlExport(scope: scope, vehicles: vehicles, trailers: trailers, logs: logs, checklists: checklists, workBlocks: workBlocks)
            return (fileName(scope: scope, ext: format.fileExtension), Data(html.utf8))
        }
    }

    // MARK: - JSON

    private static func jsonExport(scope: ExportScope, vehicles: [Vehicle], trailers: [Trailer], logs: [DriveLog], checklists: [Checklist], workBlocks: [WorkBlock]) throws -> Data {
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
                vehicleID: l.vehicle?.id,
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
                vehicleID: c.vehicle?.id,
                trailerID: c.trailer?.id,
                vehicleType: c.vehicleType.rawValue,
                title: c.title,
                lastEditedISO8601: iso.string(from: c.lastEdited),
                items: (c.items ?? []).map { .init(id: $0.id, section: $0.section, title: $0.title, state: $0.state.rawValue, note: $0.note) }
            )
        }

        func blockDTO(_ b: WorkBlock) -> ExportPayload.WorkBlockDTO {
            .init(id: b.id, activity: b.activity.rawValue, startISO8601: iso.string(from: b.start), endISO8601: b.end.map { iso.string(from: $0) },
                  vehiclePlate: b.vehiclePlate, vehicleName: b.vehicleName, kmStart: b.kmStart, kmEnd: b.kmEnd,
                  placeStart: b.placeStart, placeEnd: b.placeEnd, exception: b.exception, note: b.note,
                  lastEditedISO8601: iso.string(from: b.lastEdited))
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
            payload.workBlocks = workBlocks.map(blockDTO)
        case .workTime:
            payload.workBlocks = workBlocks.map(blockDTO)
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

    private static func blockLine(_ b: WorkBlock) -> String {
        var parts = ["\(b.start.formatted(date: .abbreviated, time: .shortened))–\(b.end?.formatted(date: .omitted, time: .shortened) ?? "running")", b.activity.title]
        if !b.vehiclePlate.isEmpty { parts.append(b.vehiclePlate) }
        if let k = b.kmStart { parts.append("km \(k)–\(b.kmEnd.map(String.init) ?? "")") }
        let place = [b.placeStart, b.placeEnd].filter { !$0.isEmpty }.joined(separator: " → ")
        if !place.isEmpty { parts.append(place) }
        if b.exception { parts.append("Art. 12 exception") }
        if !b.note.isEmpty { parts.append(b.note) }
        return parts.joined(separator: " • ")
    }

    private static func textExport(scope: ExportScope, vehicles: [Vehicle], trailers: [Trailer], logs: [DriveLog], checklists: [Checklist], workBlocks: [WorkBlock]) -> String {
        var lines: [String] = []
        lines.append("Export: \(scope.title)")
        lines.append("Generated: \(Date().formatted(date: .abbreviated, time: .standard))")
        lines.append("")

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

        if scope == .all || scope == .workTime {
            lines.append("")
            lines.append("WORK TIME")
            for b in workBlocks { lines.append("- " + blockLine(b)) }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - HTML

    private static func htmlExport(scope: ExportScope, vehicles: [Vehicle], trailers: [Trailer], logs: [DriveLog], checklists: [Checklist], workBlocks: [WorkBlock]) -> String {
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

        if scope == .all || scope == .workTime {
            body += "<h2>Work time</h2><ul>" + workBlocks.map { "<li>\(escape(blockLine($0)))</li>" }.joined() + "</ul>"
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
        return "purusdrive_export_\(scope.rawValue)_\(df.string(from: .now)).\(ext)"
    }

    private static func escape(_ s: String) -> String {
        s
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
