# User Guide

A comprehensive guide to using Purus.Drive effectively for vehicle tracking, drive logging, and pre-trip inspections.

## Table of Contents

- [Overview](#overview)
- [Managing Vehicles](#managing-vehicles)
- [Working with Trailers](#working-with-trailers)
- [Logging Drives](#logging-drives)
- [Pre-Trip Inspections](#pre-trip-inspections)
- [Synchronization](#synchronization)
- [Data Management](#data-management)
- [Tips & Best Practices](#tips--best-practices)

## Overview

Purus.Drive helps you:
- Track multiple vehicles and trailers
- Perform pre-trip safety inspections
- Log drives with mileage tracking
- Sync data across all your devices
- Maintain compliance records

## Managing Vehicles

### Creating a Vehicle Profile

A complete vehicle profile includes:

**Basic Information:**
- **Type**: Car, Van, Truck, Camper, Boat, Motorbike, Scooter, Other
- **Brand/Model**: Make and model (e.g., "Ford F-150")
- **Color**: Vehicle color for easy identification
- **License Plate**: Plate number for documentation

**Additional Details:**
- **Notes**: Maintenance notes, special instructions, etc.
- **Photo**: Visual reference of the vehicle
- **Trailer**: Link to a trailer (if applicable)

**Example Vehicle:**
```
Type: Truck
Brand/Model: Chevrolet Silverado 2500HD
Color: Red
Plate: COM-001
Notes: Company truck #1 - Diesel, 4WD
Photo: [Front view photo]
Trailer: 20ft Enclosed Cargo Trailer
```

### Organizing Multiple Vehicles

**Best Practices:**
- Use consistent naming (e.g., "Company Truck #1", "Company Truck #2")
- Add clear photos for quick identification
- Use notes for distinguishing features
- Keep license plates up to date

**Sorting:**
- Vehicles are sorted by last modified date
- Recently used vehicles appear at the top
- Use search (future feature) to find specific vehicles

### Vehicle Photos

**Taking Good Photos:**
- Use good lighting (natural daylight is best)
- Capture the whole vehicle
- Take from a slight angle to show front and side
- Ensure license plate is visible
- Use landscape orientation

**When to Update Photos:**
- After painting or body work
- After adding decals or branding
- After damage or accidents
- Seasonal changes (snow tires, bike racks, etc.)

### Editing Vehicle Information

**Common Updates:**
- Change license plate (after renewal)
- Update notes (maintenance records)
- Change photo (new paint, damage, etc.)
- Link/unlink trailer

**Quick Access:**
- Tap vehicle in list to view details
- Tap "Edit" to modify
- Changes save automatically
- Syncs to all devices (if iCloud enabled)

## Working with Trailers

### Trailer vs. Vehicle

Trailers are managed separately because:
- They can be attached/detached
- They have their own inspection requirements
- One trailer can be used with multiple vehicles
- They need independent tracking

### Creating a Trailer

Similar to vehicles but without vehicle type:

```
Brand/Model: 20ft Enclosed Cargo Trailer
Color: White
Plate: TRL-123
Notes: Ramp door, interior lighting
Photo: [Exterior photo]
```

### Linking and Unlinking

**To Link:**
1. Edit the vehicle
2. Scroll to "Trailer" section
3. Tap "Select Trailer"
4. Choose from existing trailers
5. Save

**To Unlink:**
1. Edit the vehicle (or trailer)
2. Tap "Unlink" in the trailer section
3. Save

**Sync Note:**
- Linking/unlinking syncs across devices
- Both vehicle and trailer must exist on all devices
- If trailer doesn't exist, create it first

### Trailer Checklists

Trailers have separate checklists because they have different inspection requirements:

**Trailer-Specific Items:**
- Coupler and hitch pin
- Safety chains
- Breakaway cable
- Trailer brakes
- Wheel bearings
- Ramp/door operation
- Tie-down points

## Logging Drives

### When to Log a Drive

**Commercial Drivers:**
- Every drive (legally required for many operations)
- Include pre-trip inspection
- Document reason for drive

**Fleet Managers:**
- Track vehicle usage
- Monitor mileage
- Maintenance scheduling

**Personal Use:**
- Track business mileage (tax deduction)
- Maintenance intervals
- Fuel economy calculations

### Complete Drive Log

A thorough drive log includes:

```
Date: February 17, 2026
Vehicle: Ford F-150
Start km: 87,450
End km: 87,685
Distance: 235 km (calculated)
Reason: Delivery to customer site
Notes: Highway driving, good weather
Checklist: Morning Pre-Trip Inspection (completed)
```

### Using Checklists with Drive Logs

**Best Practice:**
1. Create the drive log before the drive
2. Attach a pre-trip checklist
3. Complete the inspection
4. Note any issues found
5. Address issues or note "not ok" items
6. Begin the drive only if safe
7. Update end mileage after drive

**Safety First:**
- Never skip pre-trip inspections for commercial vehicles
- Document all issues found
- Don't drive if critical items fail inspection
- Keep inspection records for compliance

### Editing Past Drive Logs

You can edit:
- End mileage (if you forgot to record it)
- Notes (add additional information)
- Date (if recorded wrong)

You cannot edit:
- The checklist (it captures a point-in-time state)
- The vehicle (create a new log instead)

### Tracking Mileage

**Odometer Readings:**
- Always use kilometers (km)
- Record as shown on odometer
- Distance is calculated automatically

**Common Use Cases:**
- Business mileage for taxes
- Maintenance intervals (oil change every 5,000 km)
- Lease mileage tracking
- Fuel economy calculations

## Pre-Trip Inspections

### Why Pre-Trip Inspections Matter

**Safety:**
- Identify mechanical issues before driving
- Prevent breakdowns on the road
- Ensure lights and signals work

**Compliance:**
- Required for commercial drivers
- Insurance documentation
- DOT requirements

**Maintenance:**
- Early detection of wear
- Schedule repairs proactively
- Extend vehicle life

### Creating Effective Checklists

**Template Structure:**

```
Title: Truck Pre-Trip Inspection
Vehicle Type: Truck

Section: Exterior
- Walk around vehicle for damage
- Check body condition and decals
- Verify registration sticker is current

Section: Tires
- Check tire pressure (all tires)
- Inspect tread depth
- Look for cuts or bulges
- Check lug nut tightness

Section: Lights
- Headlights (low and high beam)
- Parking lights
- Turn signals (front and rear)
- Brake lights
- Reverse lights
- License plate light

Section: Fluids
- Engine oil level
- Coolant level
- Brake fluid level
- Power steering fluid
- Windshield washer fluid

Section: Under Hood
- Battery condition
- Belt condition
- Hose condition
- Leaks or damage

Section: Interior
- Horn operation
- Windshield wipers
- Mirrors adjusted
- Seat belts functional
- Fire extinguisher present

Section: Brakes
- Brake pedal feel
- Parking brake operation
- No unusual sounds

Section: Safety Equipment
- First aid kit
- Warning triangles
- Flashlight
- Tools
```

### Performing an Inspection

**Step by Step:**

1. **Start the checklist** - Open or create from template
2. **Work systematically** - Go section by section
3. **Mark each item**:
   - ✓ Selected = OK
   - N/A = Not applicable
   - ✗ Not OK = Issue found
4. **Add notes** - Document specific findings
5. **Address issues** - Fix problems or document why not
6. **Complete** - Save the checklist

**Documenting Issues:**

```
Item: Check tire pressure (all tires)
State: Not OK
Notes: Front left tire at 28 PSI (should be 35 PSI). Inflated to correct pressure.
```

### Checklist Best Practices

**Template Management:**
- Create one template per vehicle type
- Review and update templates regularly
- Include all legally required items
- Add company-specific requirements

**Inspection Frequency:**
- Commercial vehicles: Daily (before first drive)
- Fleet vehicles: Before each use
- Personal vehicles: Weekly or before long trips
- Trailers: Before attaching and before each trip

**Record Keeping:**
- Keep completed checklists for required period
- Export regularly for external storage
- Use sync for backup
- Document patterns of issues

## Synchronization

### How Sync Works

Purus.Drive uses iCloud to sync data across your devices:

**Sync Timing:**
- Automatic on app launch
- Automatic when app resumes
- Manual via "Sync Now" button

**What Syncs:**
- All vehicles and trailers
- All drive logs
- All checklists (templates and instances)
- Photos
- All relationships
- Deletion records

### Managing Conflicts

**When Conflicts Happen:**

Same item edited on multiple devices:
```
Device A: Edit vehicle "Truck" at 10:00 AM
Device B: Edit same vehicle at 10:05 AM
Device B syncs: Sees Device A's older version
Result: Conflict detected
```

**Resolving Conflicts:**

1. Conflict screen appears
2. Review each conflict:
   - Local version (your device)
   - Remote version (other device)
   - Timestamps shown
3. Choose for each:
   - "Keep local" - Your changes win
   - "Accept remote" - Other device wins
4. Apply all resolutions

**Decision Guide:**
- Keep the most recent edit
- Keep the most complete information
- Keep the version with photos
- Keep the version with notes

### Sync Troubleshooting

**Sync Not Working:**
- [ ] Check internet connection
- [ ] Verify iCloud account signed in
- [ ] Check iCloud storage quota
- [ ] Try manual sync
- [ ] Restart the app

**Conflicts Appearing Often:**
- Multiple users editing same items
- Devices not syncing frequently enough
- Solution: Sync before making changes

**Data Not Appearing:**
- Wait for sync to complete
- Check sync status
- Verify iCloud sync is enabled on both devices
- Check that both devices use same iCloud account

## Data Management

### Exporting Data

**When to Export:**
- Monthly backups
- Before major changes
- Before device changes
- For external record keeping
- For data analysis

**Export Process:**
1. Settings → Export Data
2. Choose scope (All, Vehicles, Logs, Checklists)
3. Select format (JSON)
4. Choose destination
5. Save or share

**What's Included:**
- All selected data and relationships
- Photos (base64 encoded)
- Timestamps
- All metadata

### Importing Data

**Use Cases:**
- Restore from backup
- Transfer to new device (without iCloud)
- Merge data from multiple sources
- Recover deleted items

**Import Process:**
1. Settings → Import Data
2. Select JSON file
3. Review preview
4. Choose strategy:
   - Merge: Add to existing data
   - Replace: Clear and import
5. Confirm import

**Merge Behavior:**
- Existing items are updated if newer
- New items are added
- Relationships are preserved
- Conflicts resolved by timestamp

### Database Reset

**Warning:** Permanently deletes all local data!

**When to Use:**
- Troubleshooting corruption
- Starting fresh
- Before selling device

**Process:**
1. Settings → Reset Local Database
2. Read warning carefully
3. Type confirmation text
4. Confirm reset
5. All local data deleted

**Important:**
- If iCloud sync enabled, can re-sync
- Exported backups are not affected
- Cannot be undone

## Tips & Best Practices

### For Commercial Drivers

**Daily Routine:**
1. Open app before first drive
2. Complete pre-trip inspection
3. Start drive log
4. Complete drive
5. Update end mileage
6. Note any issues

**Compliance:**
- Keep inspection records for required period
- Export monthly for external storage
- Document all issues and resolutions
- Sync across devices for backup

### For Fleet Managers

**Setup:**
- Create standardized checklist templates
- Enable iCloud sync on all devices
- Train drivers on app usage
- Set up export schedule

**Monitoring:**
- Review drive logs regularly
- Check for repeated issues
- Track mileage for maintenance
- Export for reporting

**Maintenance:**
- Use notes to track repairs
- Document service dates
- Track recurring issues
- Schedule based on mileage

### For Personal Use

**Vehicle Maintenance:**
- Log oil changes in notes
- Track tire rotations
- Document repairs
- Record inspection dates

**Tax Documentation:**
- Log business mileage
- Export annually
- Keep backup records
- Document business purposes

**Resale Value:**
- Maintain complete records
- Document all maintenance
- Keep photos up to date
- Show inspection history

### General Tips

**Photography:**
- Take before/after photos
- Document damage immediately
- Keep lighting consistent
- Update photos regularly

**Notes:**
- Be specific and detailed
- Include dates and times
- Document who did what
- Note costs and parts

**Organization:**
- Use consistent naming
- Keep checklists up to date
- Review and clean up regularly
- Archive old vehicles

**Backup:**
- Export monthly
- Keep multiple backups
- Store off-device
- Test restore periodically

---

*For more information, see [Features Guide](Features.md) and [Getting Started](Getting-Started.md)*
