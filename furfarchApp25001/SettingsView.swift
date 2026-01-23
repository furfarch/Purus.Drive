import SwiftUI
import CloudKit
import Combine

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

@MainActor
final class CloudStatusViewModel: ObservableObject {
    @Published var accountStatusText: String = "Checking…"
    @Published var isICloudAvailable: Bool = false

    func refresh() {
        CKContainer(identifier: "iCloud.com.simplydrive.app").accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                if let error {
                    self?.accountStatusText = "Error: \(error.localizedDescription)"
                    self?.isICloudAvailable = false
                    return
                }

                switch status {
                case .available:
                    self?.accountStatusText = "Available"
                    self?.isICloudAvailable = true
                case .noAccount:
                    self?.accountStatusText = "No iCloud account"
                    self?.isICloudAvailable = false
                case .restricted:
                    self?.accountStatusText = "Restricted"
                    self?.isICloudAvailable = false
                case .couldNotDetermine:
                    self?.accountStatusText = "Could not determine"
                    self?.isICloudAvailable = false
                case .temporarilyUnavailable:
                    self?.accountStatusText = "Temporarily unavailable"
                    self?.isICloudAvailable = false
                @unknown default:
                    self?.accountStatusText = "Unknown"
                    self?.isICloudAvailable = false
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

            Section {
                Button("Close") { dismiss() }
            }
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
