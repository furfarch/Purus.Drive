import SwiftUI
import SwiftData

struct ChecklistListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Checklist.lastEdited, order: .reverse) private var checklists: [Checklist]

    @State private var showingCreate = false
    @State private var editChecklist: Checklist? = nil

    var body: some View {
        List {
            if checklists.isEmpty {
                ContentUnavailableView("No checklists", systemImage: "checklist", description: Text("Tap + to create a checklist from a template or blank."))
            } else {
                ForEach(checklists) { cl in
                    NavigationLink(destination: ChecklistEditorView(checklist: cl)) {
                        VStack(alignment: .leading) {
                            Text(cl.title).font(.headline)
                            Text(cl.vehicleType.displayName).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("Checklists")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingCreate = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingCreate) {
            NavigationStack {
                CreateChecklistView { new in
                    modelContext.insert(new)
                    do {
                        try modelContext.save()
                    } catch {
                        print("ERROR: failed saving new checklist: \(error)")
                    }
                    showingCreate = false
                    // open editor for created checklist
                    editChecklist = new
                }
                .environment(\.modelContext, modelContext)
            }
        }
        .sheet(item: $editChecklist) { cl in
            NavigationStack { ChecklistEditorView(checklist: cl) }
        }
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets {
            let cl = checklists[i]
            CloudKitSyncService.shared.markDeleted(entityType: "Checklist", id: cl.id)
            modelContext.delete(cl)
        }
        try? modelContext.save()
        Task { await CloudKitSyncService.shared.pushDeletions() }
    }
}

struct CreateChecklistView: View {
    @Environment(\.dismiss) private var dismiss
    var onCreate: (Checklist) -> Void

    /// When provided, the checklist is created for this vehicle (no extra selection required).
    var preselectedVehicle: Vehicle? = nil

    @Query(sort: \Vehicle.lastEdited, order: .reverse) private var vehicles: [Vehicle]
    @State private var selectedVehicle: Vehicle? = nil

    var body: some View {
        Form {
            Section("Vehicle") {
                if let preselectedVehicle {
                    HStack {
                        Text("Vehicle")
                        Spacer()
                        Text(preselectedVehicle.brandModel.isEmpty ? preselectedVehicle.type.displayName : preselectedVehicle.brandModel)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Picker("Vehicle", selection: $selectedVehicle) {
                        Text("Select...").tag(Vehicle?.none)
                        ForEach(vehicles) { v in
                            Text(v.brandModel.isEmpty ? v.type.displayName : v.brandModel)
                                .tag(Vehicle?.some(v))
                        }
                    }
                }
            }
        }
        .navigationTitle("New Checklist")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let effectiveVehicle = preselectedVehicle ?? selectedVehicle
                    guard let selectedVehicle = effectiveVehicle else { return }
                    let finalTitle = ChecklistTitle.make(for: selectedVehicle.type, date: .now)

                    // Always prefill based on the vehicle's type.
                    let items = ChecklistTemplates.items(for: selectedVehicle.type)
                    let new = Checklist(vehicleType: selectedVehicle.type,
                                        title: finalTitle,
                                        items: items,
                                        lastEdited: .now,
                                        vehicle: selectedVehicle)
                    onCreate(new)
                    dismiss()
                } label: {
                    Text("Save").fontWeight(.semibold)
                }
                .accessibilityLabel("Save")
                .disabled(preselectedVehicle == nil && selectedVehicle == nil)
            }
        }
        .onAppear {
            if let preselectedVehicle {
                selectedVehicle = preselectedVehicle
            }
        }
    }
}

// Checklist editor (moved here so all references compile)
struct ChecklistEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var checklist: Checklist

    @Query(sort: \DriveLog.date, order: .reverse) private var allDriveLogs: [DriveLog]

    @State private var showingDeleteConfirm = false

    private var orderedSections: [String] {
        let present = Set((checklist.items ?? []).map { $0.section })
        let preferred = ChecklistTemplates.sectionOrder(for: checklist.vehicleType)
        let inPreferred = preferred.filter { present.contains($0) }
        let remainder = present.subtracting(inPreferred).sorted()
        return inPreferred + remainder
    }

    private var subsectionOrderBySection: [String: [String]] {
        ChecklistTemplates.subsectionOrderBySection(for: checklist.vehicleType)
    }

    private func items(in section: String) -> [ChecklistItem] {
        let sectionItems = (checklist.items ?? []).filter { $0.section == section }
        guard let order = subsectionOrderBySection[section], !order.isEmpty else {
            return sectionItems.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        return sectionItems.sorted { a, b in
            let ia = order.firstIndex(of: a.title) ?? Int.max
            let ib = order.firstIndex(of: b.title) ?? Int.max
            if ia != ib { return ia < ib }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }
    }

    private func subsectionName(for item: ChecklistItem, in section: String) -> String? {
        guard let order = subsectionOrderBySection[section], let idx = order.firstIndex(of: item.title) else { return nil }
        let prior = order.prefix(idx)
        // The template lists subsection labels as ALL CAPS; pick the most recent.
        return prior.last(where: { $0.uppercased() == $0 })
    }

    private func binding(for item: ChecklistItem) -> Binding<ChecklistItem> {
        Binding(get: {
            (checklist.items ?? []).first(where: { $0.id == item.id }) ?? item
        }, set: { updated in
            guard var items = checklist.items else { return }
            if let idx = items.firstIndex(where: { $0.id == updated.id }) {
                items[idx] = updated
                checklist.items = items
            }
        })
    }

    /// items of a section split by subsection (template order)
    private func grouped(_ items: [ChecklistItem], in section: String) -> [(subsection: String?, items: [ChecklistItem])] {
        var result: [(String?, [ChecklistItem])] = []
        for item in items {
            let sub = subsectionName(for: item, in: section)
            if let last = result.last, last.0 == sub { result[result.count - 1].1.append(item) }
            else { result.append((sub, [item])) }
        }
        return result
    }

    /// "5 done · 1 not OK · 2 open"
    private func summary(_ items: [ChecklistItem]) -> String {
        func n(_ st: ChecklistItemState) -> Int { items.filter { $0.state == st }.count }
        let parts = [(n(.selected), "done"), (n(.notOk), "not OK"), (n(.notApplicable), "n/a"), (n(.notSelected), "open")]
        let s = parts.filter { $0.0 > 0 }.map { "\($0.0) \($0.1)" }.joined(separator: " · ")
        return s.isEmpty ? "No items" : s
    }

    /// local save on every tap (as before); the Save button also syncs
    private func saveLocal() {
        checklist.lastEdited = .now
        do { try modelContext.save() } catch { print("ERROR: failed saving checklist: \(error)") }
    }

    var body: some View {
        Group {
            if orderedSections.isEmpty {
                ContentUnavailableView("No items", systemImage: "checklist", description: Text("This checklist has no items."))
            } else {
                // FinAI style: one collapsible line per part with a summary, first part open
                List {
                    ForEach(Array(orderedSections.enumerated()), id: \.offset) { index, section in
                        let sectionItems = items(in: section)
                        Section {
                            Fold(title: section, summary: summary(sectionItems), open: index == 0) {
                                ForEach(Array(grouped(sectionItems, in: section).enumerated()), id: \.offset) { _, group in
                                    if let sub = group.subsection {
                                        Text(sub).font(.caption).foregroundStyle(.secondary)
                                    }
                                    ForEach(group.items) { item in
                                        ChecklistCardItemRow(item: binding(for: item), onChange: saveLocal)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(checklist.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showingDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    checklist.lastEdited = .now
                    do { try modelContext.save() } catch { print("ERROR: failed saving checklist: \(error)") }
                    // Trigger CloudKit sync after save
                    Task { await CloudKitSyncService.shared.pushAllToCloud() }
                    dismiss()
                } label: {
                    Text("Save").fontWeight(.semibold)
                }
            }
        }
        .confirmationDialog("Delete this checklist?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                    // Clear any log references first.
                    for log in allDriveLogs where log.checklist === checklist {
                        log.checklist = nil
                    }
                    CloudKitSyncService.shared.markDeleted(entityType: "Checklist", id: checklist.id)
                    modelContext.delete(checklist)
                    do { try modelContext.save() } catch { print("ERROR: failed deleting checklist: \(error)") }
                    Task { await CloudKitSyncService.shared.pushDeletions() }
                    dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
    }
}

private struct ChecklistCardItemRow: View {
    @Binding var item: ChecklistItem
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                Button {
                    item.state.cycle()
                    onChange()
                } label: {
                    Image(systemName: symbolName(for: item.state))
                        .font(.title3)
                        .foregroundStyle(color(for: item.state))
                }
                .buttonStyle(.plain)

                Text(item.title)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    // show an empty note field; hide it again only while it is empty (never erase a written note)
                    if item.note == nil { item.note = "" }
                    else if item.note == "" { item.note = nil }
                    onChange()
                } label: {
                    Image(systemName: "ellipsis")
                }
                .buttonStyle(.plain)
            }

            if let _ = item.note {
                TextField("Notiz", text: Binding(
                    get: { item.note ?? "" },
                    set: { newValue in
                        item.note = newValue
                        onChange()
                    }
                ), axis: .vertical)
                .font(.footnote)
                .textFieldStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func color(for state: ChecklistItemState) -> Color {
        switch state {
        case .selected: return .green
        case .notOk: return .red
        case .notSelected, .notApplicable: return .secondary
        }
    }

    private func symbolName(for state: ChecklistItemState) -> String {
        switch state {
        case .notSelected: return "circle"
        case .selected: return "checkmark.circle.fill"
        case .notApplicable: return "minus.circle"
        case .notOk: return "xmark.octagon.fill"
        }
    }
}

#Preview { NavigationStack { ChecklistListView() } }
