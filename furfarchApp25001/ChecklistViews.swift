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
                    try? modelContext.save()
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
        for i in offsets { modelContext.delete(checklists[i]) }
        try? modelContext.save()
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
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    let effectiveVehicle = preselectedVehicle ?? selectedVehicle
                    guard let selectedVehicle = effectiveVehicle else { return }
                    let df = DateFormatter()
                    df.dateStyle = .medium
                    df.timeStyle = .short
                    let finalTitle = df.string(from: .now)

                    // Always prefill based on the vehicle's type.
                    let items = ChecklistTemplates.items(for: selectedVehicle.type)
                    let new = Checklist(vehicleType: selectedVehicle.type, title: finalTitle, items: items, lastEdited: .now)
                    onCreate(new)
                }
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
    @Bindable var checklist: Checklist

    @State private var editingNoteIndex: Int? = nil
    @State private var noteDraft: String = ""

    private var sectionedIndices: [String: [Int]] {
        Dictionary(grouping: checklist.items.indices, by: { checklist.items[$0].section })
    }

    var body: some View {
        List {
            ForEach(sectionedIndices.keys.sorted(), id: \.self) { section in
                Section(section) {
                    ForEach(sectionedIndices[section] ?? [], id: \.self) { idx in
                        let item = checklist.items[idx]

                        HStack(alignment: .top, spacing: 12) {
                            Button {
                                var updated = item
                                updated.state.cycle()
                                checklist.items[idx] = updated
                                checklist.lastEdited = .now
                                do { try modelContext.save() } catch { print("ERROR: failed saving checklist: \(error)") }
                            } label: {
                                Image(systemName: icon(for: item.state))
                                    .foregroundStyle(color(for: item.state))
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)

                                if let note = item.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(note)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                Button {
                                    editingNoteIndex = idx
                                    noteDraft = item.note ?? ""
                                } label: {
                                    Label("Note", systemImage: "square.and.pencil")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                            }

                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle(checklist.title)
        .sheet(isPresented: Binding(get: { editingNoteIndex != nil }, set: { if !$0 { editingNoteIndex = nil } })) {
            NavigationStack {
                Form {
                    Section("Note") {
                        TextField("Add note…", text: $noteDraft, axis: .vertical)
                    }
                }
                .navigationTitle("Edit Note")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { editingNoteIndex = nil } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            guard let idx = editingNoteIndex else { return }
                            var updated = checklist.items[idx]
                            let trimmed = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                            updated.note = trimmed.isEmpty ? nil : trimmed
                            checklist.items[idx] = updated
                            checklist.lastEdited = .now
                            try? modelContext.save()
                            editingNoteIndex = nil
                        }
                        .bold()
                    }
                }
            }
        }
    }

    private func icon(for state: ChecklistItemState) -> String {
        switch state {
        case .notSelected:
            return "circle"
        case .selected:
            return "checkmark.circle.fill"
        case .notApplicable:
            return "minus.circle.fill"
        case .notOk:
            return "xmark.octagon.fill"
        }
    }

    private func color(for state: ChecklistItemState) -> Color {
        switch state {
        case .notSelected:
            return .secondary
        case .selected:
            return .green
        case .notApplicable:
            return .orange
        case .notOk:
            return .red
        }
    }
}

struct ChecklistItemRow: View {
    @Binding var item: ChecklistItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.title)
                Spacer()
                Menu {
                    Button("Clear") { item.state = .notSelected }
                    Button("OK") { item.state = .selected }
                    Button("N/A") { item.state = .notApplicable }
                    Button("Not OK") { item.state = .notOk }
                } label: {
                    Label(label(for: item.state), systemImage: icon(for: item.state))
                        .labelStyle(.titleAndIcon)
                }
            }
            if let note = item.note {
                Text(note).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func label(for state: ChecklistItemState) -> String {
        switch state {
        case .notSelected: return "Clear"
        case .selected: return "OK"
        case .notApplicable: return "N/A"
        case .notOk: return "Not OK"
        }
    }

    private func icon(for state: ChecklistItemState) -> String {
        switch state {
        case .notSelected: return "circle"
        case .selected: return "checkmark.circle.fill"
        case .notApplicable: return "minus.circle.fill"
        case .notOk: return "xmark.octagon.fill"
        }
    }
}

#Preview { NavigationStack { ChecklistListView() } }
