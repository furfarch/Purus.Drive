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
                    Image(systemName: "square.and.arrow.down")
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

    @State private var selectedSectionIndex: Int = 0
    @State private var editingItemID: UUID? = nil

    private var orderedSections: [String] {
        let present = Set(checklist.items.map { $0.section })
        let preferred = ChecklistTemplates.sectionOrder(for: checklist.vehicleType)
        let inPreferred = preferred.filter { present.contains($0) }
        let remainder = present.subtracting(inPreferred).sorted()
        return inPreferred + remainder
    }

    private var subsectionOrderBySection: [String: [String]] {
        ChecklistTemplates.subsectionOrderBySection(for: checklist.vehicleType)
    }

    private func items(in section: String) -> [ChecklistItem] {
        let sectionItems = checklist.items.filter { $0.section == section }
        guard let order = subsectionOrderBySection[section], !order.isEmpty else {
            return sectionItems.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        // Preserve template order by sorting by the title's index in the order list.
        return sectionItems.sorted { a, b in
            let ia = order.firstIndex(of: a.title) ?? Int.max
            let ib = order.firstIndex(of: b.title) ?? Int.max
            if ia != ib { return ia < ib }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }
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

    var body: some View {
        VStack(spacing: 0) {
            if orderedSections.isEmpty {
                ContentUnavailableView("No items", systemImage: "checklist", description: Text("This checklist has no items."))
            } else {
                TabView(selection: $selectedSectionIndex) {
                    ForEach(Array(orderedSections.enumerated()), id: \.offset) { index, section in
                        ChecklistSectionCard(
                            title: section,
                            items: items(in: section),
                            bindingFor: binding(for:),
                            subtitleForItem: { item in
                                // Show which subsection header the item belongs to (based on template order).
                                guard let order = subsectionOrderBySection[section], let idx = order.firstIndex(of: item.title) else { return nil }
                                let prior = order.prefix(idx)
                                return prior.last(where: { $0.uppercased() == $0 }) // heuristic: template subsection headers are uppercase
                            },
                            onEditNote: { item in
                                editingItemID = item.id
                            },
                            onChange: {
                                checklist.lastEdited = .now
                                do { try modelContext.save() } catch { print("ERROR: failed saving checklist: \(error)") }
                            }
                        )
                        .padding(.horizontal)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            }
        }
        // avoid repeated title by only using navigation title
        .navigationTitle(checklist.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: Binding<ChecklistItem?>(
            get: {
                guard let id = editingItemID else { return nil }
                return checklist.items.first(where: { $0.id == id })
            },
            set: { _ in
                editingItemID = nil
            }
        )) { _ in
            ChecklistNoteEditorSheet(
                item: Binding(get: {
                    checklist.items.first(where: { $0.id == editingItemID }) ?? ChecklistItem(section: "", title: "")
                }, set: { updated in
                    if let idx = checklist.items.firstIndex(where: { $0.id == updated.id }) {
                        checklist.items[idx] = updated
                        checklist.lastEdited = .now
                        try? modelContext.save()
                    }
                })
            )
            .presentationDetents([.medium, .large])
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    // Clear any log references first.
                    for log in allDriveLogs where log.checklist === checklist {
                        log.checklist = nil
                    }
                    modelContext.delete(checklist)
                    do { try modelContext.save() } catch { print("ERROR: failed deleting checklist: \(error)") }
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    checklist.lastEdited = .now
                    do { try modelContext.save() } catch { print("ERROR: failed saving checklist: \(error)") }
                    dismiss()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .accessibilityLabel("Save")
            }
        }
    }
}

private struct ChecklistSectionCard: View {
    let title: String
    let items: [ChecklistItem]
    let bindingFor: (ChecklistItem) -> Binding<ChecklistItem>
    let subtitleForItem: (ChecklistItem) -> String?
    let onEditNote: (ChecklistItem) -> Void
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title only once (card)
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)

            if items.isEmpty {
                Text("No items in this section")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(items) { item in
                            ChecklistCardItemRow(
                                item: bindingFor(item),
                                subtitle: subtitleForItem(item),
                                onEditNote: { onEditNote(item) },
                                onChange: onChange
                            )
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
        )
    }
}

private struct ChecklistCardItemRow: View {
    @Binding var item: ChecklistItem
    let subtitle: String?
    let onEditNote: () -> Void
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 10) {
                Button {
                    item.state.cycle()
                    onChange()
                } label: {
                    Image(systemName: symbolName(for: item.state))
                        .font(.title3)
                }
                .buttonStyle(.plain)

                Text(item.title)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    onEditNote()
                } label: {
                    Image(systemName: item.note == nil || item.note == "" ? "note.text.badge.plus" : "note.text")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit note")
            }

            if let note = item.note, !note.isEmpty {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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

private struct ChecklistNoteEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var item: ChecklistItem

    @State private var draft: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Note") {
                    TextField("Optional note", text: $draft, axis: .vertical)
                        .lineLimit(3...12)
                }
            }
            .navigationTitle("Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        item.note = trimmed.isEmpty ? nil : trimmed
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel("Save note")
                }
            }
        }
        .onAppear { draft = item.note ?? "" }
    }
}

#Preview { NavigationStack { ChecklistListView() } }
