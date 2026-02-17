# Purus.Drive Wiki Documentation

This directory contains comprehensive documentation for the Purus.Drive app.

## About

These markdown files are designed to be used as GitHub Wiki pages. They provide detailed information about the app's features, architecture, and usage.

## Wiki Pages

### For Users

1. **[Home.md](Home.md)** - Main wiki landing page with overview and navigation
2. **[Getting-Started.md](Getting-Started.md)** - Installation and initial setup guide
3. **[User-Guide.md](User-Guide.md)** - Comprehensive usage guide for all features
4. **[Features.md](Features.md)** - Detailed documentation of all app features

### For Developers

5. **[Architecture.md](Architecture.md)** - Technical architecture and design patterns
6. **[Data-Models.md](Data-Models.md)** - Complete data model documentation
7. **[CloudKit-Sync.md](CloudKit-Sync.md)** - CloudKit synchronization implementation
8. **[Developer-Guide.md](Developer-Guide.md)** - Development setup and contribution guide

## How to Use

### Option 1: Copy to GitHub Wiki (Recommended)

1. Navigate to your repository's Wiki tab on GitHub
2. Create a new page for each markdown file
3. Copy the content from each `.md` file to the corresponding Wiki page
4. Update the page names to match (e.g., `Home.md` → "Home")
5. The internal links will work automatically

### Option 2: Read from Repository

You can read these files directly from the repository:
- Navigate to the `wiki/` directory
- Click on any `.md` file
- GitHub will render it with proper formatting

### Option 3: Local Viewing

Use any markdown viewer:
- **macOS**: Preview (may need plugin), Typora, MacDown
- **VS Code**: Built-in markdown preview
- **Command line**: `grip` or `mdcat`

## Structure

```
wiki/
├── README.md              (this file)
├── Home.md               (Wiki home page)
├── Getting-Started.md    (User onboarding)
├── User-Guide.md         (Detailed user guide)
├── Features.md           (Feature documentation)
├── Architecture.md       (Technical overview)
├── Data-Models.md        (Model documentation)
├── CloudKit-Sync.md      (Sync implementation)
└── Developer-Guide.md    (Developer information)
```

## Maintenance

### Updating Documentation

When making changes to the app:

1. **New Features**: Update `Features.md` and `User-Guide.md`
2. **Architecture Changes**: Update `Architecture.md`
3. **Data Model Changes**: Update `Data-Models.md`
4. **Sync Changes**: Update `CloudKit-Sync.md`
5. **Developer Process**: Update `Developer-Guide.md`

### Keeping Wiki in Sync

If using GitHub Wiki:

1. Make changes in the `wiki/` directory
2. Commit to the main repository
3. Copy updated content to GitHub Wiki
4. OR: Set up automation to sync automatically

## Contributing

When contributing documentation:

- Use clear, concise language
- Include code examples where helpful
- Add screenshots for UI features (when applicable)
- Follow the existing structure and style
- Update the table of contents if adding sections
- Test all internal links

## Formatting Guidelines

### Headers

Use ATX-style headers:
```markdown
# Top Level
## Second Level
### Third Level
```

### Code Blocks

Use fenced code blocks with language:
````markdown
```swift
let vehicle = Vehicle(type: .truck)
```
````

### Links

Use relative links for internal wiki pages:
```markdown
[Architecture](Architecture.md)
```

### Lists

Use `-` for unordered lists, `1.` for ordered:
```markdown
- Item one
- Item two

1. First step
2. Second step
```

### Emphasis

- **Bold** for important terms: `**bold**`
- *Italic* for emphasis: `*italic*`
- `Code` for code/commands: `` `code` ``

## Screenshots

Screenshots are not included in this documentation to keep file sizes small. When copying to GitHub Wiki, consider adding screenshots:

- **Getting Started**: Installation, first launch
- **Features**: Each main feature in action
- **User Guide**: Step-by-step screenshots for common tasks

## Additional Resources

- **GitHub Repository**: [furfarch/Purus.Drive](https://github.com/furfarch/Purus.Drive)
- **Issues**: Report bugs and request features
- **Pull Requests**: Contribute to the project

## License

Documentation is licensed under the same license as the Purus.Drive project.

---

**Note**: These wiki pages are intended to be copied to GitHub's Wiki feature for best navigation and search functionality. However, they are fully functional as standalone markdown files in the repository.
