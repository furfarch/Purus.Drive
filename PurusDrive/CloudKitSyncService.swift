import Foundation
import CloudKit
import SwiftData

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

    private init() {}

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Public Sync Methods

    /// Performs a full sync: fetches from cloud then pushes local changes.
    func performFullSync() async {
        guard modelContext != nil else {
            print("CloudKitSyncService: No model context set")
            return
        }

        do {
            // Ensure zone exists
            try await ensureZoneExists()

            // Fetch from cloud first
            await fetchAllFromCloud()

            // Then push local changes
            await pushAllToCloud()

            print("CloudKitSyncService: Full sync completed")
        } catch {
            print("CloudKitSyncService: Sync error - \(error)")
        }
    }

    /// Fetches all records from CloudKit and imports them locally.
    func fetchAllFromCloud() async {
        guard let context = modelContext else { return }

        do {
            try await fetchVehicles(context: context)
            try await fetchTrailers(context: context)
            try await fetchDriveLogs(context: context)
            try await fetchChecklists(context: context)
            try await fetchChecklistItems(context: context)

            try context.save()
            print("CloudKitSyncService: Fetch from cloud completed")
        } catch {
            print("CloudKitSyncService: Fetch error - \(error)")
        }
    }

    /// Pushes all local records to CloudKit.
    func pushAllToCloud() async {
        guard let context = modelContext else { return }

        do {
            try await pushVehicles(context: context)
            try await pushTrailers(context: context)
            try await pushDriveLogs(context: context)
            try await pushChecklists(context: context)
            try await pushChecklistItems(context: context)

            print("CloudKitSyncService: Push to cloud completed")
        } catch {
            print("CloudKitSyncService: Push error - \(error)")
        }
    }

    // MARK: - Zone Management

    private func ensureZoneExists() async throws {
        let zone = CKRecordZone(zoneName: zoneName)
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: nil)

        return try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordZonesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    // Zone already exists is not an error
                    if let ckError = error as? CKError, ckError.code == .serverRejectedRequest {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: error)
                    }
                }
            }
            privateDatabase.add(operation)
        }
    }

    // MARK: - Record ID Helpers

    private func recordID(for type: String, uuid: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: "\(type)_\(uuid.uuidString)", zoneID: recordZone.zoneID)
    }

    private func referenceID(for type: String, uuid: UUID) -> CKRecord.Reference {
        CKRecord.Reference(recordID: recordID(for: type, uuid: uuid), action: .none)
    }

    // MARK: - Vehicle Sync

    private func pushVehicles(context: ModelContext) async throws {
        let vehicles = try context.fetch(FetchDescriptor<Vehicle>())

        for vehicle in vehicles {
            let recordID = recordID(for: "CD_Vehicle", uuid: vehicle.id)
            let record = CKRecord(recordType: "CD_Vehicle", recordID: recordID)

            record["CD_id"] = vehicle.id.uuidString
            record["CD_type"] = vehicle.type.rawValue
            record["CD_brandModel"] = vehicle.brandModel
            record["CD_color"] = vehicle.color
            record["CD_plate"] = vehicle.plate
            record["CD_notes"] = vehicle.notes
            record["CD_lastEdited"] = vehicle.lastEdited

            if let photoData = vehicle.photoData {
                record["CD_photoData"] = photoData
            }

            if let trailer = vehicle.trailer {
                record["CD_trailer"] = referenceID(for: "CD_Trailer", uuid: trailer.id)
            }

            try await saveRecord(record)
        }
    }

    private func fetchVehicles(context: ModelContext) async throws {
        let query = CKQuery(recordType: "CD_Vehicle", predicate: NSPredicate(value: true))
        let records = try await fetchRecords(query: query)

        for record in records {
            guard let idString = record["CD_id"] as? String,
                  let uuid = UUID(uuidString: idString) else { continue }

            // Check if vehicle exists locally
            let descriptor = FetchDescriptor<Vehicle>(predicate: #Predicate { $0.id == uuid })
            let existing = try context.fetch(descriptor).first

            let vehicle = existing ?? Vehicle()
            if existing == nil {
                vehicle.id = uuid
                context.insert(vehicle)
            }

            if let typeString = record["CD_type"] as? String,
               let type = VehicleType(rawValue: typeString) {
                vehicle.type = type
            }
            vehicle.brandModel = record["CD_brandModel"] as? String ?? ""
            vehicle.color = record["CD_color"] as? String ?? ""
            vehicle.plate = record["CD_plate"] as? String ?? ""
            vehicle.notes = record["CD_notes"] as? String ?? ""
            vehicle.photoData = record["CD_photoData"] as? Data
            if let lastEdited = record["CD_lastEdited"] as? Date {
                vehicle.lastEdited = lastEdited
            }

            // Trailer relationship handled after trailers are fetched
        }
    }

    // MARK: - Trailer Sync

    private func pushTrailers(context: ModelContext) async throws {
        let trailers = try context.fetch(FetchDescriptor<Trailer>())

        for trailer in trailers {
            let recordID = recordID(for: "CD_Trailer", uuid: trailer.id)
            let record = CKRecord(recordType: "CD_Trailer", recordID: recordID)

            record["CD_id"] = trailer.id.uuidString
            record["CD_brandModel"] = trailer.brandModel
            record["CD_color"] = trailer.color
            record["CD_plate"] = trailer.plate
            record["CD_notes"] = trailer.notes
            record["CD_lastEdited"] = trailer.lastEdited

            if let photoData = trailer.photoData {
                record["CD_photoData"] = photoData
            }

            if let linkedVehicle = trailer.linkedVehicle {
                record["CD_linkedVehicle"] = referenceID(for: "CD_Vehicle", uuid: linkedVehicle.id)
            }

            try await saveRecord(record)
        }
    }

    private func fetchTrailers(context: ModelContext) async throws {
        let query = CKQuery(recordType: "CD_Trailer", predicate: NSPredicate(value: true))
        let records = try await fetchRecords(query: query)

        for record in records {
            guard let idString = record["CD_id"] as? String,
                  let uuid = UUID(uuidString: idString) else { continue }

            let descriptor = FetchDescriptor<Trailer>(predicate: #Predicate { $0.id == uuid })
            let existing = try context.fetch(descriptor).first

            let trailer = existing ?? Trailer()
            if existing == nil {
                trailer.id = uuid
                context.insert(trailer)
            }

            trailer.brandModel = record["CD_brandModel"] as? String ?? ""
            trailer.color = record["CD_color"] as? String ?? ""
            trailer.plate = record["CD_plate"] as? String ?? ""
            trailer.notes = record["CD_notes"] as? String ?? ""
            trailer.photoData = record["CD_photoData"] as? Data
            if let lastEdited = record["CD_lastEdited"] as? Date {
                trailer.lastEdited = lastEdited
            }
        }
    }

    // MARK: - DriveLog Sync

    private func pushDriveLogs(context: ModelContext) async throws {
        let driveLogs = try context.fetch(FetchDescriptor<DriveLog>())

        for log in driveLogs {
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

            try await saveRecord(record)
        }
    }

    private func fetchDriveLogs(context: ModelContext) async throws {
        let query = CKQuery(recordType: "CD_DriveLog", predicate: NSPredicate(value: true))
        let records = try await fetchRecords(query: query)

        for record in records {
            guard let idString = record["CD_id"] as? String,
                  let uuid = UUID(uuidString: idString) else { continue }

            let descriptor = FetchDescriptor<DriveLog>(predicate: #Predicate { $0.id == uuid })
            let existing = try context.fetch(descriptor).first

            let log = existing ?? DriveLog()
            if existing == nil {
                log.id = uuid
                context.insert(log)
            }

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

            // Link to vehicle if reference exists
            if let vehicleRef = record["CD_vehicle"] as? CKRecord.Reference {
                let vehicleUUID = extractUUID(from: vehicleRef.recordID.recordName, prefix: "CD_Vehicle_")
                if let vUUID = vehicleUUID {
                    let vDesc = FetchDescriptor<Vehicle>(predicate: #Predicate { $0.id == vUUID })
                    log.vehicle = try context.fetch(vDesc).first
                }
            }
        }
    }

    // MARK: - Checklist Sync

    private func pushChecklists(context: ModelContext) async throws {
        let checklists = try context.fetch(FetchDescriptor<Checklist>())

        for checklist in checklists {
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

            try await saveRecord(record)
        }
    }

    private func fetchChecklists(context: ModelContext) async throws {
        let query = CKQuery(recordType: "CD_Checklist", predicate: NSPredicate(value: true))
        let records = try await fetchRecords(query: query)

        for record in records {
            guard let idString = record["CD_id"] as? String,
                  let uuid = UUID(uuidString: idString) else { continue }

            let descriptor = FetchDescriptor<Checklist>(predicate: #Predicate { $0.id == uuid })
            let existing = try context.fetch(descriptor).first

            let checklist = existing ?? Checklist()
            if existing == nil {
                checklist.id = uuid
                context.insert(checklist)
            }

            if let typeString = record["CD_vehicleType"] as? String,
               let type = VehicleType(rawValue: typeString) {
                checklist.vehicleType = type
            }
            checklist.title = record["CD_title"] as? String ?? ""
            if let lastEdited = record["CD_lastEdited"] as? Date {
                checklist.lastEdited = lastEdited
            }

            // Link to vehicle/trailer
            if let vehicleRef = record["CD_vehicle"] as? CKRecord.Reference {
                let vehicleUUID = extractUUID(from: vehicleRef.recordID.recordName, prefix: "CD_Vehicle_")
                if let vUUID = vehicleUUID {
                    let vDesc = FetchDescriptor<Vehicle>(predicate: #Predicate { $0.id == vUUID })
                    checklist.vehicle = try context.fetch(vDesc).first
                }
            }

            if let trailerRef = record["CD_trailer"] as? CKRecord.Reference {
                let trailerUUID = extractUUID(from: trailerRef.recordID.recordName, prefix: "CD_Trailer_")
                if let tUUID = trailerUUID {
                    let tDesc = FetchDescriptor<Trailer>(predicate: #Predicate { $0.id == tUUID })
                    checklist.trailer = try context.fetch(tDesc).first
                }
            }
        }
    }

    // MARK: - ChecklistItem Sync

    private func pushChecklistItems(context: ModelContext) async throws {
        let items = try context.fetch(FetchDescriptor<ChecklistItem>())

        for item in items {
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

            try await saveRecord(record)
        }
    }

    private func fetchChecklistItems(context: ModelContext) async throws {
        let query = CKQuery(recordType: "CD_ChecklistItem", predicate: NSPredicate(value: true))
        let records = try await fetchRecords(query: query)

        for record in records {
            guard let idString = record["CD_id"] as? String,
                  let uuid = UUID(uuidString: idString) else { continue }

            let descriptor = FetchDescriptor<ChecklistItem>(predicate: #Predicate { $0.id == uuid })
            let existing = try context.fetch(descriptor).first

            let item = existing ?? ChecklistItem(section: "", title: "")
            if existing == nil {
                item.id = uuid
                context.insert(item)
            }

            item.section = record["CD_section"] as? String ?? ""
            item.title = record["CD_title"] as? String ?? ""
            if let stateString = record["CD_state"] as? String,
               let state = ChecklistItemState(rawValue: stateString) {
                item.state = state
            }
            item.note = record["CD_note"] as? String

            // Link to checklist
            if let checklistRef = record["CD_checklist"] as? CKRecord.Reference {
                let checklistUUID = extractUUID(from: checklistRef.recordID.recordName, prefix: "CD_Checklist_")
                if let cUUID = checklistUUID {
                    let cDesc = FetchDescriptor<Checklist>(predicate: #Predicate { $0.id == cUUID })
                    item.checklist = try context.fetch(cDesc).first
                }
            }
        }
    }

    // MARK: - CloudKit Helpers

    private func saveRecord(_ record: CKRecord) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            privateDatabase.save(record) { _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func fetchRecords(query: CKQuery) async throws -> [CKRecord] {
        query.sortDescriptors = [NSSortDescriptor(key: "___createTime", ascending: true)]

        return try await withCheckedThrowingContinuation { continuation in
            let operation = CKQueryOperation(query: query)
            operation.zoneID = recordZone.zoneID

            var results: [CKRecord] = []

            operation.recordMatchedBlock = { _, result in
                if case .success(let record) = result {
                    results.append(record)
                }
            }

            operation.queryResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: results)
                case .failure(let error):
                    continuation.resume(throwing: error)
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
}
