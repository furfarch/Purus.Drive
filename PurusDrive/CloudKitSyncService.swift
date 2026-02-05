import Foundation
import CloudKit
import SwiftData
import UIKit

/// Manual CloudKit sync service for Purus Drive.
/// Uses local SwiftData storage and manually syncs to CloudKit.
@MainActor
final class CloudKitSyncService {
    static let shared = CloudKitSyncService()

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
    private var lastErrorMessage: String? = nil
    private var shouldReconcileDeletes: Bool { lastErrorMessage == nil }

    // MARK: - Tombstone Helpers
    private func localDelete(entityType: String, id: UUID, context: ModelContext) throws {
        switch entityType {
        case "Vehicle":
            if let v = try context.fetch(FetchDescriptor<Vehicle>(predicate: #Predicate { $0.id == id })).first {
                // delete associated logs
                if let logs = v.driveLogs { for l in logs { context.delete(l) } }
                // delete associated checklists
                if let cls = v.checklists { for c in cls { context.delete(c) } }
                // unlink trailer
                v.trailer?.linkedVehicle = nil
                context.delete(v)
            }
        case "Trailer":
            if let t = try context.fetch(FetchDescriptor<Trailer>(predicate: #Predicate { $0.id == id })).first {
                // delete associated checklists
                if let cls = t.checklists { for c in cls { context.delete(c) } }
                // unlink vehicle
                t.linkedVehicle?.trailer = nil
                context.delete(t)
            }
        case "DriveLog":
            if let l = try context.fetch(FetchDescriptor<DriveLog>(predicate: #Predicate { $0.id == id })).first {
                context.delete(l)
            }
        case "Checklist":
            if let c = try context.fetch(FetchDescriptor<Checklist>(predicate: #Predicate { $0.id == id })).first {
                // clear references from logs
                let logs = try context.fetch(FetchDescriptor<DriveLog>())
                for log in logs where log.checklist === c { log.checklist = nil }
                context.delete(c)
            }
        case "ChecklistItem":
            if let i = try context.fetch(FetchDescriptor<ChecklistItem>(predicate: #Predicate { $0.id == id })).first {
                context.delete(i)
            }
        default: break
        }
    }

    private func tombstoneRecord(for ts: DeletedRecord) -> CKRecord {
        let recID = CKRecord.ID(recordName: "CD_Deleted_\(ts.entityType)_\(ts.id.uuidString)", zoneID: recordZone.zoneID)
        let rec = CKRecord(recordType: "CD_Deleted", recordID: recID)
        rec["entityType"] = ts.entityType
        rec["entityID"] = ts.id.uuidString
        rec["deletedAt"] = ts.deletedAt
        return rec
    }

    /// Fetch remote tombstones and apply local deletions, then remove the tombstones from CloudKit.
    func fetchRemoteTombstones() async {
        guard let context = modelContext else { return }
        do {
            let query = CKQuery(recordType: "CD_Deleted", predicate: NSPredicate(value: true))
            let records = try await fetchRecords(query: query)
            if records.isEmpty { return }
            // var toDeleteFromCloud: [CKRecord.ID] = [] // Removed to retain tombstones in CloudKit
            for rec in records {
                guard let type = rec["entityType"] as? String,
                      let idStr = rec["entityID"] as? String,
                      let uuid = UUID(uuidString: idStr) else { continue }
                do { try localDelete(entityType: type, id: uuid, context: context) } catch { print("CloudKit: local delete error for \(type) id=\(idStr): \(error)") }
                // toDeleteFromCloud.append(rec.recordID) // Removed
            }
            try context.save()
            // if !toDeleteFromCloud.isEmpty {
            //     let op = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: toDeleteFromCloud)
            //     try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            //         op.modifyRecordsResultBlock = { result in
            //             switch result { case .success: continuation.resume(); case .failure(let error): continuation.resume(throwing: error) }
            //         }
            //         privateDatabase.add(op)
            //     }
            // }
            // Retain tombstones in CloudKit so all devices can consume them
        } catch {
            print("CloudKit: fetchRemoteTombstones error - \(error)")
        }
    }

    private init() {}

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Public Sync Methods

    /// Performs a full sync: fetches from cloud then pushes local changes.
    func performFullSync() async {
        guard let context = modelContext else {
            print("CloudKitSyncService: No model context set")
            return
        }

        let mode = "iCloud"
        var report = SyncReport(startedAt: Date(), finishedAt: nil, mode: mode)

        print("CloudKit: full sync starting")
        lastErrorMessage = nil

        // Ensure zone exists
        do {
            try await ensureZoneExists()
        } catch {
            print("CloudKitSyncService: Failed to ensure zone exists - \(error)")
            lastErrorMessage = String(describing: error)
            report.error = lastErrorMessage
            await MainActor.run { reportStore.lastReport = report }
            return
        }

        // 1) CRITICAL: Push pending local deletions FIRST so other devices learn about them
        //    This must happen before fetching to prevent deleted items from reappearing
        await pushDeletions()

        // 2) Apply remote deletions so local store is purged
        await fetchRemoteTombstones()

        // 3) Fetch from cloud (each type independently)
        //    Deleted items are now filtered out via tombstonedIDs
        do { try await fetchTrailers(context: context) } catch { print("CloudKit: fetch trailers error - \(error)") }
        do { try await fetchVehicles(context: context) } catch { print("CloudKit: fetch vehicles error - \(error)") }
        do { try await fetchChecklists(context: context) } catch { print("CloudKit: fetch checklists error - \(error)") }
        do { try await fetchChecklistItems(context: context) } catch { print("CloudKit: fetch checklist items error - \(error)") }
        do { try await fetchDriveLogs(context: context) } catch { print("CloudKit: fetch drive logs error - \(error)") }

        // 4) Save local changes after fetch
        do {
            try context.save()
        } catch {
            print("CloudKit: failed to save after fetch - \(error)")
        }

        // 5) Finally, push any remaining local upserts
        await pushAllToCloud()

        // 6) Final deletion push in case any tombstones were created during the sync
        await pushDeletions()

        report.finishedAt = Date()
        await MainActor.run { reportStore.lastReport = report }

        print("CloudKit: full sync completed")
        print("CloudKitSyncService: Full sync completed")
    }

    /// Fetches all records from CloudKit and imports them locally.
    func fetchAllFromCloud() async {
        guard let context = modelContext else { return }

        // Fetch each entity type independently - one failure shouldn't stop others
        do { try await fetchTrailers(context: context) } catch { print("CloudKitSyncService: Fetch trailers error - \(error)") }
        do { try await fetchVehicles(context: context) } catch { print("CloudKitSyncService: Fetch vehicles error - \(error)") }
        do { try await fetchChecklists(context: context) } catch { print("CloudKitSyncService: Fetch checklists error - \(error)") }
        do { try await fetchChecklistItems(context: context) } catch { print("CloudKitSyncService: Fetch checklist items error - \(error)") }
        do { try await fetchDriveLogs(context: context) } catch { print("CloudKitSyncService: Fetch drive logs error - \(error)") }

        do {
            try context.save()
            print("CloudKitSyncService: Fetch from cloud completed")
        } catch {
            print("CloudKitSyncService: Failed to save after fetch - \(error)")
            lastErrorMessage = String(describing: error)
        }
    }

    /// Pushes all local records to CloudKit.
    func pushAllToCloud() async {
        guard let context = modelContext else { return }

        do { try await ensureZoneExists() } catch { print("CloudKit: ensureZoneExists failed before pushAllToCloud - \(error)") }

        // Always push local deletions first so CloudKit learns about them
        await pushDeletions()

        // Then pull remote tombstones to avoid resurrecting records on this device
        await fetchRemoteTombstones()

        // Now push each entity type independently — one failure shouldn't stop others
        do { try await pushTrailers(context: context) } catch { print("CloudKitSyncService: Push trailers error - \(error)") }
        do { try await pushVehicles(context: context) } catch { print("CloudKitSyncService: Push vehicles error - \(error)") }
        do { try await pushChecklists(context: context) } catch { print("CloudKitSyncService: Push checklists error - \(error)") }
        do { try await pushChecklistItems(context: context) } catch { print("CloudKitSyncService: Push checklist items error - \(error)") }
        do { try await pushDriveLogs(context: context) } catch { print("CloudKitSyncService: Push drive logs error - \(error)") }

        // Final pass to push any tombstones created during this run
        await pushDeletions()

        print("CloudKitSyncService: Push to cloud completed (safe order with tombstone fetch)")
    }

    /// Records a local deletion so it can be pushed to CloudKit.
    /// If immediate sync is enabled and in iCloud mode, triggers an automatic sync.
    func markDeleted(entityType: String, id: UUID, cascade: Bool = true, autoSync: Bool = true) {
        guard let context = modelContext else { return }
        // Upsert: avoid duplicate unique id constraint
        if let fetched = try? context.fetch(FetchDescriptor<DeletedRecord>(predicate: #Predicate { $0.id == id })),
           let existing = fetched.first {
            existing.entityType = entityType
            existing.deletedAt = .now
        } else {
            let tombstone = DeletedRecord(entityType: entityType, id: id, deletedAt: .now)
            context.insert(tombstone)
        }

        if cascade {
            // Cascade tombstones for related entities so CloudKit deletes them as well
            switch entityType {
            case "Vehicle":
                if let v = try? context.fetch(FetchDescriptor<Vehicle>(predicate: #Predicate { $0.id == id })).first {
                    if let logs = v.driveLogs {
                        for l in logs {
                            let lid = l.id
                            if (try? context.fetch(FetchDescriptor<DeletedRecord>(predicate: #Predicate { $0.id == lid })).first) == nil {
                                let ts = DeletedRecord(entityType: "DriveLog", id: lid, deletedAt: .now)
                                context.insert(ts)
                            }
                        }
                    }
                    if let cls = v.checklists {
                        for c in cls {
                            let cid = c.id
                            if (try? context.fetch(FetchDescriptor<DeletedRecord>(predicate: #Predicate { $0.id == cid })).first) == nil {
                                let ts = DeletedRecord(entityType: "Checklist", id: cid, deletedAt: .now)
                                context.insert(ts)
                            }
                            // Also tombstone checklist items
                            for i in (c.items ?? []) {
                                let iid = i.id
                                if (try? context.fetch(FetchDescriptor<DeletedRecord>(predicate: #Predicate { $0.id == iid })).first) == nil {
                                    let its = DeletedRecord(entityType: "ChecklistItem", id: iid, deletedAt: .now)
                                    context.insert(its)
                                }
                            }
                        }
                    }
                }
            case "Trailer":
                if let t = try? context.fetch(FetchDescriptor<Trailer>(predicate: #Predicate { $0.id == id })).first {
                    if let cls = t.checklists {
                        for c in cls {
                            let cid = c.id
                            if (try? context.fetch(FetchDescriptor<DeletedRecord>(predicate: #Predicate { $0.id == cid })).first) == nil {
                                let ts = DeletedRecord(entityType: "Checklist", id: cid, deletedAt: .now)
                                context.insert(ts)
                            }
                            for i in (c.items ?? []) {
                                let iid = i.id
                                if (try? context.fetch(FetchDescriptor<DeletedRecord>(predicate: #Predicate { $0.id == iid })).first) == nil {
                                    let its = DeletedRecord(entityType: "ChecklistItem", id: iid, deletedAt: .now)
                                    context.insert(its)
                                }
                            }
                        }
                    }
                }
            default:
                break
            }
        }

        do { try context.save() } catch { print("CloudKit: failed saving tombstone(s): \(error)") }

        // Trigger automatic deletion sync if enabled and in iCloud mode
        if autoSync {
            let storageRaw = UserDefaults.standard.string(forKey: "storageLocation") ?? "local"
            if storageRaw == "icloud" {
                Task { @MainActor in
                    print("CloudKit: auto-syncing deletion of \(entityType) \(id)")
                    await self.pushDeletions()
                    // Also trigger a notification so UI can update
                    NotificationCenter.default.post(name: Notification.Name("DeletionSyncedNotification"), object: nil, userInfo: ["entityType": entityType, "id": id])
                }
            }
        }
    }

    /// Pushes pending deletions to CloudKit and removes tombstones on success.
    func pushDeletions() async {
        guard let context = modelContext else { return }

        // Ensure the custom zone exists so tombstones can be saved reliably
        do { try await ensureZoneExists() } catch { print("CloudKit: ensureZoneExists failed before pushDeletions - \(error)") }

        do {
            let tombstones = try context.fetch(FetchDescriptor<DeletedRecord>())
            guard !tombstones.isEmpty else { return }

            print("CloudKit: pushing \(tombstones.count) deletions …")

            // First, save tombstone records to CloudKit (so other devices know about deletions)
            let tombstoneRecords: [CKRecord] = tombstones.map { tombstoneRecord(for: $0) }

            var savedTombstonesToCloud = false

            let saveOp = CKModifyRecordsOperation(recordsToSave: tombstoneRecords, recordIDsToDelete: nil)
            saveOp.savePolicy = .allKeys
            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    saveOp.modifyRecordsResultBlock = { result in
                        switch result {
                        case .success:
                            continuation.resume()
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                    privateDatabase.add(saveOp)
                }
                print("CloudKit: saved \(tombstoneRecords.count) tombstone records")
                savedTombstonesToCloud = true
            } catch {
                print("CloudKit: failed to save tombstone records - \(error)")
                // Do not proceed with deleting cloud records or removing local tombstones; try again later
                return
            }

            // Track which tombstones were successfully reflected in CloudKit deletions
            var successfullyDeletedIDs: Set<UUID> = []

            for ts in tombstones {
                let type = mappedRecordType(from: ts.entityType)
                let tsId = ts.id
                let tsEntityType = ts.entityType
                let recordIDToDelete = CKRecord.ID(recordName: "\(type)_\(tsId.uuidString)", zoneID: recordZone.zoneID)

                do {
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        privateDatabase.delete(withRecordID: recordIDToDelete) { _, error in
                            if let ckError = error as? CKError {
                                if ckError.code == .unknownItem {
                                    print("CloudKit: record \(tsEntityType) \(tsId) not found in cloud (already deleted or never synced)")
                                    successfullyDeletedIDs.insert(tsId)
                                    continuation.resume()
                                    return
                                }
                            }
                            if let error = error {
                                continuation.resume(throwing: error)
                            } else {
                                successfullyDeletedIDs.insert(tsId)
                                continuation.resume()
                            }
                        }
                    }
                } catch {
                    print("CloudKit: failed to delete \(tsEntityType) \(tsId) from cloud - \(error)")
                }
            }

            // Only remove local tombstones that we know CloudKit has acknowledged (deleted or already gone)
            if savedTombstonesToCloud {
                for ts in tombstones where successfullyDeletedIDs.contains(ts.id) {
                    context.delete(ts)
                }
            }

            try context.save()
            print("CloudKit: processed \(tombstones.count) deletions")
        } catch {
            print("CloudKit: pushDeletions error - \(error)")
        }
    }

    private func mappedRecordType(from entityType: String) -> String {
        switch entityType {
        case "Vehicle": return "CD_Vehicle"
        case "Trailer": return "CD_Trailer"
        case "DriveLog": return "CD_DriveLog"
        case "Checklist": return "CD_Checklist"
        case "ChecklistItem": return "CD_ChecklistItem"
        default: return entityType
        }
    }

    /// Deletes all records in the app's private database zone.
    func deleteAllFromCloud() async {
        do {
            // Delete in each record type
            try await deleteAll(ofType: "CD_ChecklistItem")
            try await deleteAll(ofType: "CD_Checklist")
            try await deleteAll(ofType: "CD_DriveLog")
            try await deleteAll(ofType: "CD_Trailer")
            try await deleteAll(ofType: "CD_Vehicle")
            print("CloudKitSyncService: Deleted all records from cloud")
        } catch {
            print("CloudKitSyncService: deleteAllFromCloud error - \(error)")
        }
    }

    /// Pulls all data from CloudKit and imports into local store.
    func pullAllFromCloud() async {
        await fetchAllFromCloud()
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
    
    // MARK: - Asset Helpers
    private func makeAsset(from data: Data, named name: String) throws -> (CKAsset, URL) {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("PD_Asset_\(name)_\(UUID().uuidString).dat")
        try data.write(to: tmp, options: .atomic)
        return (CKAsset(fileURL: tmp), tmp)
    }

    private func data(from asset: CKAsset) -> Data? {
        guard let url = asset.fileURL else { return nil }
        return try? Data(contentsOf: url)
    }

    // MARK: - Image Compression Helper
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
        (try? context.fetch(FetchDescriptor<DeletedRecord>()))
            .map { Set($0.map { $0.id }) } ?? []
    }

    // MARK: - Vehicle Sync

    private func pushVehicles(context: ModelContext) async throws {
        let vehicles = try context.fetch(FetchDescriptor<Vehicle>())
        let deleted = tombstonedIDs(in: context)
        let activeVehicles = vehicles.filter { !deleted.contains($0.id) }
        print("CloudKit: pushing \(activeVehicles.count) vehicles …")

        var records: [CKRecord] = []
        for vehicle in activeVehicles {
            let recordID = recordID(for: "CD_Vehicle", uuid: vehicle.id)
            let record = CKRecord(recordType: "CD_Vehicle", recordID: recordID)

            record["CD_id"] = vehicle.id.uuidString
            record["CD_type"] = vehicle.type.rawValue
            record["CD_brandModel"] = vehicle.brandModel
            record["CD_color"] = vehicle.color
            record["CD_plate"] = vehicle.plate
            record["CD_notes"] = vehicle.notes
            record["CD_lastEdited"] = vehicle.lastEdited

            if let photoData = vehicle.photoData, let jpeg = compressedJPEGData(from: photoData) {
                record["CD_photoData"] = jpeg
            }

            // Do NOT set CD_trailer in first pass (two-phase linking)
            records.append(record)
        }

        // Chunked save for base vehicle records
        let chunkSize = 100
        for chunk in stride(from: 0, to: records.count, by: chunkSize) {
            let end = min(chunk + chunkSize, records.count)
            let batch = Array(records[chunk..<end])
            try await saveRecordsBatch(batch)
        }

        // Phase 2: apply trailer links only
        var linkRecords: [CKRecord] = []
        for vehicle in activeVehicles {
            if let trailer = vehicle.trailer {
                let recordID = recordID(for: "CD_Vehicle", uuid: vehicle.id)
                let record = CKRecord(recordType: "CD_Vehicle", recordID: recordID)
                record["CD_trailer"] = referenceID(for: "CD_Trailer", uuid: trailer.id)
                linkRecords.append(record)
            }
        }
        if !linkRecords.isEmpty {
            for chunk in stride(from: 0, to: linkRecords.count, by: chunkSize) {
                let end = min(chunk + chunkSize, linkRecords.count)
                let batch = Array(linkRecords[chunk..<end])
                try await saveRecordsBatch(batch, savePolicy: .changedKeys)
            }
        }

        NotificationCenter.default.post(name: .syncPushedCount, object: nil, userInfo: ["type": "Vehicles", "count": activeVehicles.count])
        print("CloudKit: successfully pushed \(activeVehicles.count) vehicles (two-phase link, inline photos)")
    }

    private func fetchVehicles(context: ModelContext) async throws {
        let query = CKQuery(recordType: "CD_Vehicle", predicate: NSPredicate(value: true))
        let records = try await fetchRecords(query: query)
        let deletedIDs = tombstonedIDs(in: context)
        NotificationCenter.default.post(name: .syncFetchedCount, object: nil, userInfo: ["type": "Vehicles", "count": records.count])
        print("CloudKit: fetched \(records.count) Vehicles")

        for record in records {
            guard let idString = record["CD_id"] as? String,
                  let uuid = UUID(uuidString: idString) else { continue }
            
            if deletedIDs.contains(uuid) { continue }

            // Check if vehicle exists locally
            let descriptor = FetchDescriptor<Vehicle>(predicate: #Predicate { $0.id == uuid })
            let existing = try context.fetch(descriptor).first

            let vehicle = existing ?? Vehicle()
            if existing == nil {
                vehicle.id = uuid
                context.insert(vehicle)
            }

            let cloudLastEdited = (record["CD_lastEdited"] as? Date) ?? .distantPast
            if existing != nil && vehicle.lastEdited >= cloudLastEdited {
                // Skip overwrite; still allow establishing relationships below
            } else {
                if let typeString = record["CD_type"] as? String,
                   let type = VehicleType(rawValue: typeString) {
                    vehicle.type = type
                }
                vehicle.brandModel = record["CD_brandModel"] as? String ?? ""
                vehicle.color = record["CD_color"] as? String ?? ""
                vehicle.plate = record["CD_plate"] as? String ?? ""
                vehicle.notes = record["CD_notes"] as? String ?? ""
                if let asset = record["CD_photoAsset"] as? CKAsset, let bytes = data(from: asset) {
                    vehicle.photoData = bytes
                } else if let bytes = record["CD_photoData"] as? Data {
                    vehicle.photoData = bytes
                } else {
                    vehicle.photoData = nil
                }
                if let lastEdited = record["CD_lastEdited"] as? Date {
                    vehicle.lastEdited = lastEdited
                }
            }

            // Link to trailer if reference exists (trailers were fetched first)
            if let trailerRef = record["CD_trailer"] as? CKRecord.Reference {
                let trailerUUID = extractUUID(from: trailerRef.recordID.recordName, prefix: "CD_Trailer_")
                if let tUUID = trailerUUID {
                    let tDesc = FetchDescriptor<Trailer>(predicate: #Predicate { $0.id == tUUID })
                    vehicle.trailer = try context.fetch(tDesc).first
                    vehicle.trailer?.linkedVehicle = vehicle
                }
            }
        }
        // Deletions are handled via cloud tombstones in fetchRemoteTombstones()
        NotificationCenter.default.post(name: .syncImportedCount, object: nil, userInfo: ["type": "Vehicles", "count": records.count])
    }

    // MARK: - Trailer Sync

    private func pushTrailers(context: ModelContext) async throws {
        let trailers = try context.fetch(FetchDescriptor<Trailer>())
        let deleted = tombstonedIDs(in: context)
        let activeTrailers = trailers.filter { !deleted.contains($0.id) }
        print("CloudKit: pushing \(activeTrailers.count) trailers …")

        var records: [CKRecord] = []
        for trailer in activeTrailers {
            let recordID = recordID(for: "CD_Trailer", uuid: trailer.id)
            let record = CKRecord(recordType: "CD_Trailer", recordID: recordID)

            record["CD_id"] = trailer.id.uuidString
            record["CD_brandModel"] = trailer.brandModel
            record["CD_color"] = trailer.color
            record["CD_plate"] = trailer.plate
            record["CD_notes"] = trailer.notes
            record["CD_lastEdited"] = trailer.lastEdited

            if let photoData = trailer.photoData, let jpeg = compressedJPEGData(from: photoData) {
                record["CD_photoData"] = jpeg
            }

            records.append(record)
        }

        // Chunked save for trailers
        let chunkSize = 100
        for chunk in stride(from: 0, to: records.count, by: chunkSize) {
            let end = min(chunk + chunkSize, records.count)
            let batch = Array(records[chunk..<end])
            try await saveRecordsBatch(batch)
        }

        NotificationCenter.default.post(name: .syncPushedCount, object: nil, userInfo: ["type": "Trailers", "count": activeTrailers.count])
        print("CloudKit: successfully pushed \(activeTrailers.count) trailers (inline photos)")
    }

    private func fetchTrailers(context: ModelContext) async throws {
        let query = CKQuery(recordType: "CD_Trailer", predicate: NSPredicate(value: true))
        let records = try await fetchRecords(query: query)
        let deletedIDs = tombstonedIDs(in: context)
        NotificationCenter.default.post(name: .syncFetchedCount, object: nil, userInfo: ["type": "Trailers", "count": records.count])
        print("CloudKit: fetched \(records.count) Trailers")

        for record in records {
            guard let idString = record["CD_id"] as? String,
                  let uuid = UUID(uuidString: idString) else { continue }
            
            if deletedIDs.contains(uuid) { continue }

            let descriptor = FetchDescriptor<Trailer>(predicate: #Predicate { $0.id == uuid })
            let existing = try context.fetch(descriptor).first

            let trailer = existing ?? Trailer()
            if existing == nil {
                trailer.id = uuid
                context.insert(trailer)
            }

            let cloudLastEdited = (record["CD_lastEdited"] as? Date) ?? .distantPast
            if existing != nil && trailer.lastEdited >= cloudLastEdited {
                // Skip overwrite
            } else {
                trailer.brandModel = record["CD_brandModel"] as? String ?? ""
                trailer.color = record["CD_color"] as? String ?? ""
                trailer.plate = record["CD_plate"] as? String ?? ""
                trailer.notes = record["CD_notes"] as? String ?? ""
                if let asset = record["CD_photoAsset"] as? CKAsset, let bytes = data(from: asset) {
                    trailer.photoData = bytes
                } else if let bytes = record["CD_photoData"] as? Data {
                    trailer.photoData = bytes
                } else {
                    trailer.photoData = nil
                }
                if let lastEdited = record["CD_lastEdited"] as? Date {
                    trailer.lastEdited = lastEdited
                }
            }
        }
        // Deletions are handled via cloud tombstones in fetchRemoteTombstones()
        NotificationCenter.default.post(name: .syncImportedCount, object: nil, userInfo: ["type": "Trailers", "count": records.count])
    }

    // MARK: - DriveLog Sync

    private func pushDriveLogs(context: ModelContext) async throws {
        let driveLogs = try context.fetch(FetchDescriptor<DriveLog>())
        let deleted = tombstonedIDs(in: context)
        let activeLogs = driveLogs.filter { !deleted.contains($0.id) }
        print("CloudKit: pushing \(activeLogs.count) drive logs …")

        var records: [CKRecord] = []
        for log in activeLogs {
            let recordID = recordID(for: "CD_DriveLog", uuid: log.id)
            let record = CKRecord(recordType: "CD_DriveLog", recordID: recordID)

            record["CD_id"] = log.id.uuidString
            record["CD_date"] = log.date
            record["CD_reason"] = log.reason
            record["CD_kmStart"] = log.kmStart
            record["CD_kmEnd"] = log.kmEnd
            record["CD_notes"] = log.notes
            record["CD_lastEdited"] = log.lastEdited

            if let vehicle = log.vehicle {
                record["CD_vehicle"] = referenceID(for: "CD_Vehicle", uuid: vehicle.id)
            }

            if let checklist = log.checklist {
                record["CD_checklist"] = referenceID(for: "CD_Checklist", uuid: checklist.id)
            }

            records.append(record)
        }

        do {
            try await saveRecordsBatch(records)
            NotificationCenter.default.post(name: .syncPushedCount, object: nil, userInfo: ["type": "DriveLogs", "count": activeLogs.count])
            print("CloudKit: pushed \(activeLogs.count) drive logs")
        } catch {
            print("CloudKit: failed to push drive logs batch: \(error)")
            throw error
        }
    }

    private func fetchDriveLogs(context: ModelContext) async throws {
        let query = CKQuery(recordType: "CD_DriveLog", predicate: NSPredicate(value: true))
        let records = try await fetchRecords(query: query)
        let deletedIDs = tombstonedIDs(in: context)
        NotificationCenter.default.post(name: .syncFetchedCount, object: nil, userInfo: ["type": "DriveLogs", "count": records.count])
        print("CloudKit: fetched \(records.count) DriveLogs")

        for record in records {
            guard let idString = record["CD_id"] as? String,
                  let uuid = UUID(uuidString: idString) else { continue }

            if deletedIDs.contains(uuid) { continue }

            let descriptor = FetchDescriptor<DriveLog>(predicate: #Predicate { $0.id == uuid })
            let existing = try context.fetch(descriptor).first

            let log = existing ?? DriveLog()
            if existing == nil {
                log.id = uuid
                context.insert(log)
            }

            let cloudLastEdited = (record["CD_lastEdited"] as? Date) ?? .distantPast
            if existing != nil && log.lastEdited >= cloudLastEdited {
                // Skip overwrite
            } else {
                if let date = record["CD_date"] as? Date {
                    log.date = date
                }
                log.reason = record["CD_reason"] as? String ?? ""
                log.kmStart = record["CD_kmStart"] as? Int ?? 0
                log.kmEnd = record["CD_kmEnd"] as? Int ?? 0
                log.notes = record["CD_notes"] as? String ?? ""
                if let lastEdited = record["CD_lastEdited"] as? Date {
                    log.lastEdited = lastEdited
                }
            }

            // Link to vehicle if reference exists
            if let vehicleRef = record["CD_vehicle"] as? CKRecord.Reference {
                let vehicleUUID = extractUUID(from: vehicleRef.recordID.recordName, prefix: "CD_Vehicle_")
                if let vUUID = vehicleUUID {
                    let vDesc = FetchDescriptor<Vehicle>(predicate: #Predicate { $0.id == vUUID })
                    log.vehicle = try context.fetch(vDesc).first
                }
            }
            // Link to checklist if reference exists
            if let checklistRef = record["CD_checklist"] as? CKRecord.Reference {
                let checklistUUID = extractUUID(from: checklistRef.recordID.recordName, prefix: "CD_Checklist_")
                if let cUUID = checklistUUID {
                    let cDesc = FetchDescriptor<Checklist>(predicate: #Predicate { $0.id == cUUID })
                    log.checklist = try context.fetch(cDesc).first
                }
            }
        }
        // Deletions are handled via cloud tombstones in fetchRemoteTombstones()
        NotificationCenter.default.post(name: .syncImportedCount, object: nil, userInfo: ["type": "DriveLogs", "count": records.count])
    }

    // MARK: - Checklist Sync

    private func pushChecklists(context: ModelContext) async throws {
        let checklists = try context.fetch(FetchDescriptor<Checklist>())
        let deleted = tombstonedIDs(in: context)
        let activeChecklists = checklists.filter { !deleted.contains($0.id) }
        print("CloudKit: pushing \(activeChecklists.count) checklists …")

        var records: [CKRecord] = []
        for checklist in activeChecklists {
            let recordID = recordID(for: "CD_Checklist", uuid: checklist.id)
            let record = CKRecord(recordType: "CD_Checklist", recordID: recordID)

            record["CD_id"] = checklist.id.uuidString
            record["CD_vehicleType"] = checklist.vehicleType.rawValue
            record["CD_title"] = checklist.title
            record["CD_lastEdited"] = checklist.lastEdited

            if let vehicle = checklist.vehicle {
                record["CD_vehicle"] = referenceID(for: "CD_Vehicle", uuid: vehicle.id)
            }

            if let trailer = checklist.trailer {
                record["CD_trailer"] = referenceID(for: "CD_Trailer", uuid: trailer.id)
            }

            records.append(record)
        }

        do {
            try await saveRecordsBatch(records)
            NotificationCenter.default.post(name: .syncPushedCount, object: nil, userInfo: ["type": "Checklists", "count": activeChecklists.count])
            print("CloudKit: pushed \(activeChecklists.count) checklists")
        } catch {
            print("CloudKit: failed to push checklists batch: \(error)")
            throw error
        }
    }

    private func fetchChecklists(context: ModelContext) async throws {
        let query = CKQuery(recordType: "CD_Checklist", predicate: NSPredicate(value: true))
        let records = try await fetchRecords(query: query)
        let deletedIDs = tombstonedIDs(in: context)
        NotificationCenter.default.post(name: .syncFetchedCount, object: nil, userInfo: ["type": "Checklists", "count": records.count])
        print("CloudKit: fetched \(records.count) Checklists")

        for record in records {
            guard let idString = record["CD_id"] as? String,
                  let uuid = UUID(uuidString: idString) else { continue }

            if deletedIDs.contains(uuid) { continue }

            let descriptor = FetchDescriptor<Checklist>(predicate: #Predicate { $0.id == uuid })
            let existing = try context.fetch(descriptor).first

            let checklist = existing ?? Checklist()
            if existing == nil {
                checklist.id = uuid
                context.insert(checklist)
            }

            let cloudLastEdited = (record["CD_lastEdited"] as? Date) ?? .distantPast
            if existing != nil && checklist.lastEdited >= cloudLastEdited {
                // Skip overwrite but still update relationships below
            } else {
                if let typeString = record["CD_vehicleType"] as? String,
                   let type = VehicleType(rawValue: typeString) {
                    checklist.vehicleType = type
                }
                checklist.title = record["CD_title"] as? String ?? ""
                if let lastEdited = record["CD_lastEdited"] as? Date {
                    checklist.lastEdited = lastEdited
                }
            }

            // IMPORTANT: Only link to vehicle/trailer if the reference exists in CloudKit
            // Clear any existing relationships first to prevent phantom attachments
            var hasVehicleReference = false
            var hasTrailerReference = false

            if let vehicleRef = record["CD_vehicle"] as? CKRecord.Reference {
                hasVehicleReference = true
                let vehicleUUID = extractUUID(from: vehicleRef.recordID.recordName, prefix: "CD_Vehicle_")
                if let vUUID = vehicleUUID {
                    let vDesc = FetchDescriptor<Vehicle>(predicate: #Predicate { $0.id == vUUID })
                    if let vehicle = try context.fetch(vDesc).first {
                        checklist.vehicle = vehicle
                    } else {
                        // Referenced vehicle doesn't exist locally - could be deleted or not synced yet
                        checklist.vehicle = nil
                        print("CloudKit: checklist \(uuid) references non-existent vehicle \(vUUID)")
                    }
                }
            }

            if let trailerRef = record["CD_trailer"] as? CKRecord.Reference {
                hasTrailerReference = true
                let trailerUUID = extractUUID(from: trailerRef.recordID.recordName, prefix: "CD_Trailer_")
                if let tUUID = trailerUUID {
                    let tDesc = FetchDescriptor<Trailer>(predicate: #Predicate { $0.id == tUUID })
                    if let trailer = try context.fetch(tDesc).first {
                        checklist.trailer = trailer
                    } else {
                        // Referenced trailer doesn't exist locally - could be deleted or not synced yet
                        checklist.trailer = nil
                        print("CloudKit: checklist \(uuid) references non-existent trailer \(tUUID)")
                    }
                }
            }

            // Clear relationships that shouldn't exist based on CloudKit data
            if !hasVehicleReference && checklist.vehicle != nil {
                print("CloudKit: clearing phantom vehicle link from checklist \(uuid)")
                checklist.vehicle = nil
            }
            if !hasTrailerReference && checklist.trailer != nil {
                print("CloudKit: clearing phantom trailer link from checklist \(uuid)")
                checklist.trailer = nil
            }
        }
        // Deletions are handled via cloud tombstones in fetchRemoteTombstones()
        NotificationCenter.default.post(name: .syncImportedCount, object: nil, userInfo: ["type": "Checklists", "count": records.count])
    }

    // MARK: - ChecklistItem Sync

    private func pushChecklistItems(context: ModelContext) async throws {
        let items = try context.fetch(FetchDescriptor<ChecklistItem>())
        let deleted = tombstonedIDs(in: context)
        print("CloudKit: pushing \(items.count) checklist items …")

        var records: [CKRecord] = []
        for item in items.filter({ !deleted.contains($0.id) }) {
            let recordID = recordID(for: "CD_ChecklistItem", uuid: item.id)
            let record = CKRecord(recordType: "CD_ChecklistItem", recordID: recordID)

            record["CD_id"] = item.id.uuidString
            record["CD_section"] = item.section
            record["CD_title"] = item.title
            record["CD_state"] = item.state.rawValue
            record["CD_note"] = item.note

            if let checklist = item.checklist {
                record["CD_checklist"] = referenceID(for: "CD_Checklist", uuid: checklist.id)
            }

            records.append(record)
        }

        // CloudKit has a limit of 400 records per batch operation
        // Split into chunks if necessary
        let chunkSize = 400
        for chunk in stride(from: 0, to: records.count, by: chunkSize) {
            let end = min(chunk + chunkSize, records.count)
            let batch = Array(records[chunk..<end])
            do {
                try await saveRecordsBatch(batch)
            } catch {
                print("CloudKit: failed to push checklist items batch (\(chunk)-\(end)): \(error)")
            }
        }

        NotificationCenter.default.post(name: .syncPushedCount, object: nil, userInfo: ["type": "ChecklistItems", "count": items.count])
        print("CloudKit: pushed \(items.count) checklist items")
    }

    private func fetchChecklistItems(context: ModelContext) async throws {
        let query = CKQuery(recordType: "CD_ChecklistItem", predicate: NSPredicate(value: true))
        let records = try await fetchRecords(query: query)
        let deletedIDs = tombstonedIDs(in: context)
        NotificationCenter.default.post(name: .syncFetchedCount, object: nil, userInfo: ["type": "ChecklistItems", "count": records.count])
        print("CloudKit: fetched \(records.count) ChecklistItems")

        for record in records {
            guard let idString = record["CD_id"] as? String,
                  let uuid = UUID(uuidString: idString) else { continue }

            if deletedIDs.contains(uuid) { continue }

            let descriptor = FetchDescriptor<ChecklistItem>(predicate: #Predicate { $0.id == uuid })
            let existing = try context.fetch(descriptor).first

            let item = existing ?? ChecklistItem(section: "", title: "")
            if existing == nil {
                item.id = uuid
                context.insert(item)
            }

            let cloudChecklistItemState = (record["CD_state"] as? String).flatMap { ChecklistItemState(rawValue: $0) }
            let localState = item.state
            // Checklist items don’t track lastEdited individually; prefer not to overwrite if local has diverged state.
            if let cloudState = cloudChecklistItemState, localState == .notSelected {
                item.state = cloudState
            }
            item.section = record["CD_section"] as? String ?? item.section
            item.title = record["CD_title"] as? String ?? item.title
            item.note = record["CD_note"] as? String ?? item.note

            // Link to checklist
            if let checklistRef = record["CD_checklist"] as? CKRecord.Reference {
                let checklistUUID = extractUUID(from: checklistRef.recordID.recordName, prefix: "CD_Checklist_")
                if let cUUID = checklistUUID {
                    let cDesc = FetchDescriptor<Checklist>(predicate: #Predicate { $0.id == cUUID })
                    item.checklist = try context.fetch(cDesc).first
                }
            }
        }
        // Deletions are handled via cloud tombstones in fetchRemoteTombstones()
        NotificationCenter.default.post(name: .syncImportedCount, object: nil, userInfo: ["type": "ChecklistItems", "count": records.count])
    }

    // MARK: - CloudKit Helpers

    /// Saves multiple records in a single batch operation (much faster than individual saves)
    private func saveRecordsBatch(_ records: [CKRecord], savePolicy: CKModifyRecordsOperation.RecordSavePolicy = .allKeys) async throws {
        guard !records.isEmpty else { return }

        let op = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        op.savePolicy = savePolicy
        op.isAtomic = false  // Allow partial success - some records may fail but others succeed

        op.perRecordSaveBlock = { recordID, result in
            switch result {
            case .success:
                break
            case .failure(let error):
                if let ckError = error as? CKError {
                    print("CloudKit per-record save error for \(recordID.recordName): \(ckError.code) - \(ckError.localizedDescription)")
                } else {
                    print("CloudKit per-record save error for \(recordID.recordName): \(error)")
                }
                let message: String
                if let ckError = error as? CKError {
                    message = "Save error for \(recordID.recordName): \(ckError.code) - \(ckError.localizedDescription)"
                } else {
                    message = "Save error for \(recordID.recordName): \(error.localizedDescription)"
                }
                NotificationCenter.default.post(name: .syncError, object: nil, userInfo: ["message": message])
            }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            op.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    if let ckError = error as? CKError {
                        print("CloudKit saveRecordsBatch error: \(ckError.code) - \(ckError.localizedDescription)")
                    } else {
                        print("CloudKit saveRecordsBatch error: \(error)")
                    }
                    let message: String
                    if let ckError = error as? CKError {
                        message = "Batch save error: \(ckError.code) - \(ckError.localizedDescription)"
                    } else {
                        message = "Batch save error: \(error.localizedDescription)"
                    }
                    NotificationCenter.default.post(name: .syncError, object: nil, userInfo: ["message": message])

                    // Check for zone not found error
                    if let ckError = error as? CKError, ckError.code == .zoneNotFound {
                        Task {
                            do {
                                try await self.ensureZoneExists()
                                // Retry once after ensuring the zone exists
                                try await self.saveRecordsBatch(records, savePolicy: savePolicy)
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

    private func saveRecord(_ record: CKRecord) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            privateDatabase.save(record) { _, error in
                if let error = error as? CKError, error.code == .zoneNotFound {
                    Task {
                        do {
                            try await self.ensureZoneExists()
                            // Retry once after ensuring the zone exists
                            try await self.saveRecord(record)
                            continuation.resume()
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func fetchRecords(query: CKQuery) async throws -> [CKRecord] {
        var collected: [CKRecord] = []
        return try await withCheckedThrowingContinuation { continuation in
            let operation = CKQueryOperation(query: query)
            operation.zoneID = recordZone.zoneID
            operation.recordMatchedBlock = { _, result in
                if case .success(let record) = result { collected.append(record) }
            }
            operation.queryResultBlock = { result in
                switch result {
                case .success: continuation.resume(returning: collected)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
            privateDatabase.add(operation)
        }
    }

    private func extractUUID(from recordName: String, prefix: String) -> UUID? {
        guard recordName.hasPrefix(prefix) else { return nil }
        let uuidString = String(recordName.dropFirst(prefix.count))
        return UUID(uuidString: uuidString)
    }

    private func deleteAll(ofType recordType: String) async throws {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        let records = try await fetchRecords(query: query)
        guard !records.isEmpty else { return }
        let op = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: records.map { $0.recordID })
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            op.modifyRecordsResultBlock = { result in
                switch result {
                case .success: continuation.resume()
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
            privateDatabase.add(op)
        }
    }
}
private extension Notification.Name {
    static let syncFetchedCount = Notification.Name("SyncFetchedCountNotification")
    static let syncPushedCount = Notification.Name("SyncPushedCountNotification")
    static let syncImportedCount = Notification.Name("SyncImportedCountNotification")
    static let syncError = Notification.Name("SyncErrorNotification")
}

