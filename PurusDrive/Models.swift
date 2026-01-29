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
    var id: UUID = UUID()
    var type: VehicleType = VehicleType.car
    var brandModel: String = ""
    var color: String = ""
    var plate: String = ""
    var notes: String = ""
    var photoData: Data?

    // Explicit relationship with inverse for CloudKit compatibility
    @Relationship(inverse: \Trailer.linkedVehicle)
    var trailer: Trailer?

    @Relationship(deleteRule: .nullify, inverse: \Checklist.vehicle)
    var checklists: [Checklist]? = nil

    @Relationship(deleteRule: .nullify, inverse: \DriveLog.vehicle)
    var driveLogs: [DriveLog]? = nil

    var lastEdited: Date = Date.now

    init(type: VehicleType = .car, brandModel: String = "", color: String = "", plate: String = "", notes: String = "", trailer: Trailer? = nil, lastEdited: Date = Date.now, photoData: Data? = nil) {
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
    var id: UUID = UUID()
    var brandModel: String = ""
    var color: String = ""
    var plate: String = ""
    var notes: String = ""
    var photoData: Data?

    // Inverse relationship - Vehicle owns this relationship
    var linkedVehicle: Vehicle?

    @Relationship(deleteRule: .nullify, inverse: \Checklist.trailer)
    var checklists: [Checklist]? = nil

    var lastEdited: Date = Date.now

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
    var id: UUID = UUID()

    // CloudKit-safe optional relationship - inverse defined on Vehicle
    var vehicle: Vehicle?

    var date: Date = Date.now
    var reason: String = ""
    var kmStart: Int = 0
    var kmEnd: Int = 0
    var notes: String = ""

    // Inverse defined on Checklist
    var checklist: Checklist?

    var lastEdited: Date = Date.now

    init(vehicle: Vehicle? = nil, date: Date = Date.now, reason: String = "", kmStart: Int = 0, kmEnd: Int = 0, notes: String = "", checklist: Checklist? = nil, lastEdited: Date = Date.now) {
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
    var id: UUID = UUID()
    var vehicleType: VehicleType = VehicleType.car
    var title: String = ""

    // Explicit relationship with cascade delete for items
    @Relationship(deleteRule: .cascade, inverse: \ChecklistItem.checklist)
    var items: [ChecklistItem]? = nil

    // CloudKit-safe optional relationships - inverses defined on Vehicle/Trailer
    var vehicle: Vehicle?
    var trailer: Trailer?

    @Relationship(deleteRule: .nullify, inverse: \DriveLog.checklist)
    var driveLogs: [DriveLog]? = nil

    var lastEdited: Date = Date.now

    init(vehicleType: VehicleType = .car,
         title: String = "",
         items: [ChecklistItem] = [],
         lastEdited: Date = Date.now,
         vehicle: Vehicle? = nil,
         trailer: Trailer? = nil)
    {
        self.id = UUID()
        self.vehicleType = vehicleType
        self.title = title
        // Initialize with provided array (empty by default) for convenience
        self.items = items
        self.lastEdited = lastEdited
        self.vehicle = vehicle
        self.trailer = trailer
    }
}

@Model
final class ChecklistItem {
    var id: UUID = UUID()
    var section: String = ""
    var title: String = ""
    var state: ChecklistItemState = ChecklistItemState.notSelected
    var note: String?

    // Inverse defined on Checklist
    var checklist: Checklist?

    init(section: String, title: String, state: ChecklistItemState = .notSelected, note: String? = nil) {
        self.id = UUID()
        self.section = section
        self.title = title
        self.state = state
        self.note = note
    }
}
