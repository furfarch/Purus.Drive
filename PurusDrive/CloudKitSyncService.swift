import Foundation
import CloudKit
import SwiftData
import UIKit

/// Manual CloudKit sync service for Purus Drive.
/// Uses local SwiftData storage and manually syncs to CloudKit.
@MainActor
final class CloudKitSyncService {
    static let shared = CloudKitSyncService()
    /// start time of the last sync that finished without errors; "changed since last sync" is measured against it
    static let lastSyncKey = "lastCloudSyncAt"

    private let containerID = "iCloud.com.purus.driver"
    private let zoneName = "com.apple.coredata.cloudkit.zone"

    private lazy var container: CKContainer = {
        CKContainer(identifier: containerID)
    }()

    private lazy var privateDatabase: CKDatabase = {
        container.privateCloudDatabase
    }()

    private lazy var recordZone: CKRecordZone = {
        CKRecordZone(zoneName: zoneName)
    }()

    private var modelContext: ModelContext?
    private let reportStore = SyncReportStore.shared
    private let conflictStore = SyncConflictStore.shared

    private var isSyncing = false
    private var rerunRequested = false
    private var report = SyncReport(startedAt: Date(), finishedAt: nil, mode: "iCloud")
    /// ids with a CD_Deleted record in iCloud (deleted on some device); never imported or pushed
    private var remoteTombstoneIDs: Set<UUID> = []
    /// checklists whose iCloud version was applied in this sync; only their items take the iCloud item fields
    private var remoteAppliedChecklistIDs: Set<UUID> = []

    private var isICloudMode: Bool {
        UserDefaults.standard.string(forKey: "storageLocation") == StorageLocation.icloud.rawValue
    }

    private var lastSync: Date? {
        UserDefaults.standard.object(forKey: Self.lastSyncKey) as? Date
    }

    private init() {}

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Report

    private func recordError(_ what: String, _ error: Error) {
        print("CloudKit: \(what) error - \(error)")
        let line = "\(what): \(error.localizedDescription)"
        report.error = report.error.map { "\($0)\n\(line)" } ?? line
    }

    private func count(_ name: Notification.Name, _ type: String, _ n: Int) {
        if name == .syncFetchedCount { report.fetched[type, default: 0] += n }
        if name == .syncPushedCount { report.pushed[type, default: 0] += n }
        NotificationCenter.default.post(name: name, object: nil, userInfo: ["type": type, "count": n])
    }

    // MARK: - Tombstone Helpers

    private func localDelete(entityType: String, id: UUID, context: ModelContext) throws {
        switch entityType {
        case "Vehicle":
            if let v = try vehicle(id, context) {
                if let logs = v.driveLogs { for l in logs { context.delete(l) } }
                if let cls = v.checklists { for c in cls { deleteChecklist(c, context: context) } }
                v.trailer?.linkedVehicle = nil
                context.delete(v)
            }
        case "Trailer":
            if let t = try trailer(id, context) {
                if let cls = t.checklists { for c in cls { deleteChecklist(c, context: context) } }
                t.linkedVehicle?.trailer = nil
                context.delete(t)
            }
        case "DriveLog":
            if let l = try driveLog(id, context) { context.delete(l) }
        case "Checklist":
            if let c = try checklist(id, context) { deleteChecklist(c, context: context) }
        case "ChecklistItem":
            if let i = try checklistItem(id, context) { context.delete(i) }
        case "WorkBlock":
            if let b = try workBlock(id, context) { context.delete(b) }
        default: break
        }
    }

    private func deleteChecklist(_ c: Checklist, context: ModelContext) {
        for log in c.driveLogs ?? [] { log.checklist = nil }
        // items have no delete cascade; without this they stay behind as orphans
        for i in c.items ?? [] { context.delete(i) }
        context.delete(c)
    }

    private func tombstoneRecord(for ts: DeletedRecord) -> CKRecord {
        let recID = CKRecord.ID(recordName: "CD_Deleted_\(ts.entityType)_\(ts.id.uuidString)", zoneID: recordZone.zoneID)
        let rec = CKRecord(recordType: "CD_Deleted", recordID: recID)
        rec["entityType"] = ts.entityType
        rec["entityID"] = ts.id.uuidString
        rec["deletedAt"] = ts.deletedAt
        return rec
    }

    /// lastEdited of the local record (items use their checklist's), nil if it does not exist
    private func localLastEdited(entityType: String, id: UUID, context: ModelContext) throws -> Date? {
        switch entityType {
        case "Vehicle": return try vehicle(id, context)?.lastEdited
        case "Trailer": return try trailer(id, context)?.lastEdited
        case "DriveLog": return try driveLog(id, context)?.lastEdited
        case "Checklist": return try checklist(id, context)?.lastEdited
        case "ChecklistItem": return try checklistItem(id, context)?.checklist?.lastEdited
        case "WorkBlock": return try workBlock(id, context)?.lastEdited
        default: return nil
        }
    }

    // MARK: - Conflict Detection

    private enum RemoteDecision { case apply, keepLocal, conflict }

    /// Newer remote wins. A conflict is only when both sides changed since the last sync
    /// (or the record already has an open conflict, so an old decision isn't silently overwritten).
    private func decide(id: UUID, local: Date, remote: Date, allowConflict: Bool) -> RemoteDecision {
        if allowConflict && pendingConflictIDs.contains(id) { return .conflict }
        guard remote > local else { return .keepLocal }
        if allowConflict, let last = lastSync, local > last { return .conflict }
        return .apply
    }

    private var pendingConflictIDs: Set<UUID> {
        Set(conflictStore.conflicts.filter { conflictStore.resolutions[$0.id] == .pending }.map(\.entityID))
    }

    /// Fetch remote tombstones and apply local deletions. Tombstones stay in CloudKit so all devices can consume them.
    private func fetchRemoteTombstones(context: ModelContext) async throws {
        let records = try await fetchRecords(query: CKQuery(recordType: "CD_Deleted", predicate: NSPredicate(value: true)))
        var ids = Set<UUID>()
        var revived: [CKRecord.ID] = []
        for rec in records {
            guard let rawType = rec["entityType"] as? String,
                  let idStr = rec["entityID"] as? String,
                  let uuid = UUID(uuidString: idStr) else { continue }
            let type = rawType.hasPrefix("CD_") ? String(rawType.dropFirst(3)) : rawType
            let deletedAt = rec["deletedAt"] as? Date ?? rec.modificationDate ?? .now

            // a record restored (e.g. imported) after it was deleted must survive the old tombstone
            if let edited = try localLastEdited(entityType: type, id: uuid, context: context), edited > deletedAt {
                revived.append(rec.recordID)
                continue
            }
            ids.insert(uuid)
            do { try localDelete(entityType: type, id: uuid, context: context) } catch { print("CloudKit: local delete error for \(type) id=\(idStr): \(error)") }
            // the iCloud tombstone already tells every device; the local one is done
            if let local = try context.fetch(FetchDescriptor<DeletedRecord>(predicate: #Predicate { $0.id == uuid })).first {
                context.delete(local)
            }
        }
        remoteTombstoneIDs = ids
        try context.save()
        if !revived.isEmpty {
            do { try await deleteCloudRecords(revived) } catch { recordError("Remove outdated deletions", error) }
        }
    }

    // MARK: - Public Sync Methods

    /// Performs a full sync: deletions, fetch, then push. Only in iCloud mode; calls during a running sync queue one rerun.
    func performFullSync() async {
        await runExclusive { await self.fullSync() }
    }

    /// Kept for callers after a save: a push without the fetch first would overwrite newer edits from other devices.
    func pushAllToCloud() async {
        await performFullSync()
    }

    /// Pushes pending local deletions (iCloud mode only).
    func pushDeletions() async {
        await runExclusive { await self.pushDeletionsNow() }
    }

    private func runExclusive(_ work: () async -> Void) async {
        guard isICloudMode, modelContext != nil else { return }
        if isSyncing { rerunRequested = true; return }
        isSyncing = true
        await work()
        while rerunRequested {
            rerunRequested = false
            await fullSync()
        }
        isSyncing = false
    }

    private func fullSync() async {
        guard let context = modelContext else { return }
        let startedAt = Date()
        report = SyncReport(startedAt: startedAt, finishedAt: nil, mode: "iCloud")
        reportStore.lastReport = report
        defer {
            report.finishedAt = Date()
            reportStore.lastReport = report
        }

        do {
            try await ensureZoneExists()
        } catch {
            recordError("Zone", error)
            return
        }

        // 1) Push local deletions first so deleted items can't come back with the fetch
        await pushDeletionsNow()

        // 2) Apply remote deletions, then fetch each type (one failure doesn't stop the others)
        var fetchFailed = false
        do { try await fetchRemoteTombstones(context: context) } catch { fetchFailed = true; recordError("Fetch deletions", error) }
        remoteAppliedChecklistIDs = []
        do { try await fetchTrailers(context: context) } catch { fetchFailed = true; recordError("Fetch trailers", error) }
        do { try await fetchVehicles(context: context) } catch { fetchFailed = true; recordError("Fetch vehicles", error) }
        do { try await fetchChecklists(context: context) } catch { fetchFailed = true; recordError("Fetch checklists", error) }
        do { try await fetchChecklistItems(context: context) } catch { fetchFailed = true; recordError("Fetch checklist items", error) }
        do { try await fetchDriveLogs(context: context) } catch { fetchFailed = true; recordError("Fetch drive logs", error) }
        do { try await fetchWorkBlocks(context: context) } catch { fetchFailed = true; recordError("Fetch work time", error) }
        do { try context.save() } catch { fetchFailed = true; recordError("Save after fetch", error) }

        // 3) Push local records — never after a failed download: it would overwrite edits we haven't seen
        if !fetchFailed {
            do { try await pushTrailers(context: context) } catch { recordError("Push trailers", error) }
            do { try await pushVehicles(context: context) } catch { recordError("Push vehicles", error) }
            do { try await pushChecklists(context: context) } catch { recordError("Push checklists", error) }
            do { try await pushChecklistItems(context: context) } catch { recordError("Push checklist items", error) }
            do { try await pushDriveLogs(context: context) } catch { recordError("Push drive logs", error) }
            do { try await pushWorkBlocks(context: context) } catch { recordError("Push work time", error) }
        }

        // 4) Deletions created during this sync
        await pushDeletionsNow()

        if report.error == nil { UserDefaults.standard.set(startedAt, forKey: Self.lastSyncKey) }
        print("CloudKit: full sync completed\(report.error == nil ? "" : " with errors")")

        if conflictStore.hasUnresolvedConflicts() {
            NotificationCenter.default.post(name: Notification.Name("SyncConflictsDetected"), object: nil)
        }
    }

    /// Fetches all records from CloudKit and imports them locally (used when switching to Local).
    func fetchAllFromCloud() async {
        guard let context = modelContext else { return }
        remoteAppliedChecklistIDs = []
        do { try await fetchTrailers(context: context) } catch { print("CloudKitSyncService: Fetch trailers error - \(error)") }
        do { try await fetchVehicles(context: context) } catch { print("CloudKitSyncService: Fetch vehicles error - \(error)") }
        do { try await fetchChecklists(context: context) } catch { print("CloudKitSyncService: Fetch checklists error - \(error)") }
        do { try await fetchChecklistItems(context: context) } catch { print("CloudKitSyncService: Fetch checklist items error - \(error)") }
        do { try await fetchDriveLogs(context: context) } catch { print("CloudKitSyncService: Fetch drive logs error - \(error)") }
        do { try await fetchWorkBlocks(context: context) } catch { print("CloudKitSyncService: Fetch work time error - \(error)") }
        do { try context.save() } catch { print("CloudKitSyncService: Failed to save after fetch - \(error)") }
    }

    /// Records a local deletion so it can be pushed to CloudKit (pushed right away in iCloud mode).
    func markDeleted(entityType: String, id: UUID, cascade: Bool = true, autoSync: Bool = true) {
        guard let context = modelContext else { return }
        addTombstone(entityType, id, context: context)

        if cascade {
            // Cascade tombstones for related entities so CloudKit deletes them as well
            switch entityType {
            case "Vehicle":
                if let v = try? vehicle(id, context) {
                    for l in v.driveLogs ?? [] { addTombstone("DriveLog", l.id, context: context) }
                    tombstoneChecklists(v.checklists, context: context)
                }
            case "Trailer":
                if let t = try? trailer(id, context) { tombstoneChecklists(t.checklists, context: context) }
            case "Checklist":
                if let c = try? checklist(id, context) {
                    for i in c.items ?? [] { addTombstone("ChecklistItem", i.id, context: context) }
                }
            default:
                break
            }
        }

        do { try context.save() } catch { print("CloudKit: failed saving tombstone(s): \(error)") }

        if autoSync {
            Task { @MainActor in await self.pushDeletions() }
        }
    }

    private func tombstoneChecklists(_ checklists: [Checklist]?, context: ModelContext) {
        for c in checklists ?? [] {
            addTombstone("Checklist", c.id, context: context)
            for i in c.items ?? [] { addTombstone("ChecklistItem", i.id, context: context) }
        }
    }

    private func addTombstone(_ entityType: String, _ id: UUID, context: ModelContext) {
        if let existing = try? context.fetch(FetchDescriptor<DeletedRecord>(predicate: #Predicate { $0.id == id })).first {
            existing.entityType = entityType
            existing.deletedAt = .now
        } else {
            context.insert(DeletedRecord(entityType: entityType, id: id, deletedAt: .now))
        }
    }

    // MARK: - Conflict Resolution

    /// Apply user's resolution choice for a detected conflict
    func resolveConflict(_ conflict: SyncConflict, resolution: ConflictResolution) async {
        guard let context = modelContext else { return }

        conflictStore.resolve(conflictID: conflict.id, resolution: resolution)

        switch resolution {
        case .keepLocal:
            await applyKeepLocal(conflict: conflict, context: context)
        case .keepRemote:
            await applyKeepRemote(conflict: conflict, context: context)
        case .pending:
            print("CloudKit: Warning - resolveConflict called with .pending resolution")
        }
    }

    private func applyKeepLocal(conflict: SyncConflict, context: ModelContext) async {
        let uuid = conflict.entityID
        // lastEdited = now, so the kept version also wins on the other devices
        do {
            switch conflict.entityType {
            case "Vehicle":
                guard let v = try vehicle(uuid, context) else { return }
                v.lastEdited = .now
                try context.save()
                try await pushVehicles(context: context)
            case "DriveLog":
                guard let l = try driveLog(uuid, context) else { return }
                l.lastEdited = .now
                try context.save()
                try await pushDriveLogs(context: context)
            case "Checklist":
                guard let c = try checklist(uuid, context) else { return }
                c.lastEdited = .now
                try context.save()
                try await pushChecklists(context: context)
                try await pushChecklistItems(context: context)
            default:
                print("CloudKit: Unknown entity type for conflict resolution: \(conflict.entityType)")
            }
        } catch {
            print("CloudKit: Error pushing local version: \(error)")
        }
    }

    private func applyKeepRemote(conflict: SyncConflict, context: ModelContext) async {
        let record = conflict.remoteRecord
        let uuid = conflict.entityID
        // the local record changed after this conflict was found: the old remote copy must not overwrite it
        func unchanged(_ edited: Date) -> Bool {
            if edited != conflict.localLastEdited { print("CloudKit: skip keep-remote for \(conflict.entityType) \(uuid), edited since"); return false }
            return true
        }

        do {
            switch conflict.entityType {
            case "Vehicle":
                if let v = try vehicle(uuid, context), unchanged(v.lastEdited) { try applyRemoteVehicle(record: record, to: v, context: context) }
            case "DriveLog":
                if let l = try driveLog(uuid, context), unchanged(l.lastEdited) { try applyRemoteDriveLog(record: record, to: l, context: context) }
            case "Checklist":
                if let c = try checklist(uuid, context), unchanged(c.lastEdited) {
                    try applyRemoteChecklist(record: record, to: c, context: context)
                    // its items were held back during the conflict; take the iCloud ones now
                    remoteAppliedChecklistIDs = [uuid]
                    try await fetchChecklistItems(context: context)
                }
            default:
                print("CloudKit: Unknown entity type for conflict resolution: \(conflict.entityType)")
            }
            try context.save()
        } catch {
            print("CloudKit: Error applying remote version: \(error)")
        }
    }

    // MARK: - Apply remote fields (used by fetch and by keep-remote)

    private func applyRemoteVehicle(record: CKRecord, to vehicle: Vehicle, context: ModelContext) throws {
        if let typeString = record["CD_type"] as? String, let type = VehicleType(rawValue: typeString) {
            vehicle.type = type
        }
        vehicle.brandModel = record["CD_brandModel"] as? String ?? ""
        vehicle.color = record["CD_color"] as? String ?? ""
        vehicle.plate = record["CD_plate"] as? String ?? ""
        vehicle.notes = record["CD_notes"] as? String ?? ""
        vehicle.photoData = record["CD_photoData"] as? Data
        if let lastEdited = record["CD_lastEdited"] as? Date { vehicle.lastEdited = lastEdited }

        if let t = try trailer(refUUID(record, "CD_trailer", prefix: "CD_Trailer_"), context) {
            vehicle.trailer = t
            t.linkedVehicle = vehicle
        } else if let linked = vehicle.trailer {
            linked.linkedVehicle = nil
            vehicle.trailer = nil
        }
    }

    private func applyRemoteTrailer(record: CKRecord, to trailer: Trailer) {
        trailer.brandModel = record["CD_brandModel"] as? String ?? ""
        trailer.color = record["CD_color"] as? String ?? ""
        trailer.plate = record["CD_plate"] as? String ?? ""
        trailer.notes = record["CD_notes"] as? String ?? ""
        trailer.photoData = record["CD_photoData"] as? Data
        if let lastEdited = record["CD_lastEdited"] as? Date { trailer.lastEdited = lastEdited }
    }

    private func applyRemoteDriveLog(record: CKRecord, to log: DriveLog, context: ModelContext) throws {
        if let date = record["CD_date"] as? Date { log.date = date }
        log.reason = record["CD_reason"] as? String ?? ""
        log.kmStart = record["CD_kmStart"] as? Int ?? 0
        log.kmEnd = record["CD_kmEnd"] as? Int ?? 0
        log.notes = record["CD_notes"] as? String ?? ""
        if let lastEdited = record["CD_lastEdited"] as? Date { log.lastEdited = lastEdited }
        log.vehicle = try vehicle(refUUID(record, "CD_vehicle", prefix: "CD_Vehicle_"), context)
        log.checklist = try checklist(refUUID(record, "CD_checklist", prefix: "CD_Checklist_"), context)
    }

    private func applyRemoteChecklist(record: CKRecord, to checklist: Checklist, context: ModelContext) throws {
        if let typeString = record["CD_vehicleType"] as? String, let type = VehicleType(rawValue: typeString) {
            checklist.vehicleType = type
        }
        checklist.title = record["CD_title"] as? String ?? ""
        if let lastEdited = record["CD_lastEdited"] as? Date { checklist.lastEdited = lastEdited }
        checklist.vehicle = try vehicle(refUUID(record, "CD_vehicle", prefix: "CD_Vehicle_"), context)
        checklist.trailer = try trailer(refUUID(record, "CD_trailer", prefix: "CD_Trailer_"), context)
        remoteAppliedChecklistIDs.insert(checklist.id)
    }

    private func applyRemoteWorkBlock(record: CKRecord, to b: WorkBlock) {
        if let a = (record["CD_activity"] as? String).flatMap({ WorkActivity(rawValue: $0) }) { b.activity = a }
        if let start = record["CD_start"] as? Date { b.start = start }
        b.end = record["CD_end"] as? Date
        b.vehiclePlate = record["CD_vehiclePlate"] as? String ?? ""
        b.vehicleName = record["CD_vehicleName"] as? String ?? ""
        b.kmStart = record["CD_kmStart"] as? Int
        b.kmEnd = record["CD_kmEnd"] as? Int
        b.placeStart = record["CD_placeStart"] as? String ?? ""
        b.placeEnd = record["CD_placeEnd"] as? String ?? ""
        b.exception = (record["CD_exception"] as? Int ?? 0) != 0
        b.note = record["CD_note"] as? String ?? ""
        if let lastEdited = record["CD_lastEdited"] as? Date { b.lastEdited = lastEdited }
    }

    private func applyRemoteChecklistItem(record: CKRecord, to item: ChecklistItem, context: ModelContext) throws {
        if let state = (record["CD_state"] as? String).flatMap({ ChecklistItemState(rawValue: $0) }) { item.state = state }
        item.section = record["CD_section"] as? String ?? ""
        item.title = record["CD_title"] as? String ?? ""
        item.note = record["CD_note"] as? String  // nil clears a removed note
        item.checklist = try checklist(refUUID(record, "CD_checklist", prefix: "CD_Checklist_"), context)
    }

    // MARK: - Local lookups

    private func vehicle(_ id: UUID?, _ context: ModelContext) throws -> Vehicle? {
        guard let id else { return nil }
        return try context.fetch(FetchDescriptor<Vehicle>(predicate: #Predicate { $0.id == id })).first
    }

    private func trailer(_ id: UUID?, _ context: ModelContext) throws -> Trailer? {
        guard let id else { return nil }
        return try context.fetch(FetchDescriptor<Trailer>(predicate: #Predicate { $0.id == id })).first
    }

    private func driveLog(_ id: UUID?, _ context: ModelContext) throws -> DriveLog? {
        guard let id else { return nil }
        return try context.fetch(FetchDescriptor<DriveLog>(predicate: #Predicate { $0.id == id })).first
    }

    private func checklist(_ id: UUID?, _ context: ModelContext) throws -> Checklist? {
        guard let id else { return nil }
        return try context.fetch(FetchDescriptor<Checklist>(predicate: #Predicate { $0.id == id })).first
    }

    private func checklistItem(_ id: UUID?, _ context: ModelContext) throws -> ChecklistItem? {
        guard let id else { return nil }
        return try context.fetch(FetchDescriptor<ChecklistItem>(predicate: #Predicate { $0.id == id })).first
    }

    private func workBlock(_ id: UUID?, _ context: ModelContext) throws -> WorkBlock? {
        guard let id else { return nil }
        return try context.fetch(FetchDescriptor<WorkBlock>(predicate: #Predicate { $0.id == id })).first
    }

    // MARK: - Deletions

    /// Saves CD_Deleted records, deletes the entity records in batches, then drops the confirmed local tombstones.
    private func pushDeletionsNow() async {
        guard let context = modelContext else { return }
        do {
            let tombstones = try context.fetch(FetchDescriptor<DeletedRecord>())
            guard !tombstones.isEmpty else { return }
            print("CloudKit: pushing \(tombstones.count) deletions …")

            try await saveRecordsBatch(tombstones.map { tombstoneRecord(for: $0) })
            try await deleteCloudRecords(tombstones.flatMap { cloudRecordIDs(entityType: $0.entityType, id: $0.id) })

            for ts in tombstones {
                remoteTombstoneIDs.insert(ts.id)
                context.delete(ts)
            }
            try context.save()
        } catch {
            recordError("Push deletions", error)
        }
    }

    /// Current and legacy record names in the custom and the default zone.
    private func cloudRecordIDs(entityType: String, id: UUID) -> [CKRecord.ID] {
        var names = ["\(mappedRecordType(from: entityType))_\(id.uuidString)"]
        let legacyName = "\(entityType)_\(id.uuidString)"
        if legacyName != names[0] { names.append(legacyName) }
        names.append(id.uuidString)
        return names.flatMap { [CKRecord.ID(recordName: $0, zoneID: recordZone.zoneID), CKRecord.ID(recordName: $0, zoneID: CKRecordZone.default().zoneID)] }
    }

    private func mappedRecordType(from entityType: String) -> String {
        switch entityType {
        case "Vehicle": return "CD_Vehicle"
        case "Trailer": return "CD_Trailer"
        case "DriveLog": return "CD_DriveLog"
        case "Checklist": return "CD_Checklist"
        case "ChecklistItem": return "CD_ChecklistItem"
        case "WorkBlock": return "CD_WorkBlock"
        default: return entityType
        }
    }

    private func deleteCloudRecords(_ ids: [CKRecord.ID]) async throws {
        for batch in Self.chunked(ids, size: 400) {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let op = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: batch)
                op.isAtomic = false
                op.modifyRecordsResultBlock = { result in
                    if case .failure(let error) = result, !Self.onlyMissingRecords(error) {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
                privateDatabase.add(op)
            }
        }
    }

    /// A record that is already gone counts as deleted.
    nonisolated private static func onlyMissingRecords(_ error: Error) -> Bool {
        guard let ckError = error as? CKError else { return false }
        if ckError.code == .unknownItem { return true }
        guard ckError.code == .partialFailure, let partial = ckError.partialErrorsByItemID else { return false }
        return partial.values.allSatisfy { ($0 as? CKError)?.code == .unknownItem }
    }

    // MARK: - Zone Management

    private func ensureZoneExists() async throws {
        let targetZoneID = recordZone.zoneID
        // First check if the zone already exists
        let zones = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[CKRecordZone], Error>) in
            privateDatabase.fetchAllRecordZones { zones, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: zones ?? []) }
            }
        }
        if zones.contains(where: { $0.zoneID == targetZoneID }) { return }
        // Create the zone and wait for success
        let op = CKModifyRecordZonesOperation(recordZonesToSave: [recordZone], recordZoneIDsToDelete: nil)
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            op.modifyRecordZonesResultBlock = { result in
                switch result {
                case .success: continuation.resume()
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
            privateDatabase.add(op)
        }
    }

    // MARK: - Record ID Helpers

    private func recordID(for type: String, uuid: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: "\(type)_\(uuid.uuidString)", zoneID: recordZone.zoneID)
    }

    private func referenceID(for type: String, uuid: UUID) -> CKRecord.Reference {
        CKRecord.Reference(recordID: recordID(for: type, uuid: uuid), action: .none)
    }

    private func refUUID(_ record: CKRecord, _ key: String, prefix: String) -> UUID? {
        (record[key] as? CKRecord.Reference).flatMap { extractUUID(from: $0.recordID.recordName, prefix: prefix) }
    }

    /// UUID of a record this app wrote ("<type>_<uuid>"); legacy auto-sync records return nil and are skipped.
    private func appRecordUUID(_ record: CKRecord, type: String) -> UUID? {
        guard let idString = record["CD_id"] as? String,
              let uuid = UUID(uuidString: idString),
              record.recordID.recordName == "\(type)_\(uuid.uuidString)" else { return nil }
        return uuid
    }

    // MARK: - Image Helpers

    /// Stored photo as uploaded: a JPEG that already fits is sent as is, anything else is compressed once.
    private func photoForUpload(_ data: Data?) -> Data? {
        guard let data else { return nil }
        if data.starts(with: [0xFF, 0xD8, 0xFF]) && data.count <= 900_000 { return data }
        return compressedJPEGData(from: data)
    }

    private func compressedJPEGData(from data: Data, maxBytes: Int = 900_000) -> Data? {
        guard let img = UIImage(data: data) else { return nil }

        // Try multiple max-dimension steps and compression qualities
        let dimensionCandidates: [CGFloat] = [2000, 1600, 1200, 1000, 800, 600]
        let qualityCandidates: [CGFloat] = [0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2]

        // Helper to render a resized copy that fits within the target max dimension
        func resizedImage(_ image: UIImage, targetMaxDimension: CGFloat) -> UIImage {
            let size = image.size
            let maxSide = max(size.width, size.height)
            let scale = min(1.0, targetMaxDimension / maxSide)
            // If already within bounds, return as-is
            if scale >= 1.0 { return image }
            let newSize = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1.0 // Avoid multiplying pixels by screen scale
            let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }

        var bestData: Data? = nil

        // First, try original image with decreasing quality
        for q in qualityCandidates {
            if let jpg = img.jpegData(compressionQuality: q) {
                if jpg.count <= maxBytes { return jpg }
                if bestData == nil || jpg.count < (bestData?.count ?? Int.max) {
                    bestData = jpg
                }
            }
        }

        // Then, progressively downscale and try qualities again
        for dim in dimensionCandidates {
            let scaled = resizedImage(img, targetMaxDimension: dim)
            for q in qualityCandidates {
                if let jpg = scaled.jpegData(compressionQuality: q) {
                    if jpg.count <= maxBytes { return jpg }
                    if bestData == nil || jpg.count < (bestData?.count ?? Int.max) {
                        bestData = jpg
                    }
                }
            }
        }

        // As a last resort, return the smallest we produced, even if above the cap
        return bestData
    }

    // MARK: - Tombstone Helper

    private func tombstonedIDs(in context: ModelContext) -> Set<UUID> {
        let local = (try? context.fetch(FetchDescriptor<DeletedRecord>())).map { Set($0.map { $0.id }) } ?? []
        return local.union(remoteTombstoneIDs)
    }

    // MARK: - Fetch (shared loop)

    /// Newer remote wins; both changed since the last sync goes to the conflict list (when `allowConflict`).
    /// New records are created; links are applied only together with the remote fields.
    private func fetchMerge<T: PersistentModel>(recordType: String, entityType: String, label: String, allowConflict: Bool,
                                                context: ModelContext,
                                                find: (UUID) throws -> T?,
                                                create: (UUID) -> T,
                                                lastEdited: (T) -> Date,
                                                apply: (CKRecord, T) throws -> Void) async throws {
        let records = try await fetchRecords(query: CKQuery(recordType: recordType, predicate: NSPredicate(value: true)))
        count(.syncFetchedCount, label, records.count)
        let deletedIDs = tombstonedIDs(in: context)
        var stale: [CKRecord.ID] = []

        for record in records {
            guard let uuid = appRecordUUID(record, type: recordType) else { continue }
            if deletedIDs.contains(uuid) { stale.append(record.recordID); continue }

            guard let local = try find(uuid) else {
                try apply(record, create(uuid))
                continue
            }
            let remoteEdited = record["CD_lastEdited"] as? Date ?? .distantPast
            switch decide(id: uuid, local: lastEdited(local), remote: remoteEdited, allowConflict: allowConflict) {
            case .apply:
                try apply(record, local)
            case .conflict:
                conflictStore.addConflict(SyncConflict(entityType: entityType, entityID: uuid, localLastEdited: lastEdited(local), remoteLastEdited: remoteEdited, remoteRecord: record))
                print("CloudKit: conflict detected for \(entityType) \(uuid)")
            case .keepLocal:
                break
            }
        }
        // remote copies of locally deleted records
        if !stale.isEmpty {
            do { try await deleteCloudRecords(stale) } catch { print("CloudKit: removing deleted \(label) failed - \(error)") }
        }
        count(.syncImportedCount, label, records.count)
    }

    private func fetchVehicles(context: ModelContext) async throws {
        try await fetchMerge(recordType: "CD_Vehicle", entityType: "Vehicle", label: "Vehicles", allowConflict: true, context: context,
                             find: { try vehicle($0, context) },
                             create: { id in let v = Vehicle(); v.id = id; context.insert(v); return v },
                             lastEdited: { $0.lastEdited },
                             apply: { try applyRemoteVehicle(record: $0, to: $1, context: context) })
    }

    // Trailer conflicts stay excluded (newer wins), as before
    private func fetchTrailers(context: ModelContext) async throws {
        try await fetchMerge(recordType: "CD_Trailer", entityType: "Trailer", label: "Trailers", allowConflict: false, context: context,
                             find: { try trailer($0, context) },
                             create: { id in let t = Trailer(); t.id = id; context.insert(t); return t },
                             lastEdited: { $0.lastEdited },
                             apply: { applyRemoteTrailer(record: $0, to: $1) })
    }

    private func fetchDriveLogs(context: ModelContext) async throws {
        try await fetchMerge(recordType: "CD_DriveLog", entityType: "DriveLog", label: "DriveLogs", allowConflict: true, context: context,
                             find: { try driveLog($0, context) },
                             create: { id in let l = DriveLog(); l.id = id; context.insert(l); return l },
                             lastEdited: { $0.lastEdited },
                             apply: { try applyRemoteDriveLog(record: $0, to: $1, context: context) })
    }

    private func fetchChecklists(context: ModelContext) async throws {
        try await fetchMerge(recordType: "CD_Checklist", entityType: "Checklist", label: "Checklists", allowConflict: true, context: context,
                             find: { try checklist($0, context) },
                             create: { id in let c = Checklist(); c.id = id; context.insert(c); return c },
                             lastEdited: { $0.lastEdited },
                             apply: { try applyRemoteChecklist(record: $0, to: $1, context: context) })
    }

    /// Newer wins, no conflict list. A record type the iCloud schema does not have yet counts as empty.
    private func fetchWorkBlocks(context: ModelContext) async throws {
        do {
            try await fetchMerge(recordType: "CD_WorkBlock", entityType: "WorkBlock", label: "WorkTime", allowConflict: false, context: context,
                                 find: { try workBlock($0, context) },
                                 create: { id in let b = WorkBlock(); b.id = id; context.insert(b); return b },
                                 lastEdited: { $0.lastEdited },
                                 apply: { applyRemoteWorkBlock(record: $0, to: $1) })
        } catch let error as CKError where error.code == .unknownItem {
            print("CloudKit: no work time records yet")
        }
    }

    /// Items have no lastEdited: an existing item takes the iCloud fields only when its checklist came newer from iCloud.
    private func fetchChecklistItems(context: ModelContext) async throws {
        let records = try await fetchRecords(query: CKQuery(recordType: "CD_ChecklistItem", predicate: NSPredicate(value: true)))
        count(.syncFetchedCount, "ChecklistItems", records.count)
        let deletedIDs = tombstonedIDs(in: context)
        var stale: [CKRecord.ID] = []

        for record in records {
            guard let uuid = appRecordUUID(record, type: "CD_ChecklistItem") else { continue }
            if deletedIDs.contains(uuid) { stale.append(record.recordID); continue }

            if let item = try checklistItem(uuid, context) {
                guard let parentID = refUUID(record, "CD_checklist", prefix: "CD_Checklist_"),
                      remoteAppliedChecklistIDs.contains(parentID) else { continue }
                try applyRemoteChecklistItem(record: record, to: item, context: context)
            } else {
                let item = ChecklistItem(section: "", title: "")
                item.id = uuid
                context.insert(item)
                try applyRemoteChecklistItem(record: record, to: item, context: context)
            }
        }
        if !stale.isEmpty {
            do { try await deleteCloudRecords(stale) } catch { print("CloudKit: removing deleted checklist items failed - \(error)") }
        }
        count(.syncImportedCount, "ChecklistItems", records.count)
    }

    // MARK: - Push

    /// Records not to push: deleted ones and ones waiting for the user's conflict decision.
    private func skippedIDs(in context: ModelContext) -> Set<UUID> {
        tombstonedIDs(in: context).union(pendingConflictIDs)
    }

    private func pushVehicles(context: ModelContext) async throws {
        let skip = skippedIDs(in: context)
        let vehicles = try context.fetch(FetchDescriptor<Vehicle>()).filter { !skip.contains($0.id) }
        let records: [CKRecord] = vehicles.map { vehicle in
            let record = CKRecord(recordType: "CD_Vehicle", recordID: recordID(for: "CD_Vehicle", uuid: vehicle.id))
            record["CD_id"] = vehicle.id.uuidString
            record["CD_type"] = vehicle.type.rawValue
            record["CD_brandModel"] = vehicle.brandModel
            record["CD_color"] = vehicle.color
            record["CD_plate"] = vehicle.plate
            record["CD_notes"] = vehicle.notes
            record["CD_lastEdited"] = vehicle.lastEdited
            // optional keys are always written, so nil removes the old value on the server
            record["CD_photoData"] = photoForUpload(vehicle.photoData)
            record["CD_trailer"] = vehicle.trailer.map { referenceID(for: "CD_Trailer", uuid: $0.id) }
            return record
        }
        // photos make records large; small batches stay under the request size limit
        try await saveRecordsBatch(records, chunkSize: 50)
        count(.syncPushedCount, "Vehicles", records.count)
    }

    private func pushTrailers(context: ModelContext) async throws {
        let skip = skippedIDs(in: context)
        let trailers = try context.fetch(FetchDescriptor<Trailer>()).filter { !skip.contains($0.id) }
        let records: [CKRecord] = trailers.map { trailer in
            let record = CKRecord(recordType: "CD_Trailer", recordID: recordID(for: "CD_Trailer", uuid: trailer.id))
            record["CD_id"] = trailer.id.uuidString
            record["CD_brandModel"] = trailer.brandModel
            record["CD_color"] = trailer.color
            record["CD_plate"] = trailer.plate
            record["CD_notes"] = trailer.notes
            record["CD_lastEdited"] = trailer.lastEdited
            record["CD_photoData"] = photoForUpload(trailer.photoData)
            return record
        }
        try await saveRecordsBatch(records, chunkSize: 50)
        count(.syncPushedCount, "Trailers", records.count)
    }

    private func pushDriveLogs(context: ModelContext) async throws {
        let skip = skippedIDs(in: context)
        let logs = try context.fetch(FetchDescriptor<DriveLog>()).filter { !skip.contains($0.id) }
        let records: [CKRecord] = logs.map { log in
            let record = CKRecord(recordType: "CD_DriveLog", recordID: recordID(for: "CD_DriveLog", uuid: log.id))
            record["CD_id"] = log.id.uuidString
            record["CD_date"] = log.date
            record["CD_reason"] = log.reason
            record["CD_kmStart"] = log.kmStart
            record["CD_kmEnd"] = log.kmEnd
            record["CD_notes"] = log.notes
            record["CD_lastEdited"] = log.lastEdited
            record["CD_vehicle"] = log.vehicle.map { referenceID(for: "CD_Vehicle", uuid: $0.id) }
            record["CD_checklist"] = log.checklist.map { referenceID(for: "CD_Checklist", uuid: $0.id) }
            return record
        }
        try await saveRecordsBatch(records)
        count(.syncPushedCount, "DriveLogs", records.count)
    }

    private func pushWorkBlocks(context: ModelContext) async throws {
        let skip = skippedIDs(in: context)
        let blocks = try context.fetch(FetchDescriptor<WorkBlock>()).filter { !skip.contains($0.id) }
        let records: [CKRecord] = blocks.map { b in
            let record = CKRecord(recordType: "CD_WorkBlock", recordID: recordID(for: "CD_WorkBlock", uuid: b.id))
            record["CD_id"] = b.id.uuidString
            record["CD_activity"] = b.activity.rawValue
            record["CD_start"] = b.start
            record["CD_end"] = b.end
            record["CD_vehiclePlate"] = b.vehiclePlate
            record["CD_vehicleName"] = b.vehicleName
            record["CD_kmStart"] = b.kmStart
            record["CD_kmEnd"] = b.kmEnd
            record["CD_placeStart"] = b.placeStart
            record["CD_placeEnd"] = b.placeEnd
            record["CD_exception"] = b.exception ? 1 : 0
            record["CD_note"] = b.note
            record["CD_lastEdited"] = b.lastEdited
            return record
        }
        try await saveRecordsBatch(records)
        count(.syncPushedCount, "WorkTime", records.count)
    }

    private func pushChecklists(context: ModelContext) async throws {
        let skip = skippedIDs(in: context)
        let checklists = try context.fetch(FetchDescriptor<Checklist>()).filter { !skip.contains($0.id) }
        let records: [CKRecord] = checklists.map { checklist in
            let record = CKRecord(recordType: "CD_Checklist", recordID: recordID(for: "CD_Checklist", uuid: checklist.id))
            record["CD_id"] = checklist.id.uuidString
            record["CD_vehicleType"] = checklist.vehicleType.rawValue
            record["CD_title"] = checklist.title
            record["CD_lastEdited"] = checklist.lastEdited
            record["CD_vehicle"] = checklist.vehicle.map { referenceID(for: "CD_Vehicle", uuid: $0.id) }
            record["CD_trailer"] = checklist.trailer.map { referenceID(for: "CD_Trailer", uuid: $0.id) }
            return record
        }
        try await saveRecordsBatch(records)
        count(.syncPushedCount, "Checklists", records.count)
    }

    private func pushChecklistItems(context: ModelContext) async throws {
        let skip = skippedIDs(in: context)
        let items = try context.fetch(FetchDescriptor<ChecklistItem>()).filter {
            !skip.contains($0.id) && !($0.checklist.map { skip.contains($0.id) } ?? false)
        }
        let records: [CKRecord] = items.map { item in
            let record = CKRecord(recordType: "CD_ChecklistItem", recordID: recordID(for: "CD_ChecklistItem", uuid: item.id))
            record["CD_id"] = item.id.uuidString
            record["CD_section"] = item.section
            record["CD_title"] = item.title
            record["CD_state"] = item.state.rawValue
            record["CD_note"] = item.note
            record["CD_checklist"] = item.checklist.map { referenceID(for: "CD_Checklist", uuid: $0.id) }
            return record
        }
        try await saveRecordsBatch(records)
        count(.syncPushedCount, "ChecklistItems", records.count)
    }

    // MARK: - CloudKit Helpers

    /// Splits into batches of at most `size` (CloudKit takes at most 400 records per operation).
    nonisolated static func chunked<T>(_ items: [T], size: Int) -> [[T]] {
        stride(from: 0, to: items.count, by: size).map { Array(items[$0..<min($0 + size, items.count)]) }
    }

    private func saveRecordsBatch(_ records: [CKRecord], savePolicy: CKModifyRecordsOperation.RecordSavePolicy = .allKeys, chunkSize: Int = 400) async throws {
        for batch in Self.chunked(records, size: chunkSize) {
            try await saveOneBatch(batch, savePolicy: savePolicy)
        }
    }

    private func saveOneBatch(_ records: [CKRecord], savePolicy: CKModifyRecordsOperation.RecordSavePolicy) async throws {
        guard !records.isEmpty else { return }

        let op = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        op.savePolicy = savePolicy
        op.isAtomic = false  // Allow partial success - some records may fail but others succeed

        op.perRecordSaveBlock = { recordID, result in
            if case .failure(let error) = result {
                let message: String
                if let ckError = error as? CKError {
                    message = "Save error for \(recordID.recordName): \(ckError.code) - \(ckError.localizedDescription)"
                } else {
                    message = "Save error for \(recordID.recordName): \(error.localizedDescription)"
                }
                print("CloudKit per-record \(message)")
                NotificationCenter.default.post(name: .syncError, object: nil, userInfo: ["message": message])
            }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            op.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    let message: String
                    if let ckError = error as? CKError {
                        message = "Batch save error: \(ckError.code) - \(ckError.localizedDescription)"
                    } else {
                        message = "Batch save error: \(error.localizedDescription)"
                    }
                    print("CloudKit saveRecordsBatch \(message)")
                    NotificationCenter.default.post(name: .syncError, object: nil, userInfo: ["message": message])

                    if let ckError = error as? CKError, ckError.code == .zoneNotFound {
                        Task {
                            do {
                                try await self.ensureZoneExists()
                                // Retry once after ensuring the zone exists
                                try await self.saveOneBatch(records, savePolicy: savePolicy)
                                continuation.resume()
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        }
                    } else {
                        continuation.resume(throwing: error)
                    }
                }
            }
            privateDatabase.add(op)
        }
    }

    /// Fetches all pages of a query (a single CKQueryOperation returns only the first ~100 records).
    private func fetchRecords(query: CKQuery) async throws -> [CKRecord] {
        var collected: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor? = nil
        repeat {
            let operation: CKQueryOperation
            if let cursor {
                operation = CKQueryOperation(cursor: cursor)
            } else {
                operation = CKQueryOperation(query: query)
                operation.zoneID = recordZone.zoneID
            }
            let (page, next) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<([CKRecord], CKQueryOperation.Cursor?), Error>) in
                var page: [CKRecord] = []
                operation.recordMatchedBlock = { _, result in
                    if case .success(let record) = result { page.append(record) }
                }
                operation.queryResultBlock = { result in
                    continuation.resume(with: result.map { (page, $0) })
                }
                privateDatabase.add(operation)
            }
            collected += page
            cursor = next
        } while cursor != nil
        return collected
    }

    private func extractUUID(from recordName: String, prefix: String) -> UUID? {
        guard recordName.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(recordName.dropFirst(prefix.count)))
    }
}

private extension Notification.Name {
    static let syncFetchedCount = Notification.Name("SyncFetchedCountNotification")
    static let syncPushedCount = Notification.Name("SyncPushedCountNotification")
    static let syncImportedCount = Notification.Name("SyncImportedCountNotification")
    static let syncError = Notification.Name("SyncErrorNotification")
}
