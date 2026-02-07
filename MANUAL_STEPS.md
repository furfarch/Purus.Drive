# Manual Steps Required

## Add Files to Xcode Project

The following files need to be added to the Xcode project manually:

1. **SyncConflict.swift**
   - Location: `/home/runner/work/Purus.Drive/Purus.Drive/SyncConflict.swift`
   - Should be added to the PurusDrive target

2. **SyncConflictView.swift**
   - Location: `/home/runner/work/Purus.Drive/Purus.Drive/SyncConflictView.swift`
   - Should be added to the PurusDrive target

### Steps to Add:
1. Open the project in Xcode
2. Right-click on the project root or appropriate group
3. Select "Add Files to PurusDrive"
4. Navigate to the repository root
5. Select both `SyncConflict.swift` and `SyncConflictView.swift`
6. Ensure "Copy items if needed" is **unchecked** (files are already in correct location)
7. Ensure "Add to targets" includes **PurusDrive**
8. Click "Add"

### Verification:
- Build the project (Cmd+B) to verify no compilation errors
- Check that both files appear in the Project Navigator
- Ensure files are included in the PurusDrive target's "Compile Sources" build phase

## Alternative: Use Command Line (Advanced)

If you prefer to use the command line, you can use `xed` to open the project and then manually add the files through the GUI, or use a tool like `xcodeproj` gem to programmatically add the files.

Note: Manually editing `project.pbxproj` is error-prone and not recommended.
