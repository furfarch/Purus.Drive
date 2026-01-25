import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SectionsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var showingAbout = false
    @State private var showingAddVehicle = false

    @State private var showingSettings = false

    @State private var showingExport = false
    @State private var exportScope: ExportScope = .all
    @State private var exportFormat: ExportFormat = .json

    @State private var shareURL: URL? = nil
    @State private var showingShareSheet = false

    @State private var showingImportPicker = false
    @State private var importAlertTitle: String? = nil
    @State private var importAlertMessage: String? = nil

    @Query(sort: \Vehicle.lastEdited, order: .reverse) private var vehicles: [Vehicle]
    @Query(sort: \Trailer.lastEdited, order: .reverse) private var trailers: [Trailer]
    @Query(sort: \DriveLog.date, order: .reverse) private var logs: [DriveLog]
    @Query(sort: \Checklist.lastEdited, order: .reverse) private var checklists: [Checklist]

    var body: some View {
        NavigationStack {
            VehiclesListView()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // About should be the upper-left item.
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showingAbout = true } label: { Image(systemName: "info.circle") }
                            .accessibilityLabel("About")
                    }

                    ToolbarItem(placement: .topBarLeading) {
                        Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                            .accessibilityLabel("Settings")
                    }

                    // Upper-right: only export/import and +
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button { showingAddVehicle = true } label: { Image(systemName: "plus") }
                            .accessibilityLabel("Add Vehicle")
                    }
                }
                .sheet(isPresented: $showingAbout) {
                    NavigationStack { AboutView().navigationTitle("About") }
                }
                .sheet(isPresented: $showingSettings) {
                    NavigationStack {
                        SettingsView(
                            startExportFlow: { showingExport = true },
                            startImportFlow: { showingImportPicker = true }
                        )
                        .navigationTitle("Settings")
                    }
                }
                .sheet(isPresented: $showingAddVehicle) {
                    NavigationStack { AddVehicleFlowView() }
                }
                .sheet(isPresented: $showingExport) {
                    NavigationStack {
                        Form {
                            Section("What to export") {
                                Picker("Scope", selection: $exportScope) {
                                    ForEach(ExportScope.allCases) { s in
                                        Text(s.title).tag(s)
                                    }
                                }
                            }

                            Section("Format") {
                                Picker("Format", selection: $exportFormat) {
                                    ForEach(ExportFormat.allCases) { f in
                                        Text(f.displayName).tag(f)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }

                            Section {
                                Button {
                                    do {
                                        let (name, data) = try ExportService.exportData(
                                            scope: exportScope,
                                            format: exportFormat,
                                            vehicles: vehicles,
                                            trailers: trailers,
                                            logs: logs,
                                            checklists: checklists
                                        )

                                        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
                                        try data.write(to: url, options: [.atomic])
                                        shareURL = url
                                        showingShareSheet = true
                                    } catch {
                                        print("ERROR: export failed: \(error)")
                                    }
                                } label: {
                                    Label("Generate Export", systemImage: "doc.badge.plus")
                                }
                            }
                        }
                        .navigationTitle("Export")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showingExport = false }
                            }
                        }
                    }
                }
                .sheet(isPresented: $showingShareSheet) {
                    if let url = shareURL {
                        ShareSheet(items: [url])
                    }
                }
                .fileImporter(
                    isPresented: $showingImportPicker,
                    allowedContentTypes: [UTType.json],
                    allowsMultipleSelection: false
                ) { result in
                    do {
                        let url = try result.gettingOneURL()
                        let data = try Data(contentsOf: url)
                        let summary = try ImportService.importJSON(data: data, into: modelContext)
                        importAlertTitle = "Import complete"
                        importAlertMessage = "Created: \(summary.totalCreated) • Updated: \(summary.totalUpdated)"
                    } catch {
                        importAlertTitle = "Import failed"
                        importAlertMessage = error.localizedDescription
                    }
                }
                .alert(importAlertTitle ?? "", isPresented: Binding(
                    get: { importAlertTitle != nil },
                    set: { if !$0 { importAlertTitle = nil; importAlertMessage = nil } }
                )) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(importAlertMessage ?? "")
                }
        }
    }
}

private extension Result where Success == [URL] {
    func gettingOneURL() throws -> URL {
        let urls = try get()
        if let first = urls.first { return first }
        throw ImportService.ImportError.unsupportedFormat
    }
}

#Preview {
    SectionsView()
}
