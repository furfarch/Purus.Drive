import SwiftUI
import SwiftData

struct DriveLogEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Vehicle.lastEdited, order: .reverse) private var vehicles: [Vehicle]
    @Query(sort: \Checklist.lastEdited, order: .reverse) private var allChecklists: [Checklist]

    @State var log: DriveLog
    var isNew: Bool = false
    var lockVehicle: Bool = false

    @State private var showChecklistRunner = false
    @State private var showingDeleteConfirm = false
    @State private var createdChecklistToEdit: Checklist? = nil

    private var filteredChecklists: [Checklist] {
        guard let vehicleType = log.vehicle?.type else { return [] }
        return allChecklists.filter { $0.vehicleType == vehicleType }
    }

    var body: some View {
        // after Delete the object is gone while the screen is still dismissing; reading it would crash
        if log.modelContext == nil { Color.clear } else { content }
    }

    private var content: some View {
        Form {
            Section("Vehicle & Date") {
                if lockVehicle {
                    HStack {
                        Text("Vehicle")
                        Spacer()
                        Text((log.vehicle?.brandModel.isEmpty ?? true) ? (log.vehicle?.type.displayName ?? "Vehicle") : (log.vehicle?.brandModel ?? "Vehicle"))
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
                    guard let vehicle = log.vehicle else { return }
                    let new = Checklist(vehicleType: vehicle.type,
                                        title: ChecklistTitle.make(for: vehicle.type, date: .now),
                                        items: ChecklistTemplates.items(for: vehicle.type),
                                        lastEdited: .now,
                                        vehicle: vehicle)
                    context.insert(new)
                    try? context.save()
                    log.checklist = new
                    createdChecklistToEdit = new
                } label: {
                    Label("Create Checklist", systemImage: "plus")
                }
                .disabled(log.vehicle == nil)

                if let cl = log.checklist {
                    Button {
                        showChecklistRunner = true
                    } label: {
                        Label("Run Checklist (\((cl.items ?? []).count) items)", systemImage: "checklist")
                    }
                }
            }
        }
        .navigationTitle(isNew ? "New Drive Log" : "Edit Drive Log")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Cancel") { cancel() } }

            if !isNew {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { saveAndClose() }
                    .fontWeight(.semibold)
            }
        }
        .confirmationDialog("Delete this drive log?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteLog() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
        .sheet(isPresented: $showChecklistRunner) {
            if let cl = log.checklist {
                NavigationStack { ChecklistEditorView(checklist: cl) }
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
        dismiss()
        if isNew {
            // same as Delete: a tombstone keeps an already-synced draft from coming back
            CloudKitSyncService.shared.markDeleted(entityType: "DriveLog", id: log.id)
            context.delete(log)
            do { try context.save() } catch { print("ERROR: failed discarding new drive log: \(error)") }
            Task { await CloudKitSyncService.shared.pushDeletions() }
        } else {
            // the editor binds to the model; drop the unsaved edits
            context.rollback()
        }
    }

    private func saveAndClose() {
        log.lastEdited = .now

        // Reason is a user note; do not overwrite it.
        do { try context.save() } catch { print("ERROR: failed saving drive log: \(error)") }
        // Trigger CloudKit sync after save
        Task { await CloudKitSyncService.shared.pushAllToCloud() }
        dismiss()
    }

    private func deleteLog() {
        dismiss()
        CloudKitSyncService.shared.markDeleted(entityType: "DriveLog", id: log.id)
        context.delete(log)
        do { try context.save() } catch { print("ERROR: failed deleting drive log: \(error)") }
        Task { await CloudKitSyncService.shared.pushDeletions() }
    }
}
