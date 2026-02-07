# Sync Conflict Handling Implementation

## Overview
This implementation adds sync conflict detection and resolution to the Purus.Drive CloudKit sync service. When local and remote versions of the same record have both been modified, the system detects the conflict and presents the user with options to resolve it.

## Components

### 1. SyncConflict.swift
- **SyncConflict**: A struct representing a detected conflict with:
  - Entity type (Vehicle, DriveLog, Checklist)
  - Entity ID
  - Local and remote last edited timestamps
  - Remote CloudKit record for resolution

- **ConflictResolution**: Enum with three states:
  - `.keepLocal`: User wants to keep their local changes
  - `.keepRemote`: User wants to accept the remote changes
  - `.pending`: Not yet resolved

- **SyncConflictStore**: Observable object that:
  - Stores detected conflicts
  - Tracks user's resolution choices
  - Provides methods to check for unresolved conflicts

### 2. SyncConflictView.swift
A SwiftUI view that:
- Displays all detected conflicts to the user
- Shows local vs remote timestamps for each conflict
- Allows user to select resolution for each conflict
- Applies all resolutions when user confirms

### 3. CloudKitSyncService.swift modifications

#### Conflict Detection
Added `hasConflict()` method that returns true when:
- Local and remote timestamps differ
- Remote is newer than local (local >= remote returns false)

This ensures conflicts are only shown when remote has changes that would overwrite local changes.

#### Modified Fetch Methods
Updated `fetchVehicles()`, `fetchDriveLogs()`, and `fetchChecklists()` to:
1. Check for conflicts when both versions exist
2. Add conflict to the conflict store
3. Skip applying remote changes until user resolves
4. Still establish relationships (trailers, vehicles, etc.)

#### Exclusions
- **Deletions**: Automatically handled via tombstones (no user confirmation)
- **Trailers**: Conflict detection skipped (waiting for WIP Fix Trailer unlinking)

#### Resolution Methods
- `resolveConflict()`: Applies user's choice
- `applyKeepLocal()`: Pushes local version to cloud
- `applyKeepRemote()`: Applies remote record to local entity

### 4. SectionsView.swift integration
- Added state variable for showing conflict view
- Observes `SyncConflictsDetected` notification
- Shows conflict sheet when unresolved conflicts exist

## User Flow

1. **Sync Triggered**: User syncs with iCloud
2. **Conflict Detection**: During fetch, conflicts are detected and stored
3. **Notification**: After sync completes, if conflicts exist, notification is posted
4. **UI Display**: Conflict sheet automatically appears
5. **User Resolution**: User reviews each conflict and selects keep local or remote
6. **Application**: When user confirms, resolutions are applied
7. **Sync Complete**: Changes are saved and synced

## Design Decisions

### Why detect conflicts only when remote is newer?
The original logic already handles "local wins" (local >= remote). We only need user intervention when remote would overwrite local changes.

### Why store the full CKRecord?
The remote CKRecord is needed to apply all field values when user chooses "keep remote". This avoids re-fetching the record.

### Why skip trailer conflicts?
Per requirements, trailer unlinking has a work-in-progress fix. We'll add trailer conflict detection after that's complete.

## Testing Considerations

To test this feature:
1. Create a vehicle on device A
2. Sync to iCloud
3. On device B, sync to get the vehicle
4. Modify the vehicle on both devices (different changes)
5. On device A, sync first (pushes changes)
6. On device B, sync - conflict should be detected
7. Resolve conflict and verify resolution is applied

## Future Enhancements

- Add merge option (combine local and remote changes)
- Show field-level differences in the conflict UI
- Add conflict detection for trailers after unlinking fix
- Persist conflict resolutions for audit trail
- Add unit tests for conflict detection logic
