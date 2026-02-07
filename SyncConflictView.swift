import SwiftUI
import CloudKit

struct SyncConflictView: View {
    @ObservedObject var conflictStore = SyncConflictStore.shared
    @State private var selectedResolutions: [UUID: ConflictResolution] = [:]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if conflictStore.conflicts.isEmpty {
                    Section {
                        Text("No sync conflicts detected")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(conflictStore.conflicts) { conflict in
                        Section {
                            VStack(alignment: .leading, spacing: 12) {
                                // Header
                                HStack {
                                    Image(systemName: iconName(for: conflict.entityType))
                                        .foregroundStyle(.orange)
                                    Text(conflict.entityType)
                                        .font(.headline)
                                }
                                
                                // Conflict info
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Local version: \(conflict.localLastEdited, style: .date) at \(conflict.localLastEdited, style: .time)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    
                                    Text("Remote version: \(conflict.remoteLastEdited, style: .date) at \(conflict.remoteLastEdited, style: .time)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                                
                                // Resolution options
                                VStack(spacing: 8) {
                                    Button {
                                        selectedResolutions[conflict.id] = .keepLocal
                                    } label: {
                                        HStack {
                                            Image(systemName: selectedResolutions[conflict.id] == .keepLocal ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(selectedResolutions[conflict.id] == .keepLocal ? .green : .secondary)
                                            Text("Keep my local version")
                                            Spacer()
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button {
                                        selectedResolutions[conflict.id] = .keepRemote
                                    } label: {
                                        HStack {
                                            Image(systemName: selectedResolutions[conflict.id] == .keepRemote ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(selectedResolutions[conflict.id] == .keepRemote ? .green : .secondary)
                                            Text("Accept remote version")
                                            Spacer()
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Sync Conflicts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applyResolutions()
                    }
                    .disabled(!canApply)
                }
            }
        }
    }
    
    private var canApply: Bool {
        // All conflicts must have a resolution selected
        conflictStore.conflicts.allSatisfy { conflict in
            selectedResolutions[conflict.id] != nil && selectedResolutions[conflict.id] != .pending
        }
    }
    
    private func applyResolutions() {
        Task {
            for conflict in conflictStore.conflicts {
                if let resolution = selectedResolutions[conflict.id], resolution != .pending {
                    await CloudKitSyncService.shared.resolveConflict(conflict, resolution: resolution)
                }
            }
            
            // Clear resolved conflicts
            await MainActor.run {
                conflictStore.clearResolved()
                dismiss()
            }
        }
    }
    
    private func iconName(for entityType: String) -> String {
        switch entityType {
        case "Vehicle":
            return "car"
        case "Trailer":
            return "trailer"
        case "DriveLog":
            return "road.lanes"
        case "Checklist":
            return "checklist"
        default:
            return "doc"
        }
    }
}

#Preview {
    SyncConflictView()
}
