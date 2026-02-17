# Purus.Drive

A comprehensive iOS application for professional drivers, fleet operators, and vehicle owners to track vehicles, perform pre-trip inspections, and log drives with iCloud synchronization.

<p align="center">
  <img src="https://img.shields.io/badge/platform-iOS%2017.0%2B-blue.svg" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5.9%2B-orange.svg" alt="Swift">
  <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License">
</p>

## Features

- 🚗 **Multi-Vehicle Tracking** - Manage cars, trucks, vans, trailers, boats, motorcycles, and more
- ✅ **Pre-Trip Checklists** - Customizable inspection templates for vehicle safety
- 📝 **Drive Logging** - Record trips with mileage, dates, and detailed notes
- ☁️ **iCloud Sync** - Automatic synchronization across all your iOS devices
- 🔄 **Conflict Resolution** - Smart handling of sync conflicts with user control
- 📷 **License Plate Scanner** - Built-in OCR for quick plate recognition
- 💾 **Import/Export** - Backup and restore data in JSON format
- 🔒 **Privacy First** - All data stored locally or in your private iCloud

## Screenshots

*Coming soon - Add screenshots of the app in action*

## Requirements

- iOS 17.0+ / iPadOS 17.0+
- Xcode 15.0+ (for development)
- Swift 5.9+
- iCloud account (optional, for sync)

## Installation

### From Source

1. Clone the repository:
   ```bash
   git clone https://github.com/furfarch/Purus.Drive.git
   cd Purus.Drive
   ```

2. Open the project in Xcode:
   ```bash
   open PurusDrive.xcodeproj
   ```

3. Select your target device and run (⌘R)

### From App Store

*Coming soon*

## Quick Start

1. **Launch the app** and choose storage mode (Local or iCloud)
2. **Add your first vehicle** - Tap + and fill in details
3. **Create a checklist template** - Set up pre-trip inspections
4. **Log a drive** - Record your first trip with mileage

For detailed instructions, see the [Getting Started Guide](wiki/Getting-Started.md).

## Documentation

Comprehensive documentation is available in the [Wiki](wiki/):

### For Users

- **[Getting Started](wiki/Getting-Started.md)** - Installation and setup
- **[User Guide](wiki/User-Guide.md)** - Complete usage guide
- **[Features Guide](wiki/Features.md)** - Detailed feature documentation

### For Developers

- **[Architecture](wiki/Architecture.md)** - Technical architecture overview
- **[Data Models](wiki/Data-Models.md)** - Core data structures
- **[CloudKit Sync](wiki/CloudKit-Sync.md)** - Synchronization implementation
- **[Developer Guide](wiki/Developer-Guide.md)** - Contributing and development

## Technology Stack

- **SwiftUI** - Modern declarative UI framework
- **SwiftData** - Apple's latest persistence framework
- **CloudKit** - iCloud synchronization and storage
- **Vision** - License plate recognition
- **Combine** - Reactive state management

## Architecture

Purus.Drive follows MVVM architecture with these key components:

- **Models**: SwiftData entities (Vehicle, Trailer, DriveLog, Checklist)
- **Views**: SwiftUI views with declarative UI
- **Services**: Business logic layer (CloudKitSyncService, ExportService, etc.)
- **Sync**: Manual CloudKit sync with conflict detection

For detailed architecture information, see [Architecture Documentation](wiki/Architecture.md).

## Key Features Explained

### Vehicle Management
Track unlimited vehicles with photos, details, and maintenance notes. Support for multiple vehicle types with custom icons.

### Pre-Trip Inspections
Create reusable checklist templates for different vehicle types. Complete inspections before each drive to ensure safety and compliance.

### Drive Logging
Record trips with start/end mileage, dates, and reasons. Attach pre-trip inspection checklists for complete documentation.

### iCloud Sync
Automatic synchronization across all your devices. Smart conflict resolution when the same item is edited on multiple devices.

### Conflict Resolution
When sync conflicts occur, users can choose which version to keep (local or remote) with clear timestamps and information.

## Development

### Building from Source

```bash
# Clone repository
git clone https://github.com/furfarch/Purus.Drive.git
cd Purus.Drive

# Open in Xcode
open PurusDrive.xcodeproj

# Build and run
# Press ⌘R in Xcode
```

### Running Tests

```bash
# Run all tests
xcodebuild test \
    -project PurusDrive.xcodeproj \
    -scheme PurusDrive \
    -destination 'platform=iOS Simulator,name=iPhone 15'
```

Or press **⌘U** in Xcode.

### Using fastlane

```bash
# Install fastlane
gem install fastlane

# Run tests
fastlane test

# Build for release
fastlane build
```

## Contributing

We welcome contributions! Please see the [Developer Guide](wiki/Developer-Guide.md) for details.

### Quick Contribution Guide

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes and add tests
4. Commit your changes (`git commit -m 'feat: Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

### Code Style

- Follow Apple's Swift API Design Guidelines
- Use SwiftUI best practices
- Keep views small and focused
- Add tests for new features
- Update documentation as needed

## Project Structure

```
Purus.Drive/
├── PurusDrive/              # Main app target
│   ├── Models.swift         # Data models
│   ├── Views/               # SwiftUI views
│   ├── Services/            # Business logic
│   └── Assets.xcassets/     # Images and icons
├── PurusDriveTests/         # Unit tests
├── PurusDriveUITests/       # UI tests
├── wiki/                    # Documentation
├── fastlane/                # Automation
└── .github/                 # CI/CD workflows
```

## CI/CD

The project uses GitHub Actions for continuous integration:

- Automated testing on pull requests
- Build verification
- Code quality checks
- Security scanning

## Roadmap

- [ ] Fuel tracking and economy calculations
- [ ] Maintenance scheduling and reminders
- [ ] Expense tracking
- [ ] Advanced reporting and analytics
- [ ] Export to PDF
- [ ] Multi-language support
- [ ] Apple Watch companion app
- [ ] Siri shortcuts integration

## Known Issues

See [Issues](https://github.com/furfarch/Purus.Drive/issues) for a list of known issues and feature requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

- **Documentation**: [Wiki](wiki/)
- **Bug Reports**: [GitHub Issues](https://github.com/furfarch/Purus.Drive/issues)
- **Feature Requests**: [GitHub Issues](https://github.com/furfarch/Purus.Drive/issues)
- **Discussions**: [GitHub Discussions](https://github.com/furfarch/Purus.Drive/discussions)

## Credits

Developed by Chris Furfari and contributors.

Special thanks to:
- Apple for SwiftUI, SwiftData, and CloudKit frameworks
- The open-source community
- All contributors and testers

## Privacy

Purus.Drive respects your privacy:

- All data stored locally on your device
- iCloud sync uses your private CloudKit container
- No data shared with third parties
- No analytics or tracking
- You control your data completely

## Acknowledgments

- Built with SwiftUI and SwiftData
- Uses Vision framework for license plate recognition
- Follows Apple's Human Interface Guidelines
- Inspired by the needs of professional drivers

---

**Made with ❤️ for the driving community**

For more information, visit the [Wiki](wiki/) or open an [Issue](https://github.com/furfarch/Purus.Drive/issues).
