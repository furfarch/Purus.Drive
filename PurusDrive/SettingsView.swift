import SwiftUI
import CloudKit
import Combine
import UIKit

enum StorageLocation: String, CaseIterable, Identifiable {
    case local
    case icloud

    var id: String { rawValue }

    var title: String {
        switch self {
        case .local: return "Local"
        case .icloud: return "iCloud"
        }
    }
}

// Global diagnostics - set by PurusDriveApp.init()
enum CloudKitDiagnostics {
    static var containerCreationResult: String = "Not checked"
    static var containerError: String? = nil
    static var storageMode: String = "Unknown"
    static let containerID = "iCloud.com.purus.driver"
}

@MainActor
final class CloudStatusViewModel: ObservableObject {
    @Published var accountStatusText: String = "Checking…"
    @Published var accountStatusRaw: String = ""
    @Published var isICloudAvailable: Bool = false
    @Published var userRecordID: String = "Checking..."
    @Published var privateDBStatus: String = "Checking..."

    private let container = CKContainer(identifier: CloudKitDiagnostics.containerID)

    func refresh() {
        // Check account status
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                if let error {
                    self?.accountStatusText = "Error: \(error.localizedDescription)"
                    self?.accountStatusRaw = "error"
                    self?.isICloudAvailable = false
                    return
                }

                switch status {
                case .available:
                    self?.accountStatusText = "Available"
                    self?.accountStatusRaw = "available"
                    self?.isICloudAvailable = true
                case .noAccount:
                    self?.accountStatusText = "No iCloud account"
                    self?.accountStatusRaw = "noAccount"
                    self?.isICloudAvailable = false
                case .restricted:
                    self?.accountStatusText = "Restricted"
                    self?.accountStatusRaw = "restricted"
                    self?.isICloudAvailable = false
                case .couldNotDetermine:
                    self?.accountStatusText = "Could not determine"
                    self?.accountStatusRaw = "couldNotDetermine"
                    self?.isICloudAvailable = false
                case .temporarilyUnavailable:
                    self?.accountStatusText = "Temporarily unavailable"
                    self?.accountStatusRaw = "temporarilyUnavailable"
                    self?.isICloudAvailable = false
                @unknown default:
                    self?.accountStatusText = "Unknown"
                    self?.accountStatusRaw = "unknown"
                    self?.isICloudAvailable = false
                }
            }
        }

        // Fetch user record ID
        container.fetchUserRecordID { [weak self] recordID, error in
            DispatchQueue.main.async {
                if let error {
                    self?.userRecordID = "Error: \(error.localizedDescription)"
                } else if let recordID {
                    self?.userRecordID = recordID.recordName
                } else {
                    self?.userRecordID = "None"
                }
            }
        }

        // Test private database access
        let privateDB = container.privateCloudDatabase
        privateDB.fetchAllRecordZones { [weak self] zones, error in
            DispatchQueue.main.async {
                if let error {
                    self?.privateDBStatus = "Error: \(error.localizedDescription)"
                } else if let zones {
                    let zoneNames = zones.map { $0.zoneID.zoneName }.joined(separator: ", ")
                    self?.privateDBStatus = zones.isEmpty ? "No zones" : zoneNames
                } else {
                    self?.privateDBStatus = "Unknown"
                }
            }
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    let startExportFlow: () -> Void
    let startImportFlow: () -> Void

    // Default local.
    @AppStorage("storageLocation") private var storageLocationRaw: String = StorageLocation.local.rawValue

    @StateObject private var cloudStatus = CloudStatusViewModel()

    @State private var showRestartHint = false
    @State private var showICloudUnavailableAlert = false

    @State private var showResetConfirm = false
    @State private var showResetFailed = false
    @State private var resetFailedMessage: String = ""

    private var selectionBinding: Binding<StorageLocation> {
        Binding(
            get: { StorageLocation(rawValue: storageLocationRaw) ?? .local },
            set: { newValue in
                if newValue == .icloud, !cloudStatus.isICloudAvailable {
                    storageLocationRaw = StorageLocation.local.rawValue
                    showICloudUnavailableAlert = true
                    return
                }

                storageLocationRaw = newValue.rawValue
                UserDefaults.standard.set(newValue.rawValue, forKey: "storageLocation")
                // Switching stores requires app restart because ModelContainer is created at launch.
                showRestartHint = true
            }
        )
    }

    var body: some View {
        Form {
            Section("Import / Export") {
                Button {
                    dismiss()
                    startExportFlow()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }

                Button {
                    dismiss()
                    startImportFlow()
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
            }

            Section("Storage") {
                Picker("Storage location", selection: selectionBinding) {
                    ForEach(StorageLocation.allCases) { choice in
                        Text(choice.title).tag(choice)
                    }
                }

                if selectionBinding.wrappedValue == .icloud {
                    LabeledContent("iCloud status") {
                        Text(cloudStatus.accountStatusText)
                            .foregroundStyle(cloudStatus.isICloudAvailable ? Color.secondary : Color.red)
                    }

                    if !cloudStatus.isICloudAvailable {
                        Text("If iCloud isn’t available, the app will fall back to local storage.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button("Refresh iCloud status") {
                        cloudStatus.refresh()
                    }

                    Button {
                        NotificationCenter.default.post(name: Notification.Name("RequestFullSyncNotification"), object: nil)
                    } label: {
                        Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                    }

                    if let report = SyncReportStore.shared.lastReport {
                        LabeledContent("Last Sync") {
                            Text(report.finishedAt?.formatted(date: .abbreviated, time: .standard) ?? "In progress")
                                .foregroundStyle(.secondary)
                        }
                        LabeledContent("Pushed") {
                            Text(report.pushed.map { "\($0.key): \($0.value)" }.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        LabeledContent("Fetched") {
                            Text(report.fetched.map { "\($0.key): \($0.value)" }.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let err = report.error {
                            Text("Error: \(err)")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        Button("Copy Sync Report") {
                            let df = ISO8601DateFormatter()
                            let started = df.string(from: report.startedAt)
                            let finished = report.finishedAt.map { df.string(from: $0) } ?? "-"
                            var lines: [String] = []
                            lines.append("Mode: \(report.mode)")
                            lines.append("Started: \(started)")
                            lines.append("Finished: \(finished)")
                            lines.append("Pushed: \(report.pushed)")
                            lines.append("Fetched: \(report.fetched)")
                            if let err = report.error { lines.append("Error: \(err)") }
                            UIPasteboard.general.string = lines.joined(separator: "\n")
                        }
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label("Reset Local Database", systemImage: "trash")
                }

                Text("This deletes the local database on this device. The app will close and needs to be reopened.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

#if false
            Section("About") {
                LabeledContent("Version") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Build") {
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Bundle Identifier") {
                    Text(Bundle.main.bundleIdentifier ?? "-")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
#endif

            Section {
                Button("Close") { dismiss() }
            }

#if DEBUG
            // Debug section - shows CloudKit diagnostics
            Section("CloudKit Diagnostics") {
                LabeledContent("Storage Mode") {
                    Text(CloudKitDiagnostics.storageMode)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Container ID") {
                    Text(CloudKitDiagnostics.containerID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Container Init") {
                    Text(CloudKitDiagnostics.containerCreationResult)
                        .foregroundStyle(CloudKitDiagnostics.containerError == nil ? .green : .red)
                }

                if let error = CloudKitDiagnostics.containerError {
                    Text("Error: \(error)")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                LabeledContent("Account Status") {
                    Text(cloudStatus.accountStatusText)
                        .foregroundStyle(cloudStatus.isICloudAvailable ? .green : .red)
                }

                LabeledContent("User Record ID") {
                    Text(cloudStatus.userRecordID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                LabeledContent("Private DB Zones") {
                    Text(cloudStatus.privateDBStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Refresh Diagnostics") {
                    cloudStatus.refresh()
                }

                Button("Copy Diagnostics") {
                    let diagnostics = """
                    Storage Mode: \(CloudKitDiagnostics.storageMode)
                    Container ID: \(CloudKitDiagnostics.containerID)
                    Container Init: \(CloudKitDiagnostics.containerCreationResult)
                    Container Error: \(CloudKitDiagnostics.containerError ?? "None")
                    Account Status: \(cloudStatus.accountStatusText) (\(cloudStatus.accountStatusRaw))
                    User Record ID: \(cloudStatus.userRecordID)
                    Private DB Zones: \(cloudStatus.privateDBStatus)
                    """
                    UIPasteboard.general.string = diagnostics
                }
            }
#endif
        }
        .navigationTitle("Settings")
        .onAppear { cloudStatus.refresh() }
        .alert("Restart required", isPresented: $showRestartHint) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("To fully switch storage location, close and re-open the app.")
        }
        .alert("iCloud unavailable", isPresented: $showICloudUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("iCloud isn’t available on this device/account right now. The app will keep using local storage.")
        }
        .confirmationDialog(
            "Reset local database?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                do {
                    try DatabaseResetService.resetApplicationSupport()
                    DatabaseResetService.terminateForRelaunch()
                } catch {
                    resetFailedMessage = error.localizedDescription
                    showResetFailed = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes ALL locally stored vehicles, trailers, checklists, and drive logs on this device. It won’t delete iCloud data.")
        }
        .alert("Reset failed", isPresented: $showResetFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resetFailedMessage)
        }
    }
}
