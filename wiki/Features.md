# Features Guide

This document describes all features available in Purus.Drive and how to use them effectively.

## Table of Contents

- [Vehicle Management](#vehicle-management)
- [Trailer Management](#trailer-management)
- [Drive Logging](#drive-logging)
- [Pre-Trip Checklists](#pre-trip-checklists)
- [iCloud Sync](#icloud-sync)
- [Import & Export](#import--export)
- [License Plate Scanner](#license-plate-scanner)
- [Settings](#settings)

## Vehicle Management

### Adding a Vehicle

1. Tap the **+** button in the top-right corner
2. Select vehicle type (Car, Van, Truck, Boat, etc.)
3. Enter vehicle details:
   - Brand/Model (e.g., "Ford F-150")
   - Color
   - License Plate
   - Notes
4. Optionally add a photo
5. Tap **Save**

### Vehicle Types

Purus.Drive supports multiple vehicle types:

- 🚗 **Car** - Standard automobiles
- 🚐 **Van** - Vans and minivans
- 🚚 **Truck** - Pickup trucks and commercial trucks
- 🚙 **Camper** - RVs and camper vans
- 🛥️ **Boat** - Boats and watercraft
- 🏍️ **Motorbike** - Motorcycles
- 🛵 **Scooter** - Motor scooters and mopeds
- ❓ **Other** - Other vehicle types

Each type has a unique icon and can have type-specific checklist templates.

### Editing a Vehicle

1. Tap on the vehicle in the list
2. Tap **Edit** button
3. Modify any fields
4. Tap **Save**

### Deleting a Vehicle

1. Swipe left on the vehicle in the list
2. Tap **Delete**
3. Confirm deletion

**Note:** Deleting a vehicle also deletes:
- All associated drive logs
- All associated checklists
- Unlinks any attached trailer

### Vehicle Photos

**Adding/Changing Photo:**
1. In vehicle edit mode, tap the photo area
2. Choose **Take Photo** or **Choose from Library**
3. Crop if desired
4. Photo is saved automatically

**Removing Photo:**
- In edit mode, long-press the photo and select **Remove Photo**

### Linking a Trailer

1. Edit a vehicle
2. In the **Trailer** section, tap **Select Trailer**
3. Choose a trailer from the list (or create new)
4. Save the vehicle

**Notes:**
- A vehicle can only have one trailer at a time
- A trailer can only be linked to one vehicle at a time
- Unlinking is done by tapping **Unlink** in the trailer section

## Trailer Management

Trailers are managed similarly to vehicles but with some differences:

### Adding a Trailer

1. Tap **+** button
2. Select **Trailer** type
3. Enter details (brand, color, plate, notes)
4. Add photo (optional)
5. Save

### Linking/Unlinking Trailers

**Linking:**
- From vehicle edit screen → Select trailer
- From trailer edit screen → Select vehicle

**Unlinking:**
- From vehicle edit screen → Tap **Unlink**
- From trailer edit screen → Tap **Unlink**

**Sync Note:**
- Trailer linking/unlinking syncs across all devices
- Both vehicles and trailers must exist on all devices before linking

## Drive Logging

Drive logs record individual trips with mileage and details.

### Creating a Drive Log

1. Navigate to **Drive Logs** tab
2. Tap **+** button
3. Fill in details:
   - **Date** - Date of the drive
   - **Vehicle** - Select which vehicle
   - **Start km** - Starting odometer reading
   - **End km** - Ending odometer reading
   - **Reason** - Purpose of the drive
   - **Notes** - Additional details
4. Optionally attach a **Pre-Trip Checklist**
5. Tap **Save**

**Distance Calculation:**
- Automatically calculated: `End km - Start km`
- Displayed in the drive log list

### Attaching a Pre-Trip Checklist

1. When creating/editing a drive log
2. In the **Checklist** section, tap **Select Checklist**
3. Options:
   - Select an existing template
   - Create a new checklist
   - Perform an existing checklist
4. Complete the checklist items before the drive
5. Save the log

**Best Practice:**
- Complete the pre-trip inspection before starting the drive
- Mark any issues found as "Not OK"
- Add notes to checklist items as needed

### Viewing Drive History

The **Drive Logs** tab shows all drives sorted by date (most recent first):

- Date of drive
- Vehicle name and icon
- Distance traveled
- Reason for drive
- Checklist indicator (if attached)

**Filtering:**
- Future enhancement: Filter by vehicle, date range, or reason

### Editing a Drive Log

1. Tap on the drive log in the list
2. Tap **Edit**
3. Modify fields
4. Save

**Note:** You cannot change the attached checklist after saving, but you can change checklist item states.

### Deleting a Drive Log

1. Swipe left on the drive log
2. Tap **Delete**
3. Confirm

**Note:** Deleting a drive log does not delete the attached checklist (it remains as a template).

## Pre-Trip Checklists

Checklists help ensure vehicle safety before driving.

### Checklist Types

**Template Checklists:**
- Reusable across multiple vehicles
- Associated with a vehicle type (e.g., "Truck checklist")
- Not linked to a specific vehicle
- Managed in the **Checklists** tab

**Instance Checklists:**
- Created for a specific vehicle or drive
- Captures the state at a point in time
- Attached to a drive log
- Linked to a specific vehicle

### Creating a Checklist Template

1. Navigate to **Checklists** tab
2. Tap **+** button
3. Enter checklist details:
   - **Title** (e.g., "Truck Pre-Trip Inspection")
   - **Vehicle Type** (Car, Truck, etc.)
4. Add checklist items:
   - **Section** (e.g., "Tires", "Lights", "Brakes")
   - **Title** (e.g., "Check tire pressure")
5. Save

### Checklist Sections

Organize items into logical sections:

**Common Sections:**
- **Exterior** - Body, paint, damage
- **Tires** - Pressure, tread depth, damage
- **Lights** - Headlights, taillights, turn signals
- **Brakes** - Brake pads, fluid level, operation
- **Fluids** - Oil, coolant, washer fluid
- **Interior** - Seats, mirrors, controls
- **Safety** - Fire extinguisher, first aid kit, warning triangles
- **Documents** - Registration, insurance, permits

### Checklist Item States

Each item has one of four states:

1. **Not Selected** (⚪) - Not yet checked
2. **Selected** (✓) - Checked and OK
3. **Not Applicable** (N/A) - Doesn't apply to this vehicle
4. **Not OK** (✗) - Issue found

**Cycling States:**
- Tap an item to cycle through states
- Order: Not Selected → Selected → Not Applicable → Not OK → (repeat)

### Adding Notes to Items

1. Tap on a checklist item
2. Enter notes in the text field
3. Notes are saved automatically

**Use Cases:**
- Document issues found
- Record measurements (e.g., "Tire pressure: 32 PSI")
- Note repairs needed

### Using a Checklist

**Before a Drive:**
1. Create a new drive log
2. Attach a checklist (or select template)
3. Go through each item
4. Mark as Selected (OK) or Not OK
5. Add notes for any issues
6. Complete the drive log

**For Vehicle Inspection:**
1. Navigate to vehicle details
2. Create a new checklist instance
3. Perform the inspection
4. Save for records

### Editing Checklist Templates

1. Go to **Checklists** tab
2. Tap on the template
3. Tap **Edit**
4. Add/remove/modify items
5. Save

**Note:** Editing a template doesn't affect instance checklists already created from it.

### Deleting Checklists

**Template:**
- Swipe left on the checklist
- Tap **Delete**
- Template is deleted but instances remain

**Instance:**
- Delete from the drive log or vehicle
- Instance is removed from the log

## iCloud Sync

Sync your data across all your iOS devices using iCloud.

### Enabling iCloud Sync

1. Open **Settings**
2. Toggle **iCloud Sync** to ON
3. Wait for initial sync to complete
4. All data is uploaded to iCloud
5. Other devices will receive the data

**Requirements:**
- Signed into iCloud on device
- iCloud Drive enabled
- Internet connection

### How Sync Works

**Automatic Sync:**
- On app launch
- When app resumes from background
- After enabling iCloud sync

**Manual Sync:**
- Go to **Settings**
- Tap **Sync Now** button
- Progress is shown in debug builds

### Sync Conflicts

If the same item is edited on multiple devices, a conflict may occur.

**Conflict Resolution:**
1. Sync detects the conflict
2. Conflict resolution screen appears
3. Review each conflict:
   - See local version timestamp
   - See remote version timestamp
4. Choose for each conflict:
   - **Keep local** - Your changes win
   - **Accept remote** - Other device's changes win
5. Tap **Apply** to resolve all conflicts

**When Conflicts Occur:**
- Same vehicle edited on two devices
- Same drive log edited on two devices
- Same checklist edited on two devices

**No Conflicts For:**
- New items (only on one device)
- Deletions (automatic sync)
- Items where one version is clearly newer

### Disabling iCloud Sync

1. Open **Settings**
2. Toggle **iCloud Sync** to OFF
3. Choose what to do with iCloud data:
   - **Keep iCloud Data** - Data remains in iCloud
   - **Delete iCloud Data** - All iCloud data is removed

**Note:** Local data remains on your device regardless.

### Switching Devices

**To Add a New Device:**
1. Install Purus.Drive
2. Sign into the same iCloud account
3. Enable iCloud Sync in settings
4. Wait for sync to complete
5. All data appears on new device

**Troubleshooting Sync:**
- Ensure internet connection
- Check iCloud storage quota
- Verify iCloud account is signed in
- Try manual sync

## Import & Export

Backup and restore your data using JSON export/import.

### Exporting Data

1. Open **Settings**
2. Tap **Export Data**
3. Choose what to export:
   - **All Data** - Everything
   - **Vehicles Only**
   - **Drive Logs Only**
   - **Checklists Only**
4. Choose format: **JSON** (default)
5. Tap **Export**
6. Choose where to save:
   - **Save to Files**
   - **Share via AirDrop, Messages, Mail**

**Export Includes:**
- All selected data
- Relationships (trailers, checklists, logs)
- Photos (base64 encoded)
- Timestamps

### Importing Data

1. Open **Settings**
2. Tap **Import Data**
3. Select a JSON file
4. Review import preview
5. Choose import strategy:
   - **Merge** - Add to existing data
   - **Replace** - Delete existing and import
6. Tap **Import**
7. Review import results

**Import Behavior:**
- Duplicate detection by UUID
- Relationships are restored
- Photos are restored
- Conflicts are resolved by timestamp

**Use Cases:**
- Backup before major changes
- Transfer data to new device (without iCloud)
- Restore after accidental deletion
- Share data with another user

## License Plate Scanner

Use your device camera to automatically recognize license plates.

### Using the Plate Scanner

1. When adding/editing a vehicle or trailer
2. In the **Plate** field, tap the **camera icon**
3. Point camera at license plate
4. Scanner automatically detects text
5. Tap to select the detected plate number
6. Plate is filled into the field

**Supported Formats:**
- Most alphanumeric plates
- Various countries and regions
- May require good lighting

**Tips for Best Results:**
- Ensure good lighting
- Keep camera steady
- Center the plate in frame
- Clean the plate if dirty

**Manual Entry:**
- If scanner doesn't work, type the plate manually
- Scanner is optional, not required

## Settings

Access app settings and tools from the Settings screen.

### Available Settings

**Storage Mode:**
- **Local Storage** - Data stays on device
- **iCloud Sync** - Data syncs across devices

**Sync:**
- **Sync Now** - Manually trigger sync (iCloud mode only)
- **Last Sync** - Shows when last sync occurred

**Data Management:**
- **Export Data** - Backup your data to JSON
- **Import Data** - Restore data from JSON
- **Reset Local Database** - Clear all data (with confirmation)

**About:**
- **App Version** - Current version number
- **Privacy Policy** - (if available)
- **Terms of Service** - (if available)

### Resetting the Database

**Warning:** This permanently deletes all local data!

1. Open **Settings**
2. Tap **Reset Local Database**
3. Enter confirmation text
4. Tap **Confirm Reset**
5. All local data is deleted
6. App returns to initial state

**When to Use:**
- Troubleshooting data corruption
- Starting fresh
- Before uninstalling app

**Note:** 
- If iCloud sync is enabled, data can be re-synced
- Exported backups are not affected

### Storage Mode Migration

When switching between Local and iCloud:

**Local → iCloud:**
1. All local data is uploaded to iCloud
2. Sync is enabled
3. Data syncs automatically

**iCloud → Local:**
1. All iCloud data is downloaded locally
2. iCloud data is optionally deleted
3. Sync is disabled

---

*For technical details, see [Architecture](Architecture.md) and [CloudKit Sync](CloudKit-Sync.md)*
