# Architecture Overview

This document describes the technical architecture of Purus.Drive, including the app's structure, design patterns, and key components.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Technology Stack](#technology-stack)
- [Application Architecture](#application-architecture)
- [Design Patterns](#design-patterns)
- [Key Components](#key-components)
- [Data Flow](#data-flow)
- [Sync Architecture](#sync-architecture)

## Technology Stack

### Frameworks & Libraries

- **SwiftUI** - Modern declarative UI framework
- **SwiftData** - Apple's latest persistence framework (successor to Core Data)
- **CloudKit** - iCloud synchronization and storage
- **Vision** - License plate recognition
- **Combine** - Reactive programming for state management
- **UIKit** - Legacy integration (ShareSheet, ImagePicker)

### Build & Development

- **Xcode** - IDE and build system
- **Swift** - Programming language (Swift 5.9+)
- **fastlane** - Automated building and deployment
- **GitHub Actions** - CI/CD pipelines

### Minimum Requirements

- iOS 17.0+
- iPadOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Application Architecture

Purus.Drive follows a modern iOS architecture with these characteristics:

### MVVM Pattern (Model-View-ViewModel)

```
┌─────────────────────────────────────────────┐
│                    View                     │
│              (SwiftUI Views)                │
│  ContentView, VehiclesView, DriveLogView    │
└──────────────┬──────────────────────────────┘
               │ @Query, @State, @ObservedObject
               │
┌──────────────▼──────────────────────────────┐
│              ViewModel                      │
│         (Observable Objects)                │
│  SyncConflictStore, MigrationProgress       │
└──────────────┬──────────────────────────────┘
               │
┌──────────────▼──────────────────────────────┐
│               Model                         │
│          (SwiftData Models)                 │
│  Vehicle, Trailer, DriveLog, Checklist      │
└──────────────┬──────────────────────────────┘
               │
┌──────────────▼──────────────────────────────┐
│            Persistence                      │
│    SwiftData Container + CloudKit Sync      │
└─────────────────────────────────────────────┘
```

### Service Layer

Services encapsulate business logic and external interactions:

- **CloudKitSyncService** - Manages all iCloud synchronization
- **ExportService** - Handles data export to JSON
- **ImportService** - Handles data import from JSON
- **DatabaseResetService** - Manages database reset operations

## Design Patterns

### 1. Singleton Pattern

Used for global service access:

```swift
class CloudKitSyncService {
    static let shared = CloudKitSyncService()
    private init() {}
}
```

**Used in:**
- `CloudKitSyncService`
- `SyncConflictStore`
- `SyncReportStore`

### 2. Observer Pattern

Used for reactive state updates:

```swift
@Observable
class SyncConflictStore {
    var conflicts: [SyncConflict] = []
}
```

**Used in:**
- SwiftUI `@Observable` objects
- Combine publishers
- NotificationCenter for cross-component events

### 3. Repository Pattern

SwiftData provides repository-like access to data:

```swift
@Query(sort: \Vehicle.lastEdited, order: .reverse) 
private var vehicles: [Vehicle]
```

### 4. Factory Pattern

Used in model construction and CloudKit record conversion:

```swift
func toCloudKitRecord() -> CKRecord {
    // Creates CKRecord from model
}
```

### 5. Strategy Pattern

Used for sync conflict resolution:

```swift
enum ConflictResolution {
    case keepLocal
    case keepRemote
    case pending
}
```

## Key Components

### 1. Application Entry Point

**PurusDriveApp.swift**
- Main app entry point (`@main`)
- Configures SwiftData container
- Manages storage mode (local vs iCloud)
- Handles app lifecycle events
- Initiates sync on app activation

### 2. Data Layer

**Models.swift**
- SwiftData models with `@Model` macro
- Core entities: `Vehicle`, `Trailer`, `DriveLog`, `Checklist`, `ChecklistItem`
- Relationships between entities
- Enums for types and states

**DeletedRecord.swift**
- Tombstone records for deleted entities
- Enables proper sync of deletions across devices

**SyncConflict.swift**
- Conflict detection and resolution
- Stores conflicts for user resolution

### 3. View Layer

**ContentView.swift**
- Root view container
- Hosts `SectionsView`

**SectionsView.swift**
- Main navigation hub
- Toolbar with settings, about, add vehicle
- Manages sheets and navigation

**VehiclesViews.swift**
- Vehicle list and detail views
- Vehicle editing interface

**DriveLogViews.swift**
- Drive log list and creation
- Mileage tracking

**ChecklistViews.swift**
- Checklist templates
- Checklist item management
- State cycling (not selected → selected → not applicable → not ok)

**SettingsView.swift**
- Storage mode toggle (local/iCloud)
- Import/export functionality
- Database reset

### 4. Service Layer

**CloudKitSyncService.swift** (1400+ lines)
- Manual CloudKit synchronization
- Two-phase sync: fetch then push
- Conflict detection
- Tombstone handling
- Batch operations for performance
- Main actor isolated for thread safety

**ExportService.swift / ImportService.swift**
- JSON serialization/deserialization
- Data backup and restore
- Handles relationships and photos

**DatabaseResetService.swift**
- Safely clears local database
- Maintains referential integrity

### 5. UI Components

**MigrationOverlayView.swift**
- Sync progress overlay (debug mode)
- Shows current sync operation

**SyncConflictView.swift**
- Conflict resolution UI
- Displays local vs remote versions
- User selection interface

**AboutView.swift**
- App information
- Version details
- CloudKit diagnostics (debug mode)

## Data Flow

### Read Flow

```
User Action
    ↓
SwiftUI View
    ↓
@Query (SwiftData)
    ↓
Local Database
    ↓
Display in UI
```

### Write Flow

```
User Input
    ↓
SwiftUI Binding
    ↓
Model Update
    ↓
SwiftData Save
    ↓
Local Database
    ↓
(If iCloud enabled)
    ↓
CloudKitSyncService
    ↓
Push to CloudKit
```

### Sync Flow

```
App Launch/Resume
    ↓
Check Storage Mode
    ↓
(If iCloud enabled)
    ↓
CloudKitSyncService.performFullSync()
    ↓
Phase 1: Fetch from CloudKit
    ├─ Download records
    ├─ Detect conflicts
    ├─ Import to local DB
    └─ Show conflicts if any
    ↓
Phase 2: Push to CloudKit
    ├─ Upload modified records
    ├─ Upload new records
    └─ Push tombstones
    ↓
Sync Complete
```

## Sync Architecture

See [CloudKit Sync](CloudKit-Sync.md) for detailed synchronization architecture.

### Key Concepts

1. **Manual Sync** - No automatic CloudKit integration; all sync is explicit
2. **Two-Phase Sync** - Fetch first, then push (prevents data loss)
3. **Conflict Detection** - Compares `lastEdited` timestamps
4. **Tombstones** - Tracks deletions across devices
5. **Batch Operations** - Processes records in batches of 200 for performance
6. **@MainActor** - All sync operations run on main thread for safety

### Storage Modes

**Local Mode:**
- Data stored only on device
- No synchronization
- Fast and offline-capable

**iCloud Mode:**
- Data stored locally + synced to iCloud
- Sync on app launch and resume
- Manual sync trigger available
- Conflict resolution UI

### Migration Between Modes

When switching storage modes:

**Local → iCloud:**
1. Upload all local data to CloudKit
2. Perform full sync
3. Enable automatic sync

**iCloud → Local:**
1. Fetch all data from CloudKit
2. Delete all CloudKit records
3. Disable automatic sync

## Thread Safety

- **@MainActor** annotation ensures all SwiftData and CloudKit operations run on main thread
- SwiftUI automatically handles view updates on main thread
- Async/await used for asynchronous operations

## Performance Considerations

1. **Lazy Loading** - Views use `@Query` for automatic updates
2. **Batch Processing** - CloudKit operations process 200 records per batch
3. **Image Optimization** - Photos stored as JPEG with compression
4. **Incremental Sync** - Only modified records are pushed
5. **Efficient Queries** - Predicates filter data before loading

## Error Handling

- CloudKit errors are caught and logged
- User-facing errors shown via alerts
- Fallback to in-memory storage if persistent storage fails
- Diagnostic information available in About screen (debug mode)

## Testing

- **PurusDriveTests** - Unit tests for models and services
- **SyncConflictTests** - Tests for conflict detection and resolution
- **PurusDriveUITests** - UI automation tests

---

*For implementation details, see [CloudKit Sync](CloudKit-Sync.md) and [Data Models](Data-Models.md)*
