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

        var totalCreated: Int {
            trailersCreated + vehiclesCreated + checklistsCreated + driveLogsCreated
        }

        var totalUpdated: Int {
            trailersUpdated + vehiclesUpdated + checklistsUpdated + driveLogsUpdated
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

        // Fetch existing objects once; merge in-memory.
        let existingVehicles = try modelContext.fetch(FetchDescriptor<Vehicle>())
        let existingTrailers = try modelContext.fetch(FetchDescriptor<Trailer>())
        let existingChecklists = try modelContext.fetch(FetchDescriptor<Checklist>())
        let existingLogs = try modelContext.fetch(FetchDescriptor<DriveLog>())

        var vehicleByID: [UUID: Vehicle] = Dictionary(uniqueKeysWithValues: existingVehicles.map { ($0.id, $0) })
        var trailerByID: [UUID: Trailer] = Dictionary(uniqueKeysWithValues: existingTrailers.map { ($0.id, $0) })
        var checklistByID: [UUID: Checklist] = Dictionary(uniqueKeysWithValues: existingChecklists.map { ($0.id, $0) })
        var logByID: [UUID: DriveLog] = Dictionary(uniqueKeysWithValues: existingLogs.map { ($0.id, $0) })

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
                    let t = Trailer(brandModel: dto.brandModel, color: dto.color, plate: dto.plate, notes: dto.notes, lastEdited: incomingLastEdited)
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
                    let v = Vehicle(type: incomingType, brandModel: dto.brandModel, color: dto.color, plate: dto.plate, notes: dto.notes, trailer: linkedTrailer, lastEdited: incomingLastEdited)
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

                // Optional owner linking (payload currently exports vehicleID=nil; handle anyway if present)
                let ownerVehicle = dto.vehicleID.flatMap { vehicleByID[$0] }

                if let existing = checklistByID[dto.id] {
                    if incomingLastEdited > existing.lastEdited {
                        existing.vehicleType = incomingType
                        existing.title = dto.title
                        existing.lastEdited = incomingLastEdited
                        if let ownerVehicle { existing.vehicle = ownerVehicle }

                        // Replace items when import is newer.
                        existing.items = dto.items.map { itemDTO in
                            let state = ChecklistItemState(rawValue: itemDTO.state) ?? .notSelected
                            let item = ChecklistItem(section: itemDTO.section, title: itemDTO.title, state: state, note: itemDTO.note)
                            item.id = itemDTO.id
                            return item
                        }
                        summary.checklistsUpdated += 1
                    }
                } else {
                    let newItems: [ChecklistItem] = dto.items.map { itemDTO in
                        let state = ChecklistItemState(rawValue: itemDTO.state) ?? .notSelected
                        let item = ChecklistItem(section: itemDTO.section, title: itemDTO.title, state: state, note: itemDTO.note)
                        item.id = itemDTO.id
                        return item
                    }
                    let c = Checklist(vehicleType: incomingType, title: dto.title, items: newItems, lastEdited: incomingLastEdited, vehicle: ownerVehicle)
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

                guard let vehicle = vehicleByID[dto.vehicleID] else {
                    // If the import file doesn't include vehicles, we can't re-create logs reliably.
                    // Skip silently (merge-friendly).
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
                    let l = DriveLog(vehicle: vehicle, date: logDate, reason: dto.reason, kmStart: dto.kmStart, kmEnd: dto.kmEnd, notes: dto.notes, checklist: linkedChecklist, lastEdited: incomingLastEdited)
                    l.id = dto.id
                    modelContext.insert(l)
                    logByID[dto.id] = l
                    summary.driveLogsCreated += 1
                }
            }
        }

        do {
            try modelContext.save()
        } catch {
            // Let caller surface a generic error; SwiftData can fail for constraints / corruption.
            throw error
        }

        return summary
    }
}
