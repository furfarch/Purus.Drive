import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SectionsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var showingAddVehicle = false

    @State private var showingSettings = false

    @State private var showingExport = false
    @State private var exportScope: ExportScope = .all
    @State private var exportFormat: ExportFormat = .json

    @State private var shareURL: URL? = nil
    @State private var showingShareSheet = false
    @State private var exportError: String? = nil
    /// Settings asks for Export/Import while it is closing; a second sheet can only open after that
    @State private var afterSettings: (() -> Void)? = nil

    @State private var showingImportPicker = false
    @State private var importAlertTitle: String? = nil
    @State private var importAlertMessage: String? = nil
    
    @State private var showingConflicts = false
    @ObservedObject private var conflictStore = SyncConflictStore.shared

    @Query(sort: \Vehicle.lastEdited, order: .reverse) private var vehicles: [Vehicle]
    @Query(sort: \Trailer.lastEdited, order: .reverse) private var trailers: [Trailer]
    @Query(sort: \DriveLog.date, order: .reverse) private var logs: [DriveLog]
    @Query(sort: \Checklist.lastEdited, order: .reverse) private var checklists: [Checklist]

    // Wide screen (iPhone Duo unfolded, iPad): list left, vehicle right. The Duo reports compact width, so the real width decides too.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var screenWidth: CGFloat = 0
    @State private var selection: VehicleSelection? = nil
    private var isWide: Bool { horizontalSizeClass == .regular || screenWidth >= 560 }

    var body: some View {
        Group {
            if isWide {
                HStack(spacing: 0) {
                    listStack
                        .frame(width: min(320, max(240, screenWidth * 0.36)))
                    Divider()
                    VehicleDetailColumn(selection: $selection)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                listStack
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { screenWidth = $0 }
    }

    private var listStack: some View {
        NavigationStack {
            VehiclesListView(selection: isWide ? $selection : nil)
                .navigationTitle("Vehicles")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                            .accessibilityLabel("Settings")
                    }

                    // Upper-right: only export/import and +
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        StorageModeBadge()
                        Button { showingAddVehicle = true } label: { Image(systemName: "plus") }
                            .accessibilityLabel("Add Vehicle")
                    }
                }
                .sheet(isPresented: $showingSettings, onDismiss: {
                    afterSettings?()
                    afterSettings = nil
                }) {
                    NavigationStack {
                        SettingsView(
                            startExportFlow: { afterSettings = { showingExport = true } },
                            startImportFlow: { afterSettings = { showingImportPicker = true } }
                        )
                        .navigationTitle("Settings")
                    }
                }
                .sheet(isPresented: $showingAddVehicle) {
                    NavigationStack { VehicleFormView(vehicle: nil) }
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
                                        exportError = error.localizedDescription
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
                        // presented from the export sheet: a sibling sheet can't open while this one is up
                        .sheet(isPresented: $showingShareSheet, onDismiss: {
                            if let shareURL { try? FileManager.default.removeItem(at: shareURL) }
                            shareURL = nil
                        }) {
                            if let url = shareURL {
                                ShareSheet(items: [url])
                            }
                        }
                        .alert("Export failed", isPresented: Binding(
                            get: { exportError != nil },
                            set: { if !$0 { exportError = nil } }
                        )) {
                            Button("OK", role: .cancel) {}
                        } message: {
                            Text(exportError ?? "")
                        }
                    }
                }
                .fileImporter(
                    isPresented: $showingImportPicker,
                    allowedContentTypes: [UTType.json],
                    allowsMultipleSelection: false
                ) { result in
                    do {
                        let url = try result.gettingOneURL()
                        // files from Files/iCloud Drive are outside the sandbox (false = no scope needed, read may still work)
                        let scoped = url.startAccessingSecurityScopedResource()
                        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                        let data = try Data(contentsOf: url)
                        let summary = try ImportService.importJSON(data: data, into: modelContext)
                        importAlertTitle = "Import complete"
                        importAlertMessage = "Created: \(summary.totalCreated) • Updated: \(summary.totalUpdated)"
                            + (summary.skipped > 0 ? " • Skipped: \(summary.skipped)" : "")
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
                .sheet(isPresented: $showingConflicts) {
                    SyncConflictView()
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SyncConflictsDetected"))) { _ in
                    // Check if there are conflicts after sync
                    if conflictStore.hasUnresolvedConflicts() {
                        showingConflicts = true
                    }
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

private struct StorageModeBadge: View {
    @State private var isICloud: Bool = {
        let raw = UserDefaults.standard.string(forKey: "storageLocation") ?? StorageLocation.local.rawValue
        return raw == StorageLocation.icloud.rawValue
    }()

    var body: some View {
        let symbol = isICloud ? "icloud" : "internaldrive"
        let color: Color = isICloud ? .blue : .secondary
        Image(systemName: symbol)
            .foregroundStyle(color)
            .accessibilityLabel(isICloud ? "Using iCloud" : "Using Local Storage")
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                let raw = UserDefaults.standard.string(forKey: "storageLocation") ?? StorageLocation.local.rawValue
                isICloud = (raw == StorageLocation.icloud.rawValue)
            }
    }
}

#Preview {
    SectionsView()
}
