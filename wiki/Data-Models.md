# Data Models

This document describes all data models in Purus.Drive, their properties, relationships, and how they map to CloudKit.

## Table of Contents

- [Overview](#overview)
- [Core Models](#core-models)
- [Relationships](#relationships)
- [CloudKit Schema](#cloudkit-schema)
- [Model Details](#model-details)

## Overview

Purus.Drive uses **SwiftData** for local persistence and **CloudKit** for cloud synchronization. All models use the `@Model` macro and include a `lastEdited` timestamp for sync conflict detection.

## Core Models

### Model Hierarchy

```
Vehicle
  ├─ type: VehicleType
  ├─ metadata (brand, color, plate, notes, photo)
  ├─ trailer: Trailer? (optional relationship)
  ├─ checklists: [Checklist]
  └─ driveLogs: [DriveLog]

Trailer
  ├─ metadata (brand, color, plate, notes, photo)
  ├─ linkedVehicle: Vehicle? (inverse relationship)
  └─ checklists: [Checklist]

DriveLog
  ├─ date, kmStart, kmEnd, reason, notes
  ├─ vehicle: Vehicle (required relationship)
  └─ checklist: Checklist? (optional relationship)

Checklist
  ├─ title, vehicleType
  ├─ vehicle: Vehicle? (optional relationship)
  ├─ trailer: Trailer? (optional relationship)
  └─ items: [ChecklistItem]

ChecklistItem
  ├─ title, section, note
  ├─ state: ChecklistItemState
  └─ checklist: Checklist (required relationship)

DeletedRecord
  ├─ entityType: String
  ├─ id: UUID
  └─ deletedAt: Date
```

## Model Details

### Vehicle

**Purpose:** Represents any type of vehicle (car, truck, van, boat, motorcycle, etc.)

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `id` | UUID | Unique identifier |
| `type` | VehicleType | Vehicle type (car, van, truck, etc.) |
| `brandModel` | String | Brand and model (e.g., "Toyota Camry") |
| `color` | String | Vehicle color |
| `plate` | String | License plate number |
| `notes` | String | Additional notes |
| `photoData` | Data? | Vehicle photo as JPEG data |
| `trailer` | Trailer? | Linked trailer (optional) |
| `checklists` | [Checklist]? | Associated inspection checklists |
| `driveLogs` | [DriveLog]? | Associated drive logs |
| `lastEdited` | Date | Last modification timestamp |

**CloudKit Record Type:** `CD_Vehicle`

**Example:**
```swift
let vehicle = Vehicle(
    type: .truck,
    brandModel: "Ford F-150",
    color: "Blue",
    plate: "ABC123",
    notes: "Company truck #1"
)
```

### Trailer

**Purpose:** Represents a detachable trailer that can be linked to a vehicle

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `id` | UUID | Unique identifier |
| `brandModel` | String | Brand and model |
| `color` | String | Trailer color |
| `plate` | String | License plate number |
| `notes` | String | Additional notes |
| `photoData` | Data? | Trailer photo as JPEG data |
| `linkedVehicle` | Vehicle? | Currently linked vehicle (inverse) |
| `checklists` | [Checklist]? | Associated inspection checklists |
| `lastEdited` | Date | Last modification timestamp |

**CloudKit Record Type:** `CD_Trailer`

**Notes:**
- A trailer can only be linked to one vehicle at a time
- The relationship is managed bidirectionally (Vehicle.trailer ↔ Trailer.linkedVehicle)

### DriveLog

**Purpose:** Records a single driving trip/journey

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `id` | UUID | Unique identifier |
| `date` | Date | Date of the drive |
| `kmStart` | Int64 | Starting odometer reading (km) |
| `kmEnd` | Int64 | Ending odometer reading (km) |
| `reason` | String | Purpose of the drive |
| `notes` | String | Additional notes |
| `vehicle` | Vehicle | Associated vehicle (required) |
| `checklist` | Checklist? | Optional pre-trip inspection checklist |
| `lastEdited` | Date | Last modification timestamp |

**CloudKit Record Type:** `CD_DriveLog`

**Computed Properties:**
```swift
var distance: Int64 { kmEnd - kmStart }
```

**Example:**
```swift
let log = DriveLog(
    date: Date(),
    kmStart: 45000,
    kmEnd: 45250,
    reason: "Delivery to warehouse",
    vehicle: myVehicle
)
// Distance: 250 km
```

### Checklist

**Purpose:** Reusable pre-trip inspection template with multiple check items

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `id` | UUID | Unique identifier |
| `title` | String | Checklist name |
| `vehicleType` | VehicleType? | Associated vehicle type |
| `vehicle` | Vehicle? | Specific vehicle (if not a template) |
| `trailer` | Trailer? | Specific trailer (if not a template) |
| `items` | [ChecklistItem]? | Check items |
| `lastEdited` | Date | Last modification timestamp |

**CloudKit Record Type:** `CD_Checklist`

**Usage Patterns:**

1. **Template Checklists:** 
   - `vehicleType` is set (e.g., `.truck`)
   - `vehicle` and `trailer` are nil
   - Reusable across multiple vehicles

2. **Instance Checklists:**
   - Linked to specific vehicle or trailer
   - Used for one-time inspections
   - Attached to a DriveLog

**Example:**
```swift
let template = Checklist(
    title: "Truck Pre-Trip Inspection",
    vehicleType: .truck
)

let instance = Checklist(
    title: "Morning Inspection",
    vehicle: myTruck
)
```

### ChecklistItem

**Purpose:** Individual check item within a checklist

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `id` | UUID | Unique identifier |
| `title` | String | Item description (e.g., "Check tire pressure") |
| `section` | String | Category (e.g., "Tires", "Lights", "Brakes") |
| `note` | String | Additional notes or observations |
| `state` | ChecklistItemState | Current state of the check |
| `checklist` | Checklist | Parent checklist (required) |

**CloudKit Record Type:** `CD_ChecklistItem`

**States:**

```swift
enum ChecklistItemState: String, Codable {
    case notSelected  // Not yet checked
    case selected     // ✓ Checked and OK
    case notApplicable // N/A - doesn't apply
    case notOk        // ✗ Issue found
}
```

**State Cycling:**

The state cycles through values when tapped:
```
notSelected → selected → notApplicable → notOk → (back to) notSelected
```

**Example:**
```swift
let item = ChecklistItem(
    title: "Check tire pressure",
    section: "Tires",
    state: .selected,
    checklist: myChecklist
)
```

### DeletedRecord

**Purpose:** Tombstone record to track deletions across devices

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `entityType` | String | Type of deleted entity (e.g., "Vehicle") |
| `id` | UUID | ID of deleted entity |
| `deletedAt` | Date | When entity was deleted |

**CloudKit Record Type:** `CD_Deleted`

**Purpose:**
- When an entity is deleted on Device A, a tombstone is created
- Device B fetches tombstones and deletes matching local entities
- Prevents re-importing deleted items during sync

**Example Flow:**
```
1. User deletes Vehicle(id: "abc") on Device A
2. Vehicle is deleted locally
3. DeletedRecord(entityType: "Vehicle", id: "abc") is created
4. Tombstone is pushed to CloudKit
5. Device B fetches tombstones
6. Device B finds local Vehicle(id: "abc") and deletes it
```

## Enumerations

### VehicleType

**Values:**
- `car` - Standard automobile
- `van` - Van or minivan
- `truck` - Pickup truck or commercial truck
- `trailer` - Trailer (used in checklist templates)
- `camper` - RV or camper van
- `boat` - Boat or watercraft
- `motorbike` - Motorcycle
- `scooter` - Motor scooter or moped
- `other` - Other vehicle types

### ChecklistItemState

**Values:**
- `notSelected` - Initial state, not yet checked
- `selected` - Checked and verified OK
- `notApplicable` - Item doesn't apply to this vehicle
- `notOk` - Issue or problem detected

## Relationships

### One-to-One: Vehicle ↔ Trailer

```swift
// Vehicle side
var trailer: Trailer?

// Trailer side (inverse)
var linkedVehicle: Vehicle?
```

**Rules:**
- A vehicle can have at most one trailer
- A trailer can be linked to at most one vehicle
- Bidirectional relationship maintained automatically

### One-to-Many: Vehicle → DriveLog

```swift
// Vehicle side
var driveLogs: [DriveLog]?

// DriveLog side
var vehicle: Vehicle
```

**Rules:**
- Each drive log must reference exactly one vehicle
- A vehicle can have multiple drive logs
- Deleting a vehicle cascades to its drive logs

### One-to-Many: Vehicle → Checklist

```swift
// Vehicle side
var checklists: [Checklist]?

// Checklist side
var vehicle: Vehicle?
```

**Rules:**
- Template checklists have no vehicle reference
- Instance checklists reference a specific vehicle
- Deleting a vehicle cascades to its checklists

### One-to-Many: Trailer → Checklist

```swift
// Trailer side
var checklists: [Checklist]?

// Checklist side
var trailer: Trailer?
```

**Rules:**
- Template checklists have no trailer reference
- Instance checklists reference a specific trailer
- Deleting a trailer cascades to its checklists

### One-to-Many: Checklist → ChecklistItem

```swift
// Checklist side
var items: [ChecklistItem]?

// ChecklistItem side
var checklist: Checklist
```

**Rules:**
- Each checklist item must reference exactly one checklist
- A checklist can have multiple items
- Deleting a checklist cascades to its items

### One-to-One: DriveLog → Checklist

```swift
// DriveLog side
var checklist: Checklist?
```

**Rules:**
- A drive log can optionally reference a pre-trip checklist
- Checklist captures vehicle state at time of drive
- Deleting a checklist clears the reference from drive logs

## CloudKit Schema

All models map to CloudKit record types with a `CD_` prefix:

| SwiftData Model | CloudKit Record Type | Sync Strategy |
|----------------|---------------------|---------------|
| Vehicle | CD_Vehicle | Full record sync |
| Trailer | CD_Trailer | Full record sync |
| DriveLog | CD_DriveLog | Full record sync |
| Checklist | CD_Checklist | Full record sync |
| ChecklistItem | CD_ChecklistItem | Full record sync |
| DeletedRecord | CD_Deleted | Tombstone-only |

### Field Mappings

CloudKit uses `CD_` prefixed field names:

**Vehicle:**
- `CD_id` → `id.uuidString`
- `CD_type` → `type.rawValue`
- `CD_brandModel` → `brandModel`
- `CD_color` → `color`
- `CD_plate` → `plate`
- `CD_notes` → `notes`
- `CD_photoData` → `photoData` or `CD_photoAsset` → `CKAsset`
- `CD_trailer` → `CKRecord.Reference` to trailer
- `CD_lastEdited` → `lastEdited`

**Relationships:**
- Stored as `CKRecord.Reference` objects
- Point to CloudKit record IDs
- Cascade delete not automatic (handled manually)

### Sync Considerations

1. **Photos:** Can be stored as `Data` (CD_photoData) or `CKAsset` (CD_photoAsset)
2. **References:** Must be resolved after fetching related records
3. **Timestamps:** `lastEdited` used for conflict detection
4. **Tombstones:** Separate record type for tracking deletions

## Validation Rules

### Vehicle / Trailer
- `brandModel` can be empty (displays as "Unnamed Vehicle")
- `plate` can be empty
- Photos are optional

### DriveLog
- `kmEnd` should be ≥ `kmStart` (not enforced at model level)
- `vehicle` is required

### Checklist
- Must have either `vehicleType` (template) or `vehicle`/`trailer` (instance)
- `title` can be empty (displays as "Untitled")

### ChecklistItem
- `title` is required
- `section` groups items logically
- `checklist` is required

## Migration & Versioning

Current schema version: **1.0**

### Ownership Migration

`ChecklistOwnershipMigration.runIfNeeded()` ensures:
- All checklist items properly reference their parent checklist
- Run once on app initialization
- No-op if already completed

### Future Considerations

- Add odometer reading to vehicles
- Add maintenance reminders
- Add fuel tracking
- Add expense tracking

---

*For sync implementation, see [CloudKit Sync](CloudKit-Sync.md)*
