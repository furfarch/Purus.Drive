import Foundation
import SwiftData

enum ImportService {

    struct Summary {
        var trailersCreated: Int = 0
        var trailersUpdated: Int = 0
        var vehiclesCreated: Int = 0
        var vehiclesUpdated: Int = 0
        var checklistsCreated: Int = 0
        var checklistsUpdated: Int = 0
        var driveLogsCreated: Int = 0
        var driveLogsUpdated: Int = 0
        var workBlocksCreated: Int = 0
        var workBlocksUpdated: Int = 0
        /// drive logs whose vehicle is not in the file or on this device
        var skipped: Int = 0

        var totalCreated: Int {
            trailersCreated + vehiclesCreated + checklistsCreated + driveLogsCreated + workBlocksCreated
        }

        var totalUpdated: Int {
            trailersUpdated + vehiclesUpdated + checklistsUpdated + driveLogsUpdated + workBlocksUpdated
        }
    }

    enum ImportError: LocalizedError {
        case unsupportedFormat
        case decodeFailed(Error)
        case invalidDate(String)

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat:
                return "Unsupported file format. Please import a JSON export created by this app."
            case .decodeFailed(let err):
                return "Could not read import file: \(err.localizedDescription)"
            case .invalidDate(let raw):
                return "Invalid date in import file: \(raw)"
            }
        }
    }

    /// Merge-imports a previously exported JSON payload.
    ///
    /// De-dupe strategy: entities match by UUID. If an existing entity is found, the one with the
    /// newer `lastEdited` wins (import overwrites only when it is newer).
    @MainActor
    static func importJSON(data: Data, into modelContext: ModelContext) throws -> Summary {
        let decoder = JSONDecoder()
        let payload: ExportPayload
        do {
            payload = try decoder.decode(ExportPayload.self, from: data)
        } catch {
            throw ImportError.decodeFailed(error)
        }

        let iso = ISO8601DateFormatter()
        func date(_ raw: String) throws -> Date {
            guard let d = iso.date(from: raw) else { throw ImportError.invalidDate(raw) }
            return d
        }

        var summary = Summary()
        var removedItemIDs: [UUID] = []

        // a failed import must not leave half the file saved
        do {
            // Fetch existing objects once; merge in-memory.
            let existingVehicles = try modelContext.fetch(FetchDescriptor<Vehicle>())
            let existingTrailers = try modelContext.fetch(FetchDescriptor<Trailer>())
            let existingChecklists = try modelContext.fetch(FetchDescriptor<Checklist>())
            let existingLogs = try modelContext.fetch(FetchDescriptor<DriveLog>())

            var vehicleByID: [UUID: Vehicle] = Dictionary(existingVehicles.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            var trailerByID: [UUID: Trailer] = Dictionary(existingTrailers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            var checklistByID: [UUID: Checklist] = Dictionary(existingChecklists.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            var logByID: [UUID: DriveLog] = Dictionary(existingLogs.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

            // 1) Trailers
            if let trailers = payload.trailers {
                for dto in trailers {
                    let incomingLastEdited = try date(dto.lastEditedISO8601)

                    if let existing = trailerByID[dto.id] {
                        if incomingLastEdited > existing.lastEdited {
                            existing.brandModel = dto.brandModel
                            existing.color = dto.color
                            existing.plate = dto.plate
                            existing.notes = dto.notes
                            existing.lastEdited = incomingLastEdited
                            summary.trailersUpdated += 1
                        }
                    } else {
                        let t = Trailer(brandModel: dto.brandModel, color: dto.color, plate: dto.plate, notes: dto.notes, lastEdited: .now)
                        t.id = dto.id
                        modelContext.insert(t)
                        trailerByID[dto.id] = t
                        summary.trailersCreated += 1
                    }
                }
            }

            // 2) Vehicles (link trailer if available)
            if let vehicles = payload.vehicles {
                for dto in vehicles {
                    let incomingLastEdited = try date(dto.lastEditedISO8601)
                    let incomingType = VehicleType(rawValue: dto.type) ?? .other

                    let linkedTrailer = dto.trailerID.flatMap { trailerByID[$0] }

                    if let existing = vehicleByID[dto.id] {
                        if incomingLastEdited > existing.lastEdited {
                            existing.type = incomingType
                            existing.brandModel = dto.brandModel
                            existing.color = dto.color
                            existing.plate = dto.plate
                            existing.notes = dto.notes
                            existing.trailer = linkedTrailer
                            existing.lastEdited = incomingLastEdited
                            summary.vehiclesUpdated += 1
                        } else {
                            // Still try to restore relationship if missing locally.
                            if existing.trailer == nil, let linkedTrailer {
                                existing.trailer = linkedTrailer
                            }
                        }
                    } else {
                        let v = Vehicle(type: incomingType, brandModel: dto.brandModel, color: dto.color, plate: dto.plate, notes: dto.notes, trailer: linkedTrailer, lastEdited: .now)
                        v.id = dto.id
                        modelContext.insert(v)
                        vehicleByID[dto.id] = v
                        summary.vehiclesCreated += 1
                    }
                }
            }

            // 3) Checklists (items)
            if let checklists = payload.checklists {
                for dto in checklists {
                    let incomingLastEdited = try date(dto.lastEditedISO8601)
                    let incomingType = VehicleType(rawValue: dto.vehicleType) ?? .other

                    // owners are optional: older files have neither
                    let ownerVehicle = dto.vehicleID.flatMap { vehicleByID[$0] }
                    let ownerTrailer = dto.trailerID.flatMap { trailerByID[$0] }

                    if let existing = checklistByID[dto.id] {
                        if incomingLastEdited > existing.lastEdited {
                            existing.vehicleType = incomingType
                            existing.title = dto.title
                            existing.lastEdited = incomingLastEdited
                            if let ownerVehicle { existing.vehicle = ownerVehicle }
                            if let ownerTrailer { existing.trailer = ownerTrailer }

                            // Update items in place by id (new objects with the same ids would leave orphans).
                            var oldItems = Dictionary((existing.items ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                            var merged: [ChecklistItem] = []
                            for itemDTO in dto.items {
                                let state = ChecklistItemState(rawValue: itemDTO.state) ?? .notSelected
                                if let item = oldItems.removeValue(forKey: itemDTO.id) {
                                    item.section = itemDTO.section
                                    item.title = itemDTO.title
                                    item.state = state
                                    item.note = itemDTO.note
                                    merged.append(item)
                                } else {
                                    let item = ChecklistItem(section: itemDTO.section, title: itemDTO.title, state: state, note: itemDTO.note)
                                    item.id = itemDTO.id
                                    merged.append(item)
                                }
                            }
                            for orphan in oldItems.values {
                                removedItemIDs.append(orphan.id)
                                modelContext.delete(orphan)
                            }
                            existing.items = merged
                            summary.checklistsUpdated += 1
                        }
                    } else {
                        let newItems: [ChecklistItem] = dto.items.map { itemDTO in
                            let state = ChecklistItemState(rawValue: itemDTO.state) ?? .notSelected
                            let item = ChecklistItem(section: itemDTO.section, title: itemDTO.title, state: state, note: itemDTO.note)
                            item.id = itemDTO.id
                            return item
                        }
                        let c = Checklist(vehicleType: incomingType, title: dto.title, items: newItems, lastEdited: .now, vehicle: ownerVehicle, trailer: ownerTrailer)
                        c.id = dto.id
                        modelContext.insert(c)
                        checklistByID[dto.id] = c
                        summary.checklistsCreated += 1
                    }
                }
            }

            // 4) Drive logs (link vehicle + checklist if available)
            if let logs = payload.driveLogs {
                for dto in logs {
                    let incomingLastEdited = try date(dto.lastEditedISO8601)
                    let logDate = try date(dto.dateISO8601)

                    guard let vehicleID = dto.vehicleID, let vehicle = vehicleByID[vehicleID] else {
                        // If the import file doesn't include vehicles, we can't re-create logs reliably.
                        summary.skipped += 1
                        continue
                    }

                    let linkedChecklist = dto.checklistID.flatMap { checklistByID[$0] }

                    if let existing = logByID[dto.id] {
                        if incomingLastEdited > existing.lastEdited {
                            existing.vehicle = vehicle
                            existing.date = logDate
                            existing.reason = dto.reason
                            existing.kmStart = dto.kmStart
                            existing.kmEnd = dto.kmEnd
                            existing.notes = dto.notes
                            existing.checklist = linkedChecklist
                            existing.lastEdited = incomingLastEdited
                            summary.driveLogsUpdated += 1
                        } else {
                            // Relationship fix-up on older local record
                            if existing.checklist == nil, let linkedChecklist {
                                existing.checklist = linkedChecklist
                            }
                        }
                    } else {
                        let l = DriveLog(vehicle: vehicle, date: logDate, reason: dto.reason, kmStart: dto.kmStart, kmEnd: dto.kmEnd, notes: dto.notes, checklist: linkedChecklist, lastEdited: .now)
                        l.id = dto.id
                        modelContext.insert(l)
                        logByID[dto.id] = l
                        summary.driveLogsCreated += 1
                    }
                }
            }

            // 5) Work time blocks (no links; the vehicle is stored as plate text)
            var blockIDs: [UUID] = []
            if let dtos = payload.workBlocks {
                let existing = Dictionary(try modelContext.fetch(FetchDescriptor<WorkBlock>()).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                for dto in dtos {
                    let incomingLastEdited = try date(dto.lastEditedISO8601)
                    let target: WorkBlock
                    if let b = existing[dto.id] {
                        guard incomingLastEdited > b.lastEdited else { continue }
                        target = b
                        summary.workBlocksUpdated += 1
                    } else {
                        target = WorkBlock()
                        target.id = dto.id
                        modelContext.insert(target)
                        summary.workBlocksCreated += 1
                    }
                    target.activity = WorkActivity(rawValue: dto.activity) ?? .work
                    target.start = try date(dto.startISO8601)
                    target.end = try dto.endISO8601.map(date)
                    target.vehiclePlate = dto.vehiclePlate
                    target.vehicleName = dto.vehicleName
                    target.kmStart = dto.kmStart
                    target.kmEnd = dto.kmEnd
                    target.placeStart = dto.placeStart
                    target.placeEnd = dto.placeEnd
                    target.exception = dto.exception
                    target.note = dto.note
                    // new records get "now" like the other types, so the import wins over old deletions
                    target.lastEdited = existing[dto.id] == nil ? .now : incomingLastEdited
                    blockIDs.append(dto.id)
                }
            }

            // a restored record must not be deleted again by its own old deletion marker
            let createdIDs = Set(trailerByID.keys).union(vehicleByID.keys).union(checklistByID.keys).union(logByID.keys).union(blockIDs)
            for t in try modelContext.fetch(FetchDescriptor<DeletedRecord>()) where createdIDs.contains(t.id) {
                modelContext.delete(t)
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }

        // tombstone checklist items the file no longer has, only once the import is saved (markDeleted saves the context)
        for id in removedItemIDs {
            CloudKitSyncService.shared.markDeleted(entityType: "ChecklistItem", id: id, cascade: false, autoSync: false)
        }
        // imported records are only local until synced
        NotificationCenter.default.post(name: Notification.Name("RequestFullSyncNotification"), object: nil)

        return summary
    }
}
