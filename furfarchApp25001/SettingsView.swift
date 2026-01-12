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
        CKContainer(identifier: "iCloud.com.furfarch.MyDriverLog").accountStatus { [weak self] status, error in
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

    // Default local.
    @AppStorage("storageLocation") private var storageLocationRaw: String = StorageLocation.local.rawValue

    @StateObject private var cloudStatus = CloudStatusViewModel()
    @State private var showRestartHint = false

    private var selectionBinding: Binding<StorageLocation> {
        Binding(
            get: { StorageLocation(rawValue: storageLocationRaw) ?? .local },
            set: { newValue in
                storageLocationRaw = newValue.rawValue
                // Switching stores requires app restart because ModelContainer is created at launch.
                showRestartHint = true
            }
        )
    }

    var body: some View {
        Form {
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
    }
}
