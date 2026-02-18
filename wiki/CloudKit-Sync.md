# CloudKit Sync Architecture

This document describes the CloudKit synchronization architecture in Purus.Drive, including conflict detection, resolution strategies, and implementation details.

## Table of Contents

- [Overview](#overview)
- [Sync Architecture](#sync-architecture)
- [Sync Process](#sync-process)
- [Conflict Detection](#conflict-detection)
- [Conflict Resolution](#conflict-resolution)
- [Tombstone Mechanism](#tombstone-mechanism)
- [Performance Optimization](#performance-optimization)
- [Error Handling](#error-handling)

## Overview

Purus.Drive implements **manual CloudKit synchronization** rather than using CloudKit's automatic sync. This provides:

- ✅ **Full control** over sync timing and conflict resolution
- ✅ **Explicit conflict handling** with user decisions
- ✅ **Better error handling** and recovery
- ✅ **Support for deletion tracking** via tombstones
- ✅ **Predictable sync behavior** across devices

## Sync Architecture

### Storage Modes

**Local Storage:**
- Data stored only on device using SwiftData
- No cloud synchronization
- Fast and works offline
- No conflicts possible

**iCloud Storage:**
- Data stored locally using SwiftData
- Manually synced to CloudKit private database
- Automatic sync on app launch and resume
- Conflict detection and resolution

### CloudKit Configuration

```swift
Container ID: iCloud.com.purus.driver
Database: Private (user-specific)
Zone: com.apple.coredata.cloudkit.zone
```

### Service Architecture

```
┌─────────────────────────────────────┐
│      CloudKitSyncService            │
│         (@MainActor)                │
├─────────────────────────────────────┤
│ - container: CKContainer            │
│ - privateDatabase: CKDatabase       │
│ - modelContext: ModelContext        │
│ - conflictStore: SyncConflictStore  │
└─────────────┬───────────────────────┘
              │
    ┌─────────┴──────────┐
    │                    │
┌───▼──────┐      ┌─────▼────────┐
│ SwiftData│      │   CloudKit   │
│  (Local) │      │  (Remote)    │
└──────────┘      └──────────────┘
```

## Sync Process

### Full Sync Flow

```
performFullSync()
    │
    ├─ Phase 1: FETCH
    │   ├─ fetchRemoteTombstones()
    │   │   └─ Delete local records that were deleted remotely
    │   │
    │   ├─ fetchVehicles()
    │   │   ├─ Query CloudKit for all CD_Vehicle records
    │   │   ├─ Detect conflicts (compare lastEdited)
    │   │   └─ Import or store conflict
    │   │
    │   ├─ fetchTrailers()
    │   │   └─ Same as vehicles
    │   │
    │   ├─ fetchDriveLogs()
    │   │   └─ Same as vehicles
    │   │
    │   ├─ fetchChecklists()
    │   │   └─ Same as vehicles
    │   │
    │   └─ fetchChecklistItems()
    │       └─ Always import (no conflicts)
    │
    └─ Phase 2: PUSH
        ├─ pushTombstones()
        │   └─ Upload DeletedRecord records to CloudKit
        │
        ├─ pushVehicles()
        │   ├─ Batch all vehicles
        │   └─ Upload to CloudKit (200 per batch)
        │
        ├─ pushTrailers()
        │   └─ Same as vehicles
        │
        ├─ pushDriveLogs()
        │   └─ Same as vehicles
        │
        ├─ pushChecklists()
        │   └─ Same as vehicles
        │
        └─ pushChecklistItems()
            └─ Same as vehicles
```

### Two-Phase Sync Strategy

**Why Two Phases?**

1. **Phase 1 (Fetch)** must complete before Phase 2 (Push)
2. Prevents overwriting remote changes
3. Allows conflict detection before pushing
4. Ensures all relationships are resolved before pushing

**Example Scenario:**

```
Device A: Edits Vehicle "Truck" at 10:00
Device B: Edits Vehicle "Truck" at 10:05

Device B syncs:
  Phase 1: Fetches Device A's version (10:00)
           Detects conflict (local 10:05 vs remote 10:00)
           Stores conflict for user resolution
  
  User resolves: Keep local (10:05)
  
  Phase 2: Pushes resolved version (10:05) to CloudKit

Device A syncs:
  Phase 1: Fetches Device B's version (10:05)
           No conflict (remote 10:05 > local 10:00)
           Imports remote version
  Phase 2: Nothing to push (already up to date)
```

## Conflict Detection

### Detection Algorithm

```swift
func hasConflict(localLastEdited: Date, remoteLastEdited: Date) -> Bool {
    // No conflict if timestamps are equal
    if localLastEdited == remoteLastEdited {
        return false
    }
    
    // No conflict if local is newer (local wins automatically)
    if localLastEdited > remoteLastEdited {
        return false
    }
    
    // Conflict: remote is newer than local
    // User must decide which version to keep
    return true
}
```

### When Conflicts Occur

A conflict is detected when:
1. ✅ Both devices have the same entity (by UUID)
2. ✅ Remote `lastEdited` is **newer** than local `lastEdited`
3. ✅ This would cause local changes to be overwritten

### When Conflicts Don't Occur

No conflict when:
- ❌ Timestamps are identical (no changes)
- ❌ Local is newer (local wins automatically)
- ❌ Entity only exists locally (new entity, will be pushed)
- ❌ Entity only exists remotely (new entity, will be imported)

### Exclusions

**Not Detected as Conflicts:**

1. **ChecklistItem** - Always imported without conflict detection
   - Items are typically added, not edited
   - Simpler UX for checklist management

2. **Trailer** (currently) - Conflict detection skipped
   - Pending WIP fix for trailer unlinking
   - Will be enabled in future update

3. **Deletions** - Handled automatically via tombstones
   - No user confirmation required
   - Deletion always wins over modification

## Conflict Resolution

### Resolution Options

```swift
enum ConflictResolution: String, Codable {
    case keepLocal   // Keep device's version, push to cloud
    case keepRemote  // Accept cloud version, import locally
    case pending     // Not yet decided by user
}
```

### Resolution Flow

```
1. Sync detects conflict
   └─ Store in SyncConflictStore.shared.conflicts

2. Notification posted: "SyncConflictsDetected"
   └─ UI shows conflict sheet

3. User reviews each conflict:
   ├─ Entity type (Vehicle, DriveLog, Checklist)
   ├─ Local lastEdited timestamp
   └─ Remote lastEdited timestamp

4. User chooses resolution for each:
   ├─ "Keep my local version" → keepLocal
   └─ "Accept remote version" → keepRemote

5. User taps "Apply"
   └─ CloudKitSyncService.applyConflictResolutions()

6. For each resolution:
   ├─ keepLocal: Push local entity to CloudKit
   └─ keepRemote: Import remote record to local entity

7. Clear all resolved conflicts
```

### Conflict Resolution UI

**SyncConflictView.swift** provides:

- List of all conflicts
- Entity type and ID
- Local vs remote timestamps
- Selection controls for each conflict
- Apply button (only enabled when all resolved)
- Cannot dismiss until all conflicts resolved

**User Experience:**

```
┌─────────────────────────────────────┐
│  Sync Conflicts Detected (3)        │
├─────────────────────────────────────┤
│                                     │
│  Vehicle: Truck #123                │
│  Local:  Feb 15, 10:05 AM           │
│  Remote: Feb 15, 10:00 AM           │
│  ○ Keep local   ● Accept remote     │
│                                     │
│  DriveLog: Morning delivery         │
│  Local:  Feb 16, 8:30 AM            │
│  Remote: Feb 16, 8:32 AM            │
│  ● Keep local   ○ Accept remote     │
│                                     │
│  [Apply Resolutions]                │
└─────────────────────────────────────┘
```

### Applying Resolutions

**Keep Local:**
```swift
// Update remote to match local
let record = try await fetchRemoteRecord(id: conflict.id)
updateCloudKitRecord(record, from: localEntity)
await pushRecord(record)
```

**Keep Remote:**
```swift
// Update local to match remote
let record = try await fetchRemoteRecord(id: conflict.id)
applyRemoteChanges(record, to: localEntity)
modelContext.save()
```

## Tombstone Mechanism

### Purpose

Tombstones track deletions across devices to prevent deleted entities from reappearing.

### How It Works

**Deletion Flow:**

```
1. User deletes Vehicle on Device A
   ↓
2. Vehicle deleted from local SwiftData
   ↓
3. DeletedRecord(entityType: "Vehicle", id: <uuid>) created
   ↓
4. Sync pushes tombstone to CloudKit as CD_Deleted
   ↓
5. Device B syncs
   ↓
6. Fetches tombstones from CloudKit
   ↓
7. Finds matching local Vehicle by ID
   ↓
8. Deletes local Vehicle
   ↓
9. Creates local DeletedRecord (prevents re-import)
```

### Tombstone Record Structure

```swift
@Model
final class DeletedRecord {
    var entityType: String  // "Vehicle", "Trailer", etc.
    var id: UUID            // UUID of deleted entity
    var deletedAt: Date     // When deletion occurred
}
```

### CloudKit Tombstone

```
Record Type: CD_Deleted
Record ID: CD_Deleted_<entityType>_<uuid>
Fields:
  - entityType: STRING
  - entityID: STRING
  - deletedAt: TIMESTAMP
```

### Cascade Deletion

When deleting entities with relationships:

**Vehicle Deletion:**
- Delete all associated DriveLog records
- Delete all associated Checklist records
- Unlink from Trailer (if any)
- Create tombstones for all deleted entities

**Trailer Deletion:**
- Delete all associated Checklist records
- Unlink from Vehicle (if any)
- Create tombstone

**Checklist Deletion:**
- Delete all associated ChecklistItem records
- Clear references from DriveLog records
- Create tombstones for all

### Tombstone Cleanup

Tombstones persist indefinitely to ensure deletions propagate to all devices. Future enhancement could add:
- Periodic cleanup of old tombstones (e.g., after 90 days)
- Tombstone expiration based on last sync date

## Performance Optimization

### Batch Processing

All CloudKit operations use batching:

```swift
let BATCH_SIZE = 200

func pushVehicles() async {
    let vehicles = fetchAllVehicles()
    
    for batch in vehicles.chunked(into: BATCH_SIZE) {
        let records = batch.map { $0.toCloudKitRecord() }
        try await database.save(records)
    }
}
```

**Benefits:**
- Reduces API calls
- Better error handling (partial failure recovery)
- Progress reporting per batch

### Query Optimization

**Batch Fetch Tombstones:**
```swift
// Instead of checking existence one by one
let existingTombstones = Set(
    fetchAllTombstones().map { ($0.entityType, $0.id) }
)

// O(1) lookup instead of O(n) query per record
if existingTombstones.contains((type, id)) {
    continue
}
```

### Relationship Resolution

**Two-Pass Relationship Handling:**

1. **First Pass:** Fetch and import all entities
2. **Second Pass:** Resolve references

This prevents missing reference errors when related entities arrive in different batches.

### Photo Handling

Photos can be synced as:

1. **Data** (`CD_photoData: BYTES`) - Inline in record
   - Faster for small images
   - Limited to 1 MB per field

2. **Asset** (`CD_photoAsset: ASSET`) - Separate file
   - Better for large images
   - Lazy loading support
   - Up to 250 MB per asset

Currently using inline Data for simplicity.

## Error Handling

### CloudKit Error Types

**Network Errors:**
- Not connected to internet
- CloudKit service unavailable
- Retry with exponential backoff

**Authentication Errors:**
- User not signed into iCloud
- Show alert prompting sign-in

**Quota Errors:**
- Storage quota exceeded
- Provide guidance to user

**Record Errors:**
- Record not found (deleted on server)
- Record changed (conflict)
- Handle gracefully, don't crash

### Error Recovery

```swift
do {
    try await performSync()
} catch let error as CKError {
    switch error.code {
    case .networkFailure, .networkUnavailable:
        // Retry later
        scheduleRetry()
    
    case .notAuthenticated:
        // Prompt user to sign in
        showAuthAlert()
    
    case .quotaExceeded:
        // Inform user
        showQuotaAlert()
    
    default:
        // Log and continue
        print("Sync error: \(error)")
    }
}
```

### Partial Failure Handling

Batch operations handle partial failures:

```swift
let result = try await database.save(records)

for (index, record) in result.saveResults.enumerated() {
    switch record {
    case .success:
        // Record saved successfully
        continue
    
    case .failure(let error):
        // Individual record failed
        // Log and continue with other records
        print("Failed to save \(records[index]): \(error)")
    }
}
```

## Sync Triggers

### Automatic Sync

Sync automatically triggers on:

1. **App Launch** - `task { await syncIfCloudEnabled() }`
2. **App Resume** - `onChange(of: scenePhase)` from background
3. **Storage Mode Change** - Switch to/from iCloud

### Manual Sync

User can manually trigger sync:

1. **Settings → Sync Now** button
2. Posts `RequestFullSyncNotification`
3. Initiates `performFullSync()`

### Sync Overlay (Debug Mode)

In debug builds, a sync overlay shows:
- Current sync operation
- Progress (entities fetched/pushed)
- Success/failure status

## Thread Safety

All CloudKit operations are `@MainActor`:

```swift
@MainActor
final class CloudKitSyncService {
    // All methods run on main thread
}
```

**Benefits:**
- Safe access to SwiftData (requires main thread)
- Safe UI updates from sync callbacks
- No threading issues with model context

## Future Enhancements

### Planned Improvements

1. **Incremental Sync** - Only sync changed records
2. **Background Sync** - Use BackgroundTasks framework
3. **Trailer Conflicts** - Add conflict detection for trailers
4. **Delta Sync** - Track which fields changed
5. **Compression** - Compress photo data before upload
6. **Encryption** - End-to-end encrypt sensitive fields
7. **Sync History** - Log of all sync operations

### Performance Metrics

Track and optimize:
- Sync duration
- Records transferred
- Bandwidth usage
- Battery impact
- Conflict frequency

---

*For model details, see [Data Models](Data-Models.md)*  
*For architecture overview, see [Architecture](Architecture.md)*
