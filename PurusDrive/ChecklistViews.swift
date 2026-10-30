import SwiftUI
import SwiftData

// Checklist editor (moved here so all references compile)
struct ChecklistEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var checklist: Checklist

    @State private var showingDeleteConfirm = false

    private var orderedSections: [String] {
        let present = Set((checklist.items ?? []).map { $0.section })
        let preferred = ChecklistTemplates.sectionOrder(for: checklist.vehicleType)
        let inPreferred = preferred.filter { present.contains($0) }
        let remainder = present.subtracting(inPreferred).sorted()
        return inPreferred + remainder
    }

    private var layout: [String: (subsection: String?, index: Int)] {
        ChecklistTemplates.layout(for: checklist.vehicleType)
    }

    /// items of a section in template order; items not in the template (older lists) follow A-Z
    private func items(in section: String, layout: [String: (subsection: String?, index: Int)]) -> [ChecklistItem] {
        (checklist.items ?? []).filter { $0.section == section }.sorted { a, b in
            let ia = layout[ChecklistTemplates.layoutKey(section, a.title)]?.index ?? Int.max
            let ib = layout[ChecklistTemplates.layoutKey(section, b.title)]?.index ?? Int.max
            if ia != ib { return ia < ib }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }
    }

    /// items of a section split by subsection (template order)
    private func grouped(_ items: [ChecklistItem], in section: String, layout: [String: (subsection: String?, index: Int)]) -> [(subsection: String?, items: [ChecklistItem])] {
        var result: [(subsection: String?, items: [ChecklistItem])] = []
        for item in items {
            let sub = layout[ChecklistTemplates.layoutKey(section, item.title)]?.subsection
            if let last = result.last, last.subsection == sub { result[result.count - 1].items.append(item) }
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

    /// local save on every tap (as before); Done also syncs
    private func saveLocal() {
        checklist.lastEdited = .now
        do { try modelContext.save() } catch { print("ERROR: failed saving checklist: \(error)") }
    }

    var body: some View {
        // after Delete the object is gone while the sheet is still dismissing; reading it would crash
        if checklist.modelContext == nil { Color.clear } else { content }
    }

    private func saveAndClose() {
        checklist.lastEdited = .now
        do { try modelContext.save() } catch { print("ERROR: failed saving checklist: \(error)") }
        Task { await CloudKitSyncService.shared.pushAllToCloud() }
        dismiss()
    }

    private var content: some View {
        let layout = self.layout
        return Group {
            if orderedSections.isEmpty {
                ContentUnavailableView("No items", systemImage: "checklist", description: Text("This checklist has no items."))
            } else {
                // FinAI style: one collapsible line per part with a summary, first part open
                List {
                    ForEach(Array(orderedSections.enumerated()), id: \.offset) { index, section in
                        let sectionItems = items(in: section, layout: layout)
                        Section {
                            Fold(title: section, summary: summary(sectionItems), open: index == 0) {
                                ForEach(Array(grouped(sectionItems, in: section, layout: layout).enumerated()), id: \.offset) { _, group in
                                    if let sub = group.subsection {
                                        Text(sub).font(.caption).foregroundStyle(.secondary)
                                    }
                                    ForEach(group.items) { item in
                                        ChecklistCardItemRow(item: item, onChange: saveLocal)
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
            // a live checklist run saves every tap, so there is nothing to cancel: Done saves and syncs
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { saveAndClose() }
                    .fontWeight(.semibold)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showingDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete")
            }
        }
        .confirmationDialog("Delete this checklist?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                dismiss()
                deleteChecklistLocally(checklist, in: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
    }
}

private struct ChecklistCardItemRow: View {
    @Bindable var item: ChecklistItem
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
                TextField("Note", text: Binding(
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

/// Deletes a checklist with its items, clears drive-log links and tombstones it for iCloud.
@MainActor
func deleteChecklistLocally(_ cl: Checklist, in context: ModelContext) {
    for log in (try? context.fetch(FetchDescriptor<DriveLog>())) ?? [] where log.checklist === cl { log.checklist = nil }
    CloudKitSyncService.shared.markDeleted(entityType: "Checklist", id: cl.id)
    for i in cl.items ?? [] { context.delete(i) }
    context.delete(cl)
    do { try context.save() } catch { print("ERROR: failed deleting checklist: \(error)") }
    Task { await CloudKitSyncService.shared.pushDeletions() }
    NotificationCenter.default.post(name: Notification.Name("RequestFullSyncNotification"), object: nil)
}
