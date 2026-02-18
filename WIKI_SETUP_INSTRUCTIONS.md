# How to Copy Wiki Documentation to GitHub

This guide explains how to transfer the Wiki documentation from this repository to GitHub's Wiki feature.

## Prerequisites

- Admin or write access to the repository
- The repository must have Wiki feature enabled

## Enabling Wiki (if not already enabled)

1. Go to repository Settings
2. Scroll to "Features" section
3. Check the "Wikis" checkbox
4. Save changes

## Copying Documentation to Wiki

### Method 1: Manual Copy (Recommended for First Time)

For each wiki page:

1. **Go to Repository Wiki**
   - Click the "Wiki" tab at the top of your repository
   
2. **Create or Edit Page**
   - Click "Create the first page" or "New Page"
   - Enter the page title (without .md extension):
     - `Home` (not Home.md)
     - `Getting-Started`
     - `Architecture`
     - etc.

3. **Copy Content**
   - Open the corresponding `.md` file from the `wiki/` directory
   - Copy all the content
   - Paste into the Wiki editor
   
4. **Save Page**
   - Add a commit message
   - Click "Save Page"

5. **Repeat** for all pages:
   - Home.md → Home
   - Getting-Started.md → Getting-Started
   - User-Guide.md → User-Guide
   - Features.md → Features
   - Architecture.md → Architecture
   - Data-Models.md → Data-Models
   - CloudKit-Sync.md → CloudKit-Sync
   - Developer-Guide.md → Developer-Guide

### Method 2: Clone Wiki Repository (Advanced)

GitHub Wikis are actually Git repositories themselves.

1. **Clone the Wiki Repository**
   ```bash
   git clone https://github.com/furfarch/Purus.Drive.wiki.git
   cd Purus.Drive.wiki
   ```

2. **Copy Files**
   ```bash
   cp ../wiki/*.md .
   ```

3. **Commit and Push**
   ```bash
   git add *.md
   git commit -m "Add comprehensive documentation"
   git push origin master
   ```

4. **Refresh Wiki**
   - Go to Wiki tab on GitHub
   - Pages should now appear

## Page Order

GitHub Wiki pages appear alphabetically by default. Set up the sidebar for custom navigation:

### Creating a Sidebar

1. In Wiki, create a page called `_Sidebar`
2. Add navigation links:

```markdown
**For Users**
- [Home](Home)
- [Getting Started](Getting-Started)
- [User Guide](User-Guide)
- [Features](Features)

**For Developers**
- [Architecture](Architecture)
- [Data Models](Data-Models)
- [CloudKit Sync](CloudKit-Sync)
- [Developer Guide](Developer-Guide)
```

3. Save the `_Sidebar` page
4. Sidebar now appears on all Wiki pages

## Creating a Footer

1. Create a page called `_Footer`
2. Add footer content:

```markdown
---
*Purus.Drive Documentation* | [Report an Issue](https://github.com/furfarch/Purus.Drive/issues) | [View Source](https://github.com/furfarch/Purus.Drive)
```

3. Save the `_Footer` page
4. Footer appears at bottom of all pages

## Link Format Changes

When copying to GitHub Wiki, update internal links:

**From** (repository format):
```markdown
[Architecture](Architecture.md)
```

**To** (Wiki format):
```markdown
[Architecture](Architecture)
```

Note: Remove the `.md` extension for Wiki links.

## Verifying Documentation

After copying, verify:

- [ ] All pages created
- [ ] Home page displays correctly
- [ ] Internal links work (click through to test)
- [ ] Code blocks render properly
- [ ] Tables display correctly
- [ ] Lists are formatted properly
- [ ] Sidebar navigation works (if created)

## Maintenance

### Updating Documentation

When updating the Wiki:

**Option A: Update in Repository First**
1. Update the `.md` file in `wiki/` directory
2. Commit to repository
3. Copy updated content to GitHub Wiki

**Option B: Update Wiki Directly**
1. Edit page in GitHub Wiki
2. Optionally: Copy changes back to repository

### Keeping in Sync

Recommended approach:
- Treat repository `wiki/` directory as source of truth
- Make changes there first
- Copy to GitHub Wiki for publication
- Consider setting up automation to sync automatically

## Alternative: Keep Documentation in Repository Only

If you prefer not to use GitHub's Wiki feature:

- Leave files in `wiki/` directory
- Users can read directly from repository
- Add link to Wiki in README:
  ```markdown
  ## Documentation
  See the [Wiki](wiki/) for comprehensive documentation.
  ```

## Troubleshooting

**Wiki not appearing:**
- Ensure Wiki feature is enabled in repository settings
- Check if you have write access

**Links not working:**
- Remove `.md` extension from Wiki links
- Use exact page names (case-sensitive)
- No spaces in links (use hyphens instead)

**Formatting issues:**
- Check markdown syntax
- Ensure code blocks use triple backticks
- Verify table formatting

**Images not showing:**
- Wiki doesn't support relative image links
- Upload images directly to Wiki
- Or use absolute URLs from repository

## Benefits of GitHub Wiki

✅ Better navigation with sidebar  
✅ Built-in search functionality  
✅ Better mobile experience  
✅ Edit history for each page  
✅ Collaborative editing  
✅ Clone and work offline  

## Summary

The easiest approach:

1. Enable Wiki in repository settings
2. Go to Wiki tab
3. Create each page (without .md extension)
4. Copy content from `wiki/*.md` files
5. Create `_Sidebar` for navigation
6. Test all links

Your Wiki is now ready for users and developers!

---

*Last Updated: February 2026*
