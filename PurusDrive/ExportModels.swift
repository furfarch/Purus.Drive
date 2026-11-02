import Foundation

enum ExportScope: String, CaseIterable, Identifiable {
    case all
    case vehicles
    case logs
    case checklists
    case workTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .vehicles: return "Vehicles (incl. trailers)"
        case .logs: return "Drive Logs"
        case .checklists: return "Checklists"
        case .workTime: return "Work time"
        }
    }
}

struct ExportPayload: Codable {
    struct VehicleDTO: Codable {
        var id: UUID
        var type: String
        var brandModel: String
        var color: String
        var plate: String
        var notes: String
        var trailerID: UUID?
        var lastEditedISO8601: String
    }

    struct TrailerDTO: Codable {
        var id: UUID
        var brandModel: String
        var color: String
        var plate: String
        var notes: String
        var lastEditedISO8601: String
    }

    struct DriveLogDTO: Codable {
        var id: UUID
        var vehicleID: UUID?
        var dateISO8601: String
        var reason: String
        var kmStart: Int
        var kmEnd: Int
        var notes: String
        var checklistID: UUID?
        var usedChecklist: Bool?
        var lastEditedISO8601: String
    }

    struct ChecklistDTO: Codable {
        struct ItemDTO: Codable {
            var id: UUID
            var section: String
            var title: String
            var state: String
            var note: String?
        }

        var id: UUID
        var vehicleID: UUID?
        /// optional so files exported before trailer owners were written still import
        var trailerID: UUID?
        var vehicleType: String
        var title: String
        var lastEditedISO8601: String
        var items: [ItemDTO]
    }

    struct WorkBlockDTO: Codable {
        var id: UUID
        var activity: String
        var startISO8601: String
        var endISO8601: String?
        var vehiclePlate: String
        var vehicleName: String
        var kmStart: Int?
        var kmEnd: Int?
        var placeStart: String
        var placeEnd: String
        var exception: Bool
        var note: String
        var lastEditedISO8601: String
    }

    var generatedAtISO8601: String
    var scope: String

    var vehicles: [VehicleDTO]?
    var trailers: [TrailerDTO]?
    var driveLogs: [DriveLogDTO]?
    var checklists: [ChecklistDTO]?
    /// optional: files from before the work-time log have none
    var workBlocks: [WorkBlockDTO]? = nil
}
