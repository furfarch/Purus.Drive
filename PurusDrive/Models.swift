import Foundation
import SwiftData

enum VehicleType: String, Codable, CaseIterable, Identifiable {
    case car
    case van
    case truck
    case trailer
    case camper
    case boat
    case motorbike
    case scooter
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .car: return "Car"
        case .van: return "Van"
        case .truck: return "Truck"
        case .trailer: return "Trailer"
        case .camper: return "Camper"
        case .boat: return "Boat"
        case .motorbike: return "Motorbike"
        case .scooter: return "Scooter"
        case .other: return "Other"
        }
    }
}

enum ChecklistItemState: String, Codable, CaseIterable {
    case notSelected
    case selected
    case notApplicable
    case notOk

    mutating func cycle() {
        switch self {
        case .notSelected: self = .selected
        case .selected: self = .notApplicable
        case .notApplicable: self = .notOk
        case .notOk: self = .notSelected
        }
    }
}

@Model
final class Vehicle {
    var id: UUID
    var type: VehicleType
    var brandModel: String
    var color: String
    var plate: String
    var notes: String
    var photoData: Data?

    // Relationship inferred by SwiftData.
    var trailer: Trailer?

    var checklists: [Checklist] = []
    var driveLogs: [DriveLog] = []

    var lastEdited: Date

    init(type: VehicleType, brandModel: String = "", color: String = "", plate: String = "", notes: String = "", trailer: Trailer? = nil, lastEdited: Date = Date.now, photoData: Data? = nil) {
        self.id = UUID()
        self.type = type
        self.brandModel = brandModel
        self.color = color
        self.plate = plate
        self.notes = notes
        self.photoData = photoData
        self.trailer = trailer
        self.lastEdited = lastEdited
    }
}

@Model
final class Trailer {
    var id: UUID
    var brandModel: String
    var color: String
    var plate: String
    var notes: String
    var photoData: Data?

    // Relationship inferred by SwiftData.
    var linkedVehicle: Vehicle?

    var checklists: [Checklist] = []

    var lastEdited: Date

    init(brandModel: String = "", color: String = "", plate: String = "", notes: String = "", lastEdited: Date = Date.now, photoData: Data? = nil) {
        self.id = UUID()
        self.brandModel = brandModel
        self.color = color
        self.plate = plate
        self.notes = notes
        self.photoData = photoData
        self.lastEdited = lastEdited
    }
}

@Model
final class DriveLog {
    var id: UUID

    // CloudKit-safe optional relationship.
    var vehicle: Vehicle?

    var date: Date
    var reason: String
    var kmStart: Int
    var kmEnd: Int
    var notes: String

    // Relationship inferred by SwiftData.
    var checklist: Checklist?

    var lastEdited: Date

    init(vehicle: Vehicle?, date: Date = Date.now, reason: String = "", kmStart: Int = 0, kmEnd: Int = 0, notes: String = "", checklist: Checklist? = nil, lastEdited: Date = Date.now) {
        self.id = UUID()
        self.vehicle = vehicle
        self.date = date
        self.reason = reason
        self.kmStart = kmStart
        self.kmEnd = kmEnd
        self.notes = notes
        self.checklist = checklist
        self.lastEdited = lastEdited
    }
}

@Model
final class Checklist {
    var id: UUID
    var vehicleType: VehicleType
    var title: String

    var items: [ChecklistItem] = []

    // CloudKit-safe optional relationships.
    var vehicle: Vehicle?
    var trailer: Trailer?

    var driveLogs: [DriveLog] = []

    var lastEdited: Date

    init(vehicleType: VehicleType,
         title: String,
         items: [ChecklistItem] = [],
         lastEdited: Date = Date.now,
         vehicle: Vehicle? = nil,
         trailer: Trailer? = nil)
    {
        self.id = UUID()
        self.vehicleType = vehicleType
        self.title = title
        self.items = items
        self.lastEdited = lastEdited
        self.vehicle = vehicle
        self.trailer = trailer
    }
}

@Model
final class ChecklistItem {
    var id: UUID
    var section: String
    var title: String
    var state: ChecklistItemState
    var note: String?

    // Relationship inferred by SwiftData.
    var checklist: Checklist?

    init(section: String, title: String, state: ChecklistItemState = .notSelected, note: String? = nil) {
        self.id = UUID()
        self.section = section
        self.title = title
        self.state = state
        self.note = note
    }
}
