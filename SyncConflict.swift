import Foundation
import CloudKit
import Combine

/// Represents a sync conflict between local and remote data.
struct SyncConflict: Identifiable {
    let id: UUID
    let entityType: String // "Vehicle", "Trailer", "DriveLog", "Checklist"
    let entityID: UUID
    let localLastEdited: Date
    let remoteLastEdited: Date
    let remoteRecord: CKRecord
    
    init(entityType: String, entityID: UUID, localLastEdited: Date, remoteLastEdited: Date, remoteRecord: CKRecord) {
        self.id = UUID()
        self.entityType = entityType
        self.entityID = entityID
        self.localLastEdited = localLastEdited
        self.remoteLastEdited = remoteLastEdited
        self.remoteRecord = remoteRecord
    }
}

/// Resolution choice for a sync conflict
enum ConflictResolution {
    case keepLocal      // Keep the local version, push it to cloud
    case keepRemote     // Accept the remote version, overwrite local
    case pending        // Not yet resolved by user
}

/// Stores pending sync conflicts for user resolution
@MainActor
final class SyncConflictStore: ObservableObject {
    static let shared = SyncConflictStore()
    
    @Published var conflicts: [SyncConflict] = []
    @Published var resolutions: [UUID: ConflictResolution] = [:]
    
    private init() {}
    
    func addConflict(_ conflict: SyncConflict) {
        // Avoid duplicates
        if !conflicts.contains(where: { $0.entityID == conflict.entityID && $0.entityType == conflict.entityType }) {
            conflicts.append(conflict)
            resolutions[conflict.id] = .pending
        }
    }
    
    func resolve(conflictID: UUID, resolution: ConflictResolution) {
        resolutions[conflictID] = resolution
    }
    
    func clearResolved() {
        conflicts.removeAll { conflict in
            resolutions[conflict.id] != .pending
        }
    }
    
    func hasUnresolvedConflicts() -> Bool {
        conflicts.contains { resolutions[$0.id] == .pending }
    }
    
    func clearAll() {
        conflicts.removeAll()
        resolutions.removeAll()
    }
}
