import SwiftUI
import SwiftData

private func dur(_ t: TimeInterval) -> String { WorkTimeRules.dur(t) }
private func hm(_ d: Date) -> String { d.formatted(date: .omitted, time: .shortened) }
private func dayText(_ d: Date) -> String { d.formatted(.dateTime.weekday(.abbreviated).day().month(.twoDigits)) }
/// number field that saves on every keystroke (a value/format field only saves when it loses focus)
private func digits(_ b: Binding<Int?>) -> Binding<String> {
    Binding(get: { b.wrappedValue.map(String.init) ?? "" }, set: { b.wrappedValue = Int($0.filter(\.isNumber)) })
}

/// Last line of the Vehicles list.
struct WorkTimeRow: View {
    @Query private var blocks: [WorkBlock]

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.badge.checkmark")
                .font(.title3)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("Work time").font(.headline)
                if let run = WorkLog.running(blocks) {
                    Text("\(run.activity.title) since \(hm(run.start))").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text("ARV 1 log").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct WorkTimeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkBlock.start) private var blocks: [WorkBlock]

    @State private var startSheet: WorkActivity?
    @State private var newBlock: WorkBlock?
    @State private var showExport = false
    @State private var askNext = false
    @State private var endDay = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { tl in
            let report = WorkLog.report(blocks, now: tl.date)
            List {
                nowSection(report, now: tl.date)
                checksSection(report)
                daysSection(report)
            }
        }
        .navigationTitle("Work time")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showExport = true } label: { Image(systemName: "doc.richtext") }
                    .accessibilityLabel("Export PDF")
                    .disabled(blocks.isEmpty)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let b = WorkBlock(activity: .work, start: .now.addingTimeInterval(-3600), end: .now)
                    context.insert(b)
                    newBlock = b
                } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add block")
            }
        }
        .sheet(item: $startSheet) { activity in
            NavigationStack { WorkStartSheet(activity: activity, blocks: blocks) }
        }
        .sheet(item: $newBlock) { b in
            NavigationStack { WorkBlockEditor(block: b, isNew: true) }
        }
        .sheet(isPresented: $showExport) {
            NavigationStack { WorkExportSheet(blocks: blocks) }
        }
        .sheet(isPresented: $endDay) {
            NavigationStack { WorkEndSheet(blocks: blocks) }
        }
        .confirmationDialog("What now?", isPresented: $askNext, titleVisibility: .visible) {
            let current = WorkLog.running(blocks)?.activity
            ForEach([WorkActivity.driving, .work, .standby, .rest, .ferry].filter { $0 != current }) { a in
                Button(a == .rest ? "Break" : a.title) { begin(a) }
            }
            Button("End of day", role: .destructive) { endDay = true }
        }
        .onAppear { WorkLog.refreshReminder(context) }
    }

    // MARK: Now

    @ViewBuilder
    private func nowSection(_ r: WorkTimeRules.Report, now: Date) -> some View {
        let run = WorkLog.running(blocks)
        Section {
            TimelineView(.periodic(from: .now, by: 1)) { tick in
                recorder(run, now: tick.date)
            }
            .listRowInsets(EdgeInsets())

            let s = r.status
            if run?.activity.isActive == true || s.dailyRestBy != nil {
                let left = max(0, 4.5 * WorkTimeRules.h - s.drivingSinceBreak)
                LabeledContent("Driving since break", value: "\(dur(s.drivingSinceBreak)) · \(dur(left)) left")
                    .foregroundStyle(left < 15 * WorkTimeRules.m ? .red : .primary)
                LabeledContent("Driving today", value: "\(dur(s.shiftDriving)) of 9 h")
                    .foregroundStyle(s.shiftDriving > 9 * WorkTimeRules.h ? .orange : .primary)
                if let by = s.dailyRestBy {
                    LabeledContent("Start daily rest by", value: Calendar.current.isDateInToday(by) ? hm(by) : by.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                        .foregroundStyle(by < now ? .red : .primary)
                }
            }
            if let wk = s.weeklyRestBy {
                LabeledContent("Weekly rest by", value: wk.formatted(.dateTime.weekday(.abbreviated).day().month(.twoDigits).hour().minute()))
                    .foregroundStyle(wk < now ? .red : .primary)
            }
            ForEach(Array(s.openOwed.enumerated()), id: \.offset) { _, o in
                LabeledContent(o.reason, value: String(format: "make up %.1f h by %@", o.hours, dayText(o.due)))
                    .foregroundStyle(.orange)
            }
        } footer: {
            Text("Break, Ferry/Train and off duty count as free time; so does every gap between blocks.")
        }
    }

    /// One button: off duty → Start work; recording → stop and ask what comes next.
    @ViewBuilder
    private func recorder(_ run: WorkBlock?, now: Date) -> some View {
        let off = run == nil || run?.activity == .out
        let a = run?.activity ?? .out
        VStack(spacing: 14) {
            if off {
                VStack(spacing: 4) {
                    Text("Off duty").font(.title2.bold())
                    if let since = WorkLog.lastActiveEnd(blocks) {
                        Text("since \(hm(since)) · \(dur(now.timeIntervalSince(since))) rest").foregroundStyle(.secondary)
                    }
                }
            } else if let run {
                HStack(spacing: 8) {
                    if a.isActive {
                        Image(systemName: "record.circle.fill").foregroundStyle(.red).symbolEffect(.pulse)
                        Text("REC").font(.caption.bold()).foregroundStyle(.red)
                    }
                    Label(a == .rest ? "Break" : a.title, systemImage: a.symbol).font(.headline)
                }
                Text(clock(now.timeIntervalSince(run.start)))
                    .font(.system(size: 52, weight: .semibold, design: .rounded).monospacedDigit())
                Text("since \(hm(run.start))").font(.subheadline).foregroundStyle(.secondary)
            }
            Button {
                if off { startSheet = .driving } else { askNext = true }
            } label: {
                Text(off ? "Start work" : a == .rest ? "End break" : a == .ferry ? "Off the ferry" : "Stop \(a.title.lowercased())")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.borderedProminent)
            .tint(off ? .green : .red)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(off ? Color(.secondarySystemBackground) : a.color.opacity(0.18))
    }

    private func begin(_ a: WorkActivity) {
        if WorkLog.needsStartSheet(a, blocks: blocks) { startSheet = a }
        else { WorkLog.start(a, blocks: blocks, context: context) }
    }

    private func clock(_ t: TimeInterval) -> String {
        let s = max(0, Int(t))
        return String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
    }

    // MARK: Checks

    @ViewBuilder
    private func checksSection(_ r: WorkTimeRules.Report) -> some View {
        let since = Calendar.current.date(byAdding: .day, value: -28, to: .now)!
        let recent = r.findings.filter { $0.date >= since }
        Section {
            if recent.isEmpty {
                Label("No issues in the last 28 days", systemImage: "checkmark.circle").foregroundStyle(.green)
            } else {
                Fold(title: "\(recent.count) issue\(recent.count == 1 ? "" : "s") in the last 28 days", summary: "ARV 1 checks") {
                    ForEach(recent) { f in findingRow(f) }
                }
            }
        }
    }

    // MARK: Days

    @ViewBuilder
    private func daysSection(_ r: WorkTimeRules.Report) -> some View {
        let cal = Calendar.current
        let thisWeek = WorkTimeRules.startOfWeek(.now, cal)
        Section("Days") {
            if r.shifts.isEmpty {
                Text("No work recorded yet").foregroundStyle(.secondary)
            }
            ForEach(r.weeks.reversed().filter { w in r.shifts.contains { WorkTimeRules.startOfWeek($0.start, cal) == w.start } }) { w in
                let end = cal.date(byAdding: .day, value: 6, to: w.start)!
                Fold(title: "Week \(cal.component(.weekOfYear, from: w.start)) · \(dayText(w.start)) – \(dayText(end))",
                     summary: "Driving \(dur(w.driving)) · work \(dur(w.work)) · 26-wk avg \(dur(w.average26))",
                     open: w.start == thisWeek) {
                    ForEach(r.shifts.filter { WorkTimeRules.startOfWeek($0.start, cal) == w.start }.reversed()) { shift in
                        NavigationLink {
                            WorkDayView(shift: shift, findings: r.findings)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(dayText(shift.start)) \(hm(shift.start))–\(hm(shift.end))").font(.subheadline.weight(.semibold))
                                Text(shiftSummary(shift)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

func shiftSummary(_ s: WorkTimeRules.Shift) -> String {
    var parts = ["Driving \(dur(s.driving))", "work \(dur(s.work))"]
    if s.standby > 0 { parts.append("standby \(dur(s.standby))") }
    parts.append("breaks \(dur(s.breaks))")
    if let r = s.restAfter {
        parts.append(r.ongoing ? "resting since \(hm(r.start))" : "then \(dur(r.end.timeIntervalSince(r.start))) \(r.kind?.rawValue ?? "rest")")
    }
    return parts.joined(separator: " · ")
}

@ViewBuilder
func findingRow(_ f: WorkTimeRules.Finding) -> some View {
    VStack(alignment: .leading, spacing: 2) {
        Label(f.text, systemImage: f.severe ? "exclamationmark.octagon" : "exclamationmark.triangle")
            .foregroundStyle(f.severe ? .red : .orange)
            .font(.subheadline)
        Text("\(f.date.formatted(date: .abbreviated, time: .shortened)) · ARV 1 \(f.article)")
            .font(.caption).foregroundStyle(.secondary)
    }
}

// MARK: - One day (shift)

struct WorkDayView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkBlock.start) private var blocks: [WorkBlock]
    let shift: WorkTimeRules.Shift
    let findings: [WorkTimeRules.Finding]
    @State private var editing: WorkBlock?
    @State private var adding: WorkBlock?

    private var dayBlocks: [WorkBlock] {
        let until = shift.restAfter?.end ?? .distantFuture
        return blocks.filter { $0.start >= shift.start.addingTimeInterval(-1) && $0.start < until }
    }

    var body: some View {
        List {
            Section("Totals") {
                LabeledContent("Driving", value: dur(shift.driving))
                LabeledContent("Work (incl. driving)", value: dur(shift.work))
                LabeledContent("Standby", value: dur(shift.standby))
                LabeledContent("Breaks", value: dur(shift.breaks))
                if let p = shift.splitPart { LabeledContent("First part of split rest", value: dur(p)) }
                if let r = shift.restAfter {
                    LabeledContent("Rest after", value: r.ongoing ? "since \(hm(r.start))" : "\(dur(r.end.timeIntervalSince(r.start))) · \(r.kind?.rawValue ?? "")")
                }
            }
            let mine = findings.filter { $0.date >= shift.start && $0.date <= (shift.restAfter?.end ?? .now) }
            if !mine.isEmpty {
                Section("Checks") { ForEach(mine) { findingRow($0) } }
            }
            Section("Blocks") {
                ForEach(dayBlocks) { b in
                    Button { editing = b } label: { blockRow(b) }
                        .buttonStyle(.plain)
                }
                .onDelete { idx in for i in idx { WorkLog.delete(dayBlocks[i], context: context) } }
                Button {
                    let b = WorkBlock(activity: .work, start: shift.end, end: shift.end.addingTimeInterval(1800))
                    context.insert(b)
                    adding = b
                } label: { Label("Add block", systemImage: "plus") }
            }
        }
        .navigationTitle(dayText(shift.start))
        .sheet(item: $editing) { b in
            NavigationStack { WorkBlockEditor(block: b) }
        }
        .sheet(item: $adding) { b in
            NavigationStack { WorkBlockEditor(block: b, isNew: true) }
        }
    }

    private func blockRow(_ b: WorkBlock) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: b.activity.symbol).frame(width: 22)
                Text("\(hm(b.start))–\(b.end.map(hm) ?? "now")  \(b.activity.title)").font(.subheadline)
                if b.exception { Image(systemName: "exclamationmark.circle").foregroundStyle(.orange) }
            }
            let details = [
                b.vehiclePlate.isEmpty ? nil : b.vehiclePlate,
                b.kmStart.map { s in "km \(s)\(b.kmEnd.map { "–\($0)" } ?? "")" },
                [b.placeStart, b.placeEnd].filter { !$0.isEmpty }.joined(separator: " → ").nilIfEmpty,
                b.note.nilIfEmpty
            ].compactMap { $0 }
            if !details.isEmpty {
                Text(details.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary).padding(.leading, 30)
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

// MARK: - Start after free time (like inserting the driver card)

struct WorkStartSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Vehicle.lastEdited, order: .reverse) private var vehicles: [Vehicle]

    @State var activity: WorkActivity
    let blocks: [WorkBlock]

    struct Earlier: Identifiable { let id = UUID(); var activity: WorkActivity = .work; var from: Date; var to: Date }

    @State private var startAt = Date.now
    @State private var earlier: [Earlier] = []
    @State private var plate = ""
    @State private var vehicleName = ""
    @State private var km: Int?
    @State private var place = ""
    @State private var lastKmEnd: Int?
    @State private var lastPlaceEnd = ""

    private var freeSince: Date? { WorkLog.lastActiveEnd(blocks) }
    private var lastDrive: WorkBlock? { WorkLog.lastDriving(blocks) }

    var body: some View {
        Form {
            if let since = freeSince {
                Section {
                    Text("Free time since \(since.formatted(date: .abbreviated, time: .shortened)). Add anything you did before starting now; the rest counts as rest.")
                        .font(.footnote).foregroundStyle(.secondary)
                    ForEach($earlier) { $e in
                        VStack {
                            Picker("Activity", selection: $e.activity) {
                                ForEach(WorkActivity.allCases.filter(\.isActive)) { Text($0.title).tag($0) }
                            }
                            DatePicker("From", selection: $e.from, in: since...startAt)
                            DatePicker("To", selection: $e.to, in: e.from...startAt)
                        }
                    }
                    .onDelete { earlier.remove(atOffsets: $0) }
                    Button { earlier.append(Earlier(from: max(since, startAt.addingTimeInterval(-3600)), to: startAt)) } label: {
                        Label("Add earlier activity", systemImage: "plus")
                    }
                }
            }
            Section {
                Picker("Start with", selection: $activity) {
                    ForEach(WorkActivity.allCases.filter(\.isActive)) { Label($0.title, systemImage: $0.symbol).tag($0) }
                }
                DatePicker("Start", selection: $startAt, in: (freeSince ?? .distantPast)...Date.now)
                if activity == .driving {
                    Picker("Vehicle", selection: $plate) {
                        Text("None").tag("")
                        ForEach(vehicles) { v in Text(label(v)).tag(v.plate) }
                        if !plate.isEmpty && !vehicles.contains(where: { $0.plate == plate }) { Text(plate).tag(plate) }
                    }
                    TextField("Km at start", text: digits($km)).keyboardType(.numberPad)
                }
                TextField("Place (with country, e.g. Bern CH)", text: $place)
            }
            if let last = lastDrive, last.kmEnd == nil || last.placeEnd.isEmpty {
                Section("End of the last drive (\(last.vehiclePlate.isEmpty ? dayText(last.start) : last.vehiclePlate))") {
                    TextField("Km at end", text: digits($lastKmEnd)).keyboardType(.numberPad)
                    TextField("Place at end", text: $lastPlaceEnd)
                }
            }
        }
        .navigationTitle("Start work")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) { Button("Start") { save() }.fontWeight(.semibold) }
        }
        .onAppear {
            plate = lastDrive?.vehiclePlate ?? ""
            km = lastDrive?.kmEnd
            place = lastDrive?.placeEnd ?? ""
        }
    }

    private func label(_ v: Vehicle) -> String {
        let name = v.brandModel.isEmpty ? v.type.displayName : v.brandModel
        return v.plate.isEmpty ? name : "\(name) · \(v.plate)"
    }

    private func save() {
        if let last = lastDrive {
            if let k = lastKmEnd { last.kmEnd = k }
            if !lastPlaceEnd.isEmpty { last.placeEnd = lastPlaceEnd }
            last.lastEdited = .now
        }
        let valid = earlier.filter { $0.to > $0.from }.sorted { $0.from < $1.from }
        // the running free time ends where the first earlier activity begins
        let closeAt = valid.first?.from ?? startAt
        for b in blocks where b.end == nil { b.end = max(b.start, closeAt); b.lastEdited = .now }
        for e in valid { context.insert(WorkBlock(activity: e.activity, start: e.from, end: e.to)) }
        // after the earlier activities the time up to the start is rest
        if let lastEnd = valid.last?.to, lastEnd < startAt { context.insert(WorkBlock(activity: .rest, start: lastEnd, end: startAt)) }

        let template = WorkBlock(activity: activity, start: startAt)
        template.kmStart = km
        template.placeStart = place
        if activity == .driving {
            template.vehiclePlate = plate
            template.vehicleName = vehicles.first { $0.plate == plate }.map { $0.brandModel.isEmpty ? $0.type.displayName : $0.brandModel } ?? (plate == lastDrive?.vehiclePlate ? lastDrive?.vehicleName ?? "" : "")
        }
        WorkLog.start(activity, at: startAt, template: template, blocks: blocks, context: context)
        dismiss()
    }
}

// MARK: - End of day

struct WorkEndSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let blocks: [WorkBlock]
    @State private var km: Int?
    @State private var place = ""

    private var lastDrive: WorkBlock? { WorkLog.lastDriving(blocks) }

    var body: some View {
        Form {
            if let d = lastDrive {
                Section("End of the drive (\(d.vehiclePlate.isEmpty ? dayText(d.start) : d.vehiclePlate))") {
                    TextField("Km at end", text: digits($km)).keyboardType(.numberPad)
                }
            }
            Section { TextField("Place (with country, e.g. Bern CH)", text: $place) }
        }
        .navigationTitle("End of day")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) { Button("End") { save() }.fontWeight(.semibold) }
        }
        .onAppear { km = lastDrive?.kmEnd; place = lastDrive?.placeEnd ?? "" }
    }

    private func save() {
        let now = Date.now
        for b in blocks where b.end == nil {
            b.end = max(b.start, now)
            if place.isEmpty == false { b.placeEnd = place }
            b.lastEdited = now
        }
        if let d = lastDrive {
            if let k = km { d.kmEnd = k }
            if !place.isEmpty { d.placeEnd = place }
            d.lastEdited = now
        }
        WorkLog.save(context)
        dismiss()
    }
}

private extension WorkActivity {
    var color: Color {
        switch self {
        case .driving: return .blue
        case .work: return .orange
        case .standby: return .yellow
        case .rest: return .green
        case .ferry: return .teal
        case .out: return .gray
        }
    }
}

// MARK: - Edit one block

struct WorkBlockEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Vehicle.lastEdited, order: .reverse) private var vehicles: [Vehicle]

    @Bindable var block: WorkBlock
    var isNew = false
    @State private var confirmDelete = false

    var body: some View {
        if block.modelContext == nil { Color.clear } else { form }
    }

    private var form: some View {
        Form {
            Section {
                Picker("Activity", selection: $block.activity) {
                    ForEach(WorkActivity.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                }
                DatePicker("Start", selection: $block.start)
                Toggle("Still running", isOn: Binding(get: { block.end == nil }, set: { block.end = $0 ? nil : max(block.start, .now) }))
                if block.end != nil {
                    DatePicker("End", selection: Binding(get: { block.end ?? block.start }, set: { block.end = $0 }), in: block.start...)
                }
            }
            if block.activity == .driving {
                Section("Vehicle") {
                    Picker("Vehicle", selection: Binding(get: { block.vehiclePlate }, set: { p in
                        block.vehiclePlate = p
                        if let v = vehicles.first(where: { $0.plate == p }) { block.vehicleName = v.brandModel.isEmpty ? v.type.displayName : v.brandModel }
                    })) {
                        Text("None").tag("")
                        ForEach(vehicles) { v in Text(v.plate.isEmpty ? v.brandModel : "\(v.brandModel) · \(v.plate)").tag(v.plate) }
                        if !block.vehiclePlate.isEmpty && !vehicles.contains(where: { $0.plate == block.vehiclePlate }) { Text(block.vehiclePlate).tag(block.vehiclePlate) }
                    }
                    HStack {
                        TextField("Km start", text: digits($block.kmStart)).keyboardType(.numberPad)
                        TextField("Km end", text: digits($block.kmEnd)).keyboardType(.numberPad)
                    }
                }
            }
            Section("Place (with country)") {
                TextField("Start", text: $block.placeStart)
                TextField("End", text: $block.placeEnd)
            }
            Section {
                Toggle("Exception (ARV 1 Art. 12)", isOn: $block.exception)
                TextField(block.exception ? "Reason for the exception" : "Note", text: $block.note, axis: .vertical)
            } footer: {
                Text("Art. 12: up to 1 h more driving to reach home or the company for a weekly rest, or 2 h after a 30-min break for a regular weekly rest. The extra time must be made up within 3 weeks.")
            }
            if !isNew {
                Section { Button("Delete block", role: .destructive) { confirmDelete = true } }
            }
        }
        .navigationTitle(isNew ? "New block" : "Edit block")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    if isNew { context.delete(block) } else { context.rollback() }
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    block.lastEdited = .now
                    WorkLog.save(context)
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .confirmationDialog("Delete this block?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                dismiss()
                WorkLog.delete(block, context: context)
            }
        }
    }
}
