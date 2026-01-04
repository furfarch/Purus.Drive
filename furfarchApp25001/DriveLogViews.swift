import SwiftUI
import SwiftData

struct DriveLogListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DriveLog.date, order: .reverse) private var logs: [DriveLog]
    @Query(sort: \Vehicle.lastEdited, order: .reverse) private var vehicles: [Vehicle]

    @State private var showingNew = false
    @State private var newLog: DriveLog? = nil

    var body: some View {
        List {
            if logs.isEmpty {
                ContentUnavailableView("No drive logs", systemImage: "car", description: Text("Tap + to add your first log."))
            } else {
                ForEach(logs) { log in
                    NavigationLink(value: log) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(log.vehicle.brandModel.isEmpty ? log.vehicle.type.displayName : log.vehicle.brandModel)
                                    .font(.headline)
                                if let plate = log.vehicle.plate.isEmpty ? nil : log.vehicle.plate {
                                    Text(plate).foregroundStyle(.secondary)
                                }
                            }
                            Text(log.date, style: .date)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if !log.reason.isEmpty {
                                Text(log.reason).lineLimit(1)
                                    .font(.subheadline)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteLogs)
            }
        }
        .navigationTitle("Drive Log")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingNew = true } label: { Image(systemName: "plus") }
                    .disabled(vehicles.isEmpty)
            }
        }
        .navigationDestination(for: DriveLog.self) { log in
            DriveLogEditorView(log: log)
        }
        .sheet(isPresented: $showingNew) {
            if let newLog {
                NavigationStack {
                    DriveLogEditorView(log: newLog, isNew: true)
                }
            } else {
                Text("Please add a vehicle first.").padding()
            }
        }
        .onChange(of: showingNew) { _, isPresented in
            if isPresented {
                guard newLog == nil, let firstVehicle = vehicles.first else { return }
                let created = DriveLog(vehicle: firstVehicle)
                context.insert(created)
                newLog = created
            } else {
                newLog = nil
            }
        }
    }

    private func deleteLogs(at offsets: IndexSet) {
        for index in offsets { context.delete(logs[index]) }
        try? context.save()
    }
}

struct DriveLogEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Vehicle.lastEdited, order: .reverse) private var vehicles: [Vehicle]
    @Query(sort: \Checklist.lastEdited, order: .reverse) private var allChecklists: [Checklist]

    @State var log: DriveLog
    var isNew: Bool = false
    var lockVehicle: Bool = false

    @State private var showChecklistRunner = false
    @State private var createdChecklistToEdit: Checklist? = nil

    private var filteredChecklists: [Checklist] {
        allChecklists.filter { $0.vehicleType == log.vehicle.type }
    }

    var body: some View {
        Form {
            Section("Vehicle & Date") {
                if lockVehicle {
                    HStack {
                        Text("Vehicle")
                        Spacer()
                        Text(log.vehicle.brandModel.isEmpty ? log.vehicle.type.displayName : log.vehicle.brandModel)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Picker("Vehicle", selection: $log.vehicle) {
                        ForEach(vehicles) { v in
                            Text(v.brandModel.isEmpty ? v.type.displayName : v.brandModel)
                                .tag(v as Vehicle?)
                        }
                    }
                }
                DatePicker("Date", selection: $log.date, displayedComponents: [.date, .hourAndMinute])
            }

            Section("Details") {
                TextField("Reason", text: $log.reason)
                HStack {
                    TextField("Km start", value: $log.kmStart, format: .number)
                        .keyboardType(.numberPad)
                    TextField("Km end", value: $log.kmEnd, format: .number)
                        .keyboardType(.numberPad)
                }
                if log.kmEnd >= log.kmStart { Text("Distance: \(log.kmEnd - log.kmStart) km").foregroundStyle(.secondary) }
                TextField("Notes", text: $log.notes, axis: .vertical)
            }

            Section("Checklist") {
                Picker("Template", selection: Binding(get: { log.checklist }, set: { log.checklist = $0 })) {
                    Text("None").tag(nil as Checklist?)
                    ForEach(filteredChecklists) { cl in
                        Text(cl.title).tag(cl as Checklist?)
                    }
                }

                Button {
                    let df = DateFormatter()
                    df.dateStyle = .medium
                    df.timeStyle = .short
                    let title = df.string(from: .now)
                    let items = ChecklistTemplates.items(for: log.vehicle.type)
                    let new = Checklist(vehicleType: log.vehicle.type, title: title, items: items, lastEdited: .now)
                    context.insert(new)
                    try? context.save()
                    log.checklist = new
                    createdChecklistToEdit = new
                } label: {
                    Label("Create Checklist", systemImage: "plus")
                }

                if let cl = log.checklist {
                    Button {
                        showChecklistRunner = true
                    } label: {
                        Label("Run Checklist (\(cl.items.count) items)", systemImage: "checklist")
                    }
                }
            }
        }
        .navigationTitle(isNew ? "New Drive Log" : "Edit Drive Log")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Cancel") { cancel() } }
            ToolbarItem(placement: .topBarTrailing) { Button("Save") { saveAndClose() }.bold() }
        }
        .sheet(isPresented: $showChecklistRunner) {
            if let cl = log.checklist {
                ChecklistRunnerView(checklist: cl)
            }
        }
        .sheet(item: $createdChecklistToEdit) { cl in
            NavigationStack {
                ChecklistEditorView(checklist: cl)
            }
        }
        .onChange(of: log.vehicle) { _, _ in
            // Clear checklist when vehicle changes to avoid mismatch
            log.checklist = nil
        }
    }

    private func cancel() {
        if isNew {
            context.delete(log)
            try? context.save()
        }
        dismiss()
    }

    private func saveAndClose() {
        log.lastEdited = .now
        if isNew { context.insert(log) }
        do { try context.save() } catch { print("ERROR: failed saving drive log: \(error)") }
        dismiss()
    }
}

struct ChecklistRunnerView: View {
    @Environment(\.dismiss) private var dismiss
    @State var checklist: Checklist

    var body: some View {
        NavigationStack {
            List {
                ForEach(sectionedItems.keys.sorted(), id: \.self) { section in
                    Section(section) {
                        ForEach(items(in: section)) { item in
                            ChecklistItemRow(item: binding(for: item))
                        }
                    }
                }
            }
            .navigationTitle(checklist.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.bold() }
            }
        }
    }

    private var sectionedItems: [String: [ChecklistItem]] {
        Dictionary(grouping: checklist.items, by: { $0.section })
    }

    private func items(in section: String) -> [ChecklistItem] {
        sectionedItems[section] ?? []
    }

    private func binding(for item: ChecklistItem) -> Binding<ChecklistItem> {
        Binding(get: {
            checklist.items.first(where: { $0.id == item.id }) ?? item
        }, set: { updated in
            if let idx = checklist.items.firstIndex(where: { $0.id == item.id }) {
                checklist.items[idx] = updated
            }
        })
    }
}

#Preview { NavigationStack { DriveLogListView() } }
