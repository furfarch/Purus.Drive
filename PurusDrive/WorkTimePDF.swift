import SwiftUI
import UIKit

/// Week sheet (like the tachograph sheet / booklet week) and month summary (ARV 1 Art. 16) as A4 PDF.
@MainActor
enum WorkTimePDF {

    static func week(containing ref: Date, blocks: [WorkBlock], now: Date = .now) -> (String, Data) {
        let cal = Calendar.current
        let r = WorkLog.report(blocks, now: now)
        let ws = WorkTimeRules.startOfWeek(ref, cal)
        let we = cal.date(byAdding: .day, value: 7, to: ws)!
        let shifts = r.shifts.filter { $0.start >= ws && $0.start < we }
        let wkNo = cal.component(.weekOfYear, from: ws)

        var html = header("Work time — week \(wkNo)", "\(d(ws)) – \(d(we.addingTimeInterval(-1)))")
        html += "<h2>Days</h2><table><tr><th>Day</th><th>Start–end</th><th>Vehicle</th><th>Km</th><th>Places</th><th>Driving</th><th>Work</th><th>Standby</th><th>Breaks</th><th>Rest after</th></tr>"
        for s in shifts {
            let bs = blocksIn(s, blocks)
            let drives = bs.filter { $0.activity == .driving }
            let plates = Array(NSOrderedSet(array: drives.map(\.vehiclePlate).filter { !$0.isEmpty })) as? [String] ?? []
            let kms = drives.compactMap(\.kmStart).min().map { a in "\(a)–\(drives.compactMap(\.kmEnd).max().map(String.init) ?? "")" } ?? ""
            let places = [bs.first?.placeStart ?? "", bs.last(where: { !$0.placeEnd.isEmpty })?.placeEnd ?? ""].filter { !$0.isEmpty }.joined(separator: " → ")
            html += "<tr><td>\(day(s.start))</td><td>\(t(s.start))–\(t(s.end))</td><td>\(e(plates.joined(separator: ", ")))</td><td>\(kms)</td><td>\(e(places))</td><td>\(dur(s.driving))</td><td>\(dur(s.work))</td><td>\(dur(s.standby))</td><td>\(dur(s.breaks))</td><td>\(rest(s.restAfter))</td></tr>"
        }
        html += "</table>"

        html += "<h2>Activities</h2><table><tr><th>Date</th><th>From</th><th>To</th><th>Activity</th><th>Vehicle</th><th>Km</th><th>Place</th><th>Note</th></tr>"
        for b in blocks.filter({ $0.start >= ws && $0.start < we }).sorted(by: { $0.start < $1.start }) {
            let km = b.kmStart.map { "\($0)–\(b.kmEnd.map(String.init) ?? "")" } ?? ""
            let place = [b.placeStart, b.placeEnd].filter { !$0.isEmpty }.joined(separator: " → ")
            let note = (b.exception ? "Art. 12 exception. " : "") + b.note
            html += "<tr><td>\(day(b.start))</td><td>\(t(b.start))</td><td>\(b.end.map(t) ?? "running")</td><td>\(b.activity.title)</td><td>\(e(b.vehiclePlate))</td><td>\(km)</td><td>\(e(place))</td><td>\(e(note))</td></tr>"
        }
        html += "</table>"

        if let i = r.weeks.firstIndex(where: { $0.start == ws }) {
            let w = r.weeks[i]
            let two = w.driving + (i > 0 ? r.weeks[i - 1].driving : 0)
            html += "<h2>Week totals</h2><table><tr><th>Driving</th><th>Driving 2 weeks</th><th>Work</th><th>Standby</th><th>26-week average work</th></tr>"
            html += "<tr><td>\(dur(w.driving)) (max 56 h)</td><td>\(dur(two)) (max 90 h)</td><td>\(dur(w.work)) (max 60 h)</td><td>\(dur(w.standby))</td><td>\(dur(w.average26)) (max 48 h)</td></tr></table>"
        }
        html += findings(r.findings.filter { $0.date >= ws && $0.date < we })
        html += "<p class=sig>Date: ____________________ &nbsp; Signature: ______________________________</p>"
        return ("worktime_week_\(cal.component(.yearForWeekOfYear, from: ws))-\(String(format: "%02d", wkNo)).pdf", render(html))
    }

    static func month(containing ref: Date, blocks: [WorkBlock], now: Date = .now) -> (String, Data) {
        let cal = Calendar.current
        let r = WorkLog.report(blocks, now: now)
        let ms = cal.dateInterval(of: .month, for: ref)!
        let shifts = r.shifts.filter { ms.contains($0.start) }

        var html = header("Work time — \(ms.start.formatted(.dateTime.month(.wide).year()))", "Summary of driving, work and rest times (ARV 1 Art. 16)")
        html += "<h2>Days</h2><table><tr><th>Day</th><th>Start–end</th><th>Driving</th><th>Standby</th><th>Daily rest after</th><th>Split: first part</th></tr>"
        for s in shifts {
            html += "<tr><td>\(day(s.start))</td><td>\(t(s.start))–\(t(s.end))</td><td>\(dur(s.driving))</td><td>\(dur(s.standby))</td><td>\(rest(s.restAfter))</td><td>\(s.splitPart.map(dur) ?? "")</td></tr>"
        }
        html += "</table>"

        html += "<h2>Weeks</h2><table><tr><th>Week</th><th>Driving</th><th>Work</th><th>26-week average</th><th>Weekly rests</th></tr>"
        for w in r.weeks where w.start < ms.end && cal.date(byAdding: .day, value: 7, to: w.start)! > ms.start {
            let we = cal.date(byAdding: .day, value: 7, to: w.start)!
            let weekly = r.shifts.compactMap(\.restAfter).filter { $0.hours >= 24 && $0.start >= w.start && $0.start < we }
                .map { "\(d($0.start)) \(dur($0.end.timeIntervalSince($0.start)))\($0.hours < 45 && !$0.ongoing ? " (reduced)" : "")" }
            html += "<tr><td>\(cal.component(.weekOfYear, from: w.start)) · \(d(w.start))</td><td>\(dur(w.driving))</td><td>\(dur(w.work))</td><td>\(dur(w.average26))</td><td>\(weekly.joined(separator: "<br>"))</td></tr>"
        }
        html += "</table>"
        html += findings(r.findings.filter { ms.contains($0.date) })
        html += "<p class=sig>Date: ____________________ &nbsp; Signature: ______________________________</p>"
        let f = DateFormatter(); f.dateFormat = "yyyy-MM"
        return ("worktime_month_\(f.string(from: ms.start)).pdf", render(html))
    }

    // MARK: - Helpers

    private static func blocksIn(_ s: WorkTimeRules.Shift, _ blocks: [WorkBlock]) -> [WorkBlock] {
        blocks.filter { $0.activity.isActive && $0.start >= s.start && $0.start <= s.end }.sorted { $0.start < $1.start }
    }

    private static func rest(_ r: WorkTimeRules.Rest?) -> String {
        guard let r else { return "" }
        return r.ongoing ? "since \(t(r.start))" : "\(dur(r.end.timeIntervalSince(r.start))) \(r.kind?.rawValue ?? "")"
    }

    private static func findings(_ list: [WorkTimeRules.Finding]) -> String {
        guard !list.isEmpty else { return "<h2>Checks</h2><p>No issues found.</p>" }
        return "<h2>Checks</h2><ul>" + list.sorted { $0.date < $1.date }.map {
            "<li class=\($0.severe ? "bad" : "warn")>\(day($0.date)) \(t($0.date)): \(e($0.text)) (ARV 1 \($0.article))</li>"
        }.joined() + "</ul>"
    }

    private static func header(_ title: String, _ sub: String) -> String {
        """
        <html><head><meta charset="utf-8"><style>
        body{font-family:-apple-system,Helvetica;font-size:9pt;color:#111}
        h1{font-size:15pt;margin:0}h2{font-size:11pt;margin:14px 0 4px}
        .sub{color:#555;margin:2px 0 8px}
        table{border-collapse:collapse;width:100%}th,td{border:1px solid #bbb;padding:3px 4px;text-align:left;vertical-align:top}
        th{background:#eee}.bad{color:#b00}.warn{color:#b60}.sig{margin-top:28px}
        </style></head><body><h1>\(e(title))</h1><p class=sub>\(e(sub)) · Purus Drive · personal record, not an official ARV document</p>
        """
    }

    private static func render(_ body: String) -> Data {
        let html = body + "</body></html>"
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(UIMarkupTextPrintFormatter(markupText: html), startingAtPageAt: 0)
        let a4 = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        renderer.setValue(a4, forKey: "paperRect")
        renderer.setValue(a4.insetBy(dx: 32, dy: 36), forKey: "printableRect")
        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, a4, nil)
        for i in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
        }
        UIGraphicsEndPDFContext()
        return data as Data
    }

    private static func dur(_ x: TimeInterval) -> String { WorkTimeRules.dur(x) }
    private static func t(_ x: Date) -> String { x.formatted(date: .omitted, time: .shortened) }
    private static func d(_ x: Date) -> String { x.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year()) }
    private static func day(_ x: Date) -> String { x.formatted(.dateTime.weekday(.abbreviated).day(.twoDigits).month(.twoDigits)) }
    private static func e(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
    }
}

struct WorkExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let blocks: [WorkBlock]

    enum Kind: String, CaseIterable, Identifiable { case week = "Week sheet", month = "Month summary"; var id: String { rawValue } }
    @State private var kind = Kind.week
    @State private var date = Date.now
    struct SharedFile: Identifiable { let id = UUID(); let url: URL }
    @State private var file: SharedFile?
    @State private var error: String?

    var body: some View {
        Form {
            Picker("Document", selection: $kind) { ForEach(Kind.allCases) { Text($0.rawValue).tag($0) } }
                .pickerStyle(.segmented)
            DatePicker(kind == .week ? "Any day of the week" : "Any day of the month", selection: $date, displayedComponents: .date)
            Button { create() } label: { Label("Create PDF", systemImage: "doc.richtext") }
            if let error { Text(error).foregroundStyle(.red) }
        }
        .navigationTitle("Export work time")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } } }
        .sheet(item: $file) { f in ShareSheet(items: [f.url]) }
    }

    private func create() {
        let (name, data) = kind == .week ? WorkTimePDF.week(containing: date, blocks: blocks) : WorkTimePDF.month(containing: date, blocks: blocks)
        let url = FileManager.default.temporaryDirectory.appending(path: name)
        do { try data.write(to: url); file = SharedFile(url: url) } catch { self.error = error.localizedDescription }
    }
}
