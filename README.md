# Dumpster

A native macOS app for dumping your thoughts and turning them into organized work. Playful, fast, local-first.

---

## How It Works

1. **Dump** — Open the app, type freely. Each line is a bullet.
2. **Tag** — Use `#hashtags` inline to organize by topic.
3. **Magic tags** — Special tags auto-create items on Enter:
   - `#action` → creates an action item
   - `#brainstorm` → creates a brainstorm item
   - `#win` → logs an achievement
   - `#save` → appends bullet to all tagged Master Docs
   - `#resource` → creates a resource item
4. **Review** — Hit "Analyze with AI" for the ambiguous bullets. AI proposes items, suggests tags.
5. **Master Docs** — Build persistent knowledge documents per topic. Drag bullets in, AI sorts them into sections.

---

## Features

### Daily Dump (Home)
- Freeform daily notepad with auto-bullet formatting
- Magic tag processing on Enter — zero-click item creation
- Attention bar showing overdue/due-today items
- Tag pills bar with search, merge, and sub-tag creation
- "Analyze with AI" for batch extraction of items
- Past days expandable with per-day AI analysis

### Items View
- Filter tabs: All / Actions / Brainstorms / Resources
- "Group by tag" toggle — items organized under their tag headers
- "High prio" filter toggle
- "Completed" toggle
- Clickable due dates with calendar popover
- Priority indicators
- All preferences persist across restarts

### Tags
- Primary organizational unit (replaces clusters)
- Hierarchical: parent tags with expandable sub-tags
- Created automatically from `#hashtags` in your dumps
- Click a tag → see its items + Master Doc
- Drag tags to merge or create parent-child relationships

### Master Docs
- Per-topic persistent documents tied to tags
- AI-powered drag-to-insert: drop bullets, AI places them in the right section
- Batch selection: checkbox bullets → "Send to doc" → AI integrates
- "In doc" indicators (green checkmark on processed bullets)
- AI Synthesize: restructure the entire document
- Accessible from tag search panel or Docs sidebar tab

### Wins
- Standalone achievement log (no dummy parent item needed)
- Log via `#win` in daily dump or from Wins view directly
- Chronological brag doc with optional artifact URLs

### AI (Optional — via Ollama)
- Dump analysis: extract items + suggest tags
- Master Doc insertion: smart placement with section awareness
- Doc synthesis: organize messy notes into structured documents
- Works without Ollama — magic tags handle manual categorization

### System
- Global hotkey: `Ctrl+Option+N` → floating quick-capture panel
- Menu bar icon with "Add Note" and "Open Dumpster"
- Launch at login
- Export all data as Markdown
- Bro mode (dark theme toggle)
- Design package protocol — colors and geometry are swappable

---

## Install

```bash
cd ~/dumpster
swift build -c release
```

Create the app bundle:
```bash
APP="/Applications/Dumpster.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Dumpster "$APP/Contents/MacOS/"
cp -R .build/release/Dumpster_Dumpster.bundle "$APP/Contents/Resources/"
cp Sources/Dumpster/Resources/AppIcon.icns "$APP/Contents/Resources/"
codesign --force --sign - "$APP/Contents/MacOS/Dumpster"
codesign --force --sign - "$APP"
```

### Requirements
- macOS 14 (Sonoma) or later
- Xcode Command Line Tools

### Accessibility (for global hotkey)
1. System Settings > Privacy & Security > Accessibility
2. Add `/Applications/Dumpster.app`
3. Restart the app

### AI Setup (Optional)
1. Install [Ollama](https://ollama.com)
2. `ollama pull llama3.2`
3. Make sure Ollama is running

---

## Data

- Database: `~/.dumpster/dumpster.db` (SQLite)
- Fully local — no cloud, no API keys required
- Migrates from MyMind automatically on first launch (reads `~/.my-mind/mind.db`)

---

## Architecture

```
dumpster/
├── Package.swift
├── Sources/Dumpster/
│   ├── DumpsterApp.swift       # Entry point, menu bar, launch
│   ├── HotkeyManager.swift     # Global Ctrl+Opt+N
│   ├── DumpPanel.swift         # Floating quick-capture
│   ├── ExportService.swift     # Markdown export
│   ├── MigrationService.swift  # One-time import from MyMind
│   ├── FontLoader.swift        # Space Grotesk registration
│   ├── Models/                 # Item, Tag, TagRelationship, DailyDump, MasterDoc, Win, ItemLink
│   ├── Database/               # Fresh schema, single migration, all queries
│   ├── AI/                     # Ollama client + all AI operations
│   ├── ViewModels/             # AppState (navigation, observable state)
│   └── Views/                  # All SwiftUI views + Theme with DesignPackage protocol
└── Resources/                  # Space Grotesk fonts, AppIcon.icns
```

### Design Package Protocol

Colors and geometry are defined in a `DesignPackage` protocol. Swap the entire visual personality by changing one line:

```swift
static var activePackage: DesignPackage = DumpsterFirePackage()
```

---

## Lineage

Dumpster is a ground-up rebuild of [my-mind](https://github.com/inaayat/my-brain-vomit-sorter) (now retired). Key improvements:
- Tags replace clusters as the primary organizer
- Proper `item_tags` join table (no more JSON-in-text)
- Standalone wins (no dummy parent item)
- Magic tags for instant item creation from the dump
- Reactive architecture, design package system
- Single clean database migration (no accumulated v1-v7 history)
