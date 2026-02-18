# Developer Guide

This guide is for developers who want to contribute to Purus.Drive or understand its codebase.

## Table of Contents

- [Development Setup](#development-setup)
- [Project Structure](#project-structure)
- [Building the App](#building-the-app)
- [Testing](#testing)
- [Code Style](#code-style)
- [Contributing](#contributing)
- [Development Workflow](#development-workflow)

## Development Setup

### Prerequisites

- **macOS** Monterey (12.0) or later
- **Xcode** 15.0 or later
- **iOS Simulator** or physical device with iOS 17.0+
- **Git** for version control
- **GitHub account** for contributions

### Cloning the Repository

```bash
git clone https://github.com/furfarch/Purus.Drive.git
cd Purus.Drive
```

### Opening the Project

```bash
open PurusDrive.xcodeproj
```

Or simply double-click `PurusDrive.xcodeproj` in Finder.

### First Build

1. Select a target device (Simulator or physical device)
2. Press **⌘B** to build
3. Press **⌘R** to run

The app should launch successfully in the simulator or on your device.

### iCloud Development

To test iCloud features:

1. **Simulator**: Sign into an Apple ID in Settings → Apple ID
2. **Physical Device**: Use your own Apple ID
3. **Entitlements**: The project includes iCloud entitlements
4. **Container**: Uses `iCloud.com.purus.driver`

**Note:** You'll need your own Apple Developer account to test iCloud features on a real device.

## Project Structure

```
Purus.Drive/
├── PurusDrive/                 # Main app target
│   ├── PurusDriveApp.swift     # App entry point
│   ├── Models.swift            # SwiftData models
│   ├── ContentView.swift       # Root view
│   ├── SectionsView.swift      # Main navigation
│   │
│   ├── Views/                  # UI Components
│   │   ├── VehiclesViews.swift
│   │   ├── DriveLogViews.swift
│   │   ├── ChecklistViews.swift
│   │   ├── SettingsView.swift
│   │   └── AboutView.swift
│   │
│   ├── Services/               # Business logic
│   │   ├── CloudKitSyncService.swift
│   │   ├── ExportService.swift
│   │   ├── ImportService.swift
│   │   └── DatabaseResetService.swift
│   │
│   ├── Supporting/             # Helpers
│   │   ├── SyncConflict.swift
│   │   ├── SyncReport.swift
│   │   └── DeletedRecord.swift
│   │
│   └── Assets.xcassets/        # Images and icons
│
├── PurusDriveTests/            # Unit tests
│   ├── PurusDriveTests.swift
│   └── SyncConflictTests.swift
│
├── PurusDriveUITests/          # UI tests
│   └── PurusDriveUITests.swift
│
├── fastlane/                   # Automation
│   └── Fastfile
│
├── .github/                    # CI/CD
│   └── workflows/
│       └── ios.yml
│
├── wiki/                       # Documentation
│   ├── Home.md
│   ├── Architecture.md
│   ├── Data-Models.md
│   ├── CloudKit-Sync.md
│   ├── Features.md
│   ├── Getting-Started.md
│   └── Developer-Guide.md
│
└── README.md                   # Project overview
```

### Key Files

**Entry Point:**
- `PurusDriveApp.swift` - `@main` app struct, container setup

**Data Layer:**
- `Models.swift` - All SwiftData models
- `DeletedRecord.swift` - Tombstone for deletions
- `SyncConflict.swift` - Conflict detection model

**Services:**
- `CloudKitSyncService.swift` - CloudKit sync implementation (1400+ lines)
- `ExportService.swift` - JSON export functionality
- `ImportService.swift` - JSON import functionality

**Views:**
- `ContentView.swift` - Root container
- `SectionsView.swift` - Tab navigation
- `VehiclesViews.swift` - Vehicle list and details
- `DriveLogViews.swift` - Drive log management
- `ChecklistViews.swift` - Checklist management

## Building the App

### Debug Build

```bash
xcodebuild -project PurusDrive.xcodeproj \
           -scheme PurusDrive \
           -configuration Debug \
           -sdk iphonesimulator \
           -destination 'platform=iOS Simulator,name=iPhone 15'
```

Or use **⌘B** in Xcode.

### Release Build

```bash
xcodebuild -project PurusDrive.xcodeproj \
           -scheme PurusDrive \
           -configuration Release \
           -sdk iphoneos
```

### Build Configurations

**Debug:**
- Sync overlay enabled (`ENABLE_SYNC_OVERLAY = true`)
- Verbose logging
- Debug diagnostics in About screen

**Release:**
- Sync overlay disabled
- Minimal logging
- Production CloudKit container

### Using fastlane

```bash
# Install fastlane
gem install fastlane

# Run tests
fastlane test

# Build for release
fastlane build

# Deploy to TestFlight
fastlane beta
```

## Testing

### Unit Tests

Run all unit tests:

```bash
xcodebuild test \
    -project PurusDrive.xcodeproj \
    -scheme PurusDrive \
    -destination 'platform=iOS Simulator,name=iPhone 15'
```

Or press **⌘U** in Xcode.

### Test Coverage

Current test files:
- `PurusDriveTests.swift` - General unit tests
- `SyncConflictTests.swift` - Conflict detection tests

**What's Tested:**
- Model initialization
- Conflict detection logic
- Data transformations
- Export/import functionality

**What Needs More Tests:**
- CloudKit operations (requires mocking)
- UI interactions (UITests)
- Edge cases in sync logic

### UI Tests

Run UI tests:

```bash
xcodebuild test \
    -project PurusDrive.xcodeproj \
    -scheme PurusDriveUITests \
    -destination 'platform=iOS Simulator,name=iPhone 15'
```

Or press **⌘U** with UITests selected.

### Manual Testing

**Sync Testing:**
1. Use two simulators or devices
2. Sign into the same iCloud account
3. Enable iCloud sync on both
4. Make changes on one device
5. Trigger sync on the other
6. Verify changes propagate

**Conflict Testing:**
1. Edit same entity on both devices
2. Sync one device
3. Sync the other device
4. Verify conflict UI appears
5. Resolve conflict
6. Verify resolution applied

## Code Style

### Swift Style Guide

Follow Apple's Swift API Design Guidelines:

**Naming:**
- Use clear, descriptive names
- camelCase for variables and functions
- PascalCase for types and protocols
- Descriptive parameter names

```swift
// Good
func fetchVehicles(includingDeleted: Bool = false) async throws -> [Vehicle]

// Avoid
func getV(deleted: Bool) async throws -> [Vehicle]
```

**SwiftUI:**
- Keep views small and focused
- Extract subviews for reusability
- Use `@State`, `@Query`, `@ObservedObject` appropriately

```swift
// Good - small, focused view
struct VehicleRow: View {
    let vehicle: Vehicle
    var body: some View {
        HStack {
            VehicleIcon(type: vehicle.type)
            VehicleDetails(vehicle: vehicle)
        }
    }
}

// Avoid - monolithic view
struct VehicleRow: View {
    let vehicle: Vehicle
    var body: some View {
        // 200 lines of UI code...
    }
}
```

**SwiftData:**
- Use `@Model` macro for persistent models
- Use `@Query` for automatic updates
- Keep models simple, logic in services

```swift
// Good
@Model
final class Vehicle {
    var id: UUID
    var brandModel: String
    // ...
}

// Logic in service
class VehicleService {
    func deleteVehicle(_ vehicle: Vehicle) {
        // Complex deletion logic
    }
}
```

**Async/Await:**
- Use structured concurrency
- Annotate with `@MainActor` when accessing SwiftData

```swift
// Good
@MainActor
func performSync() async {
    await fetchVehicles()
    await pushVehicles()
}
```

**Error Handling:**
- Use proper error types
- Handle errors gracefully
- Provide user-facing error messages

```swift
// Good
do {
    try await syncService.performFullSync()
} catch let error as CKError {
    showAlert(title: "Sync Failed", message: error.localizedDescription)
} catch {
    showAlert(title: "Error", message: "An unexpected error occurred")
}
```

### Comments

**When to Comment:**
- Complex algorithms
- Non-obvious behavior
- Workarounds for bugs
- Public API documentation

**When Not to Comment:**
- Obvious code
- Self-documenting code
- Redundant descriptions

```swift
// Good - explains why
// Use batching to avoid CloudKit rate limits
let BATCH_SIZE = 200

// Avoid - states the obvious
// Increment counter
counter += 1
```

### Code Organization

**File Structure:**
1. Imports
2. Type declaration
3. Properties
4. Initialization
5. Public methods
6. Private methods
7. Extensions (separate file if large)

**Group Related Code:**
- Use `// MARK: -` comments
- Separate concerns
- One responsibility per type

```swift
// MARK: - Initialization

// MARK: - Public API

// MARK: - CloudKit Operations

// MARK: - Helper Methods
```

## Contributing

### Getting Started

1. **Fork** the repository on GitHub
2. **Clone** your fork locally
3. **Create a branch** for your feature
4. **Make changes** and test thoroughly
5. **Commit** with clear messages
6. **Push** to your fork
7. **Open a Pull Request**

### Branch Naming

Use descriptive branch names:

```
feature/add-fuel-tracking
bugfix/sync-conflict-crash
refactor/cleanup-models
docs/update-wiki
```

### Commit Messages

Follow conventional commits:

```
feat: Add fuel tracking feature
fix: Resolve sync conflict crash
refactor: Extract reusable components
docs: Update architecture documentation
test: Add unit tests for sync service
```

**Format:**
```
<type>: <short description>

<optional longer description>

<optional footer>
```

**Types:**
- `feat` - New feature
- `fix` - Bug fix
- `refactor` - Code restructuring
- `docs` - Documentation
- `test` - Tests
- `chore` - Maintenance

### Pull Request Guidelines

**Before Submitting:**
- [ ] Code builds without errors
- [ ] All tests pass
- [ ] New code has tests
- [ ] Documentation updated
- [ ] No merge conflicts

**PR Description Should Include:**
- What changed and why
- How to test the changes
- Screenshots for UI changes
- Related issues (if any)

**Review Process:**
1. Automated CI checks run
2. Maintainer reviews code
3. Feedback is addressed
4. PR is approved and merged

## Development Workflow

### Feature Development

1. **Create Branch**
   ```bash
   git checkout -b feature/my-feature
   ```

2. **Implement Feature**
   - Write code
   - Add tests
   - Update docs

3. **Test Locally**
   - Run unit tests
   - Manual testing
   - Check edge cases

4. **Commit Changes**
   ```bash
   git add .
   git commit -m "feat: Add my feature"
   ```

5. **Push and PR**
   ```bash
   git push origin feature/my-feature
   ```
   Then open a PR on GitHub.

### Bug Fixes

1. **Reproduce Bug**
   - Create a test case that fails
   - Document the bug

2. **Fix Bug**
   - Make minimal changes
   - Verify fix works

3. **Test**
   - Ensure test now passes
   - Check for regressions

4. **Commit and PR**
   ```bash
   git commit -m "fix: Resolve issue with sync conflicts"
   ```

### Refactoring

1. **Ensure Tests Exist**
   - Add tests if missing
   - All tests should pass

2. **Refactor Code**
   - Keep changes focused
   - One refactor at a time

3. **Verify Tests Still Pass**
   - No behavior changes
   - Tests remain green

4. **Document Changes**
   - Update comments if needed
   - Update architecture docs

## Debugging

### Common Issues

**CloudKit Not Working:**
- Check iCloud account is signed in
- Verify entitlements are correct
- Check CloudKit Dashboard for errors

**Sync Conflicts Not Appearing:**
- Ensure debug overlay is enabled
- Check `SyncConflictStore` has conflicts
- Verify notification is posted

**Build Errors:**
- Clean build folder (⌘⇧K)
- Reset package cache
- Restart Xcode

### Debug Tools

**Xcode Debugger:**
- Set breakpoints
- Inspect variables
- Step through code

**Instruments:**
- Profile performance
- Check memory usage
- Find leaks

**Console Logs:**
- `print()` statements in sync service
- CloudKit operation results
- Error messages

### Debug Overlay

In debug builds, a sync overlay shows:
- Current sync operation
- Progress (entities fetched/pushed)
- Success/failure status

Enable/disable in `PurusDriveApp.swift`:
```swift
#if DEBUG
let ENABLE_SYNC_OVERLAY = true
#else
let ENABLE_SYNC_OVERLAY = false
#endif
```

## Resources

### Documentation

- [Architecture Overview](Architecture.md)
- [Data Models](Data-Models.md)
- [CloudKit Sync](CloudKit-Sync.md)
- [Features Guide](Features.md)

### Apple Documentation

- [SwiftUI](https://developer.apple.com/documentation/swiftui/)
- [SwiftData](https://developer.apple.com/documentation/swiftdata/)
- [CloudKit](https://developer.apple.com/documentation/cloudkit/)
- [Swift Language](https://docs.swift.org/swift-book/)

### Community

- [GitHub Issues](https://github.com/furfarch/Purus.Drive/issues)
- [Pull Requests](https://github.com/furfarch/Purus.Drive/pulls)

## License

Purus.Drive is released under [LICENSE] (see LICENSE file).

By contributing, you agree to license your contributions under the same license.

---

*Thank you for contributing to Purus.Drive!*
