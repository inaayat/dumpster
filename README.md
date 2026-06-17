# Dumpster

A native macOS app for dumping your thoughts and turning them into organized work. Playful, fast, local-first.

---

## How It Works

1. **Dump** — Open the app, type freely. Each line is a bullet.
2. **Tag** — Use `#hashtags` inline to organize by topic.
3. **Magic tags** — Special tags auto-create items (processed on Enter — type all your tags first):
   - `#action` → creates an action item (green)
   - `#prio` → makes it high priority; combine with `#action` or use alone (orange)
   - `#brainstorm` → creates a brainstorm item (teal)
   - `#win` → logs an achievement (gold)
   - `#save` → appends bullet to all tagged Master Docs (blue)
   - `#resource` → creates a resource item (blue)
   - `#delete` → deletes items matching that bullet (grey, struck-through)
4. **Review** — Hit "Analyze with AI" for the ambiguous bullets. AI proposes items, suggests tags.
5. **Master Docs** — Build persistent knowledge documents per topic. Drag bullets in, AI sorts them into sections.

---

## Features

### Daily Dump (Home)
- Freeform daily notepad — editor grows smoothly as you type
- Auto-bullet formatting (type `*` or press Enter for new bullet)
- Magic tags fire on **Enter** — all tags on the line are read before creating items, so `#action #prio` always produces a high-priority item
- Magic tags render in color inline as you type (green, orange, teal, gold, grey)
- `#delete` tag deletes matching items (line shows struck-through red italic)
- `#save` appends bullet to the tagged Master Doc **and** auto-opens that doc's panel; sibling tags on the same bullet appear as pill switchers in the panel header
- Processed bullets marked `[acknowledged]` to prevent duplicates
- Adding a `#tag` to any bullet at any time registers it immediately
- **Tag autocomplete**: start typing `#partial` and a suggestion strip appears above the editor — Tab accepts the first suggestion, click any pill to insert
- Attention bar showing ALL high-priority + overdue items (always expanded)
- Tag pills bar (toggle with `# Filter`) with search, merge, sub-tag creation, and inline rename (double-click)
- Drag any tag pill onto another to merge them — updates everywhere
- "Analyze with AI" for batch extraction of items
- Past days expandable with per-day AI analysis
- Double-click bullets in tag search to edit inline

### Items View
- Filter tabs: All / Actions / Brainstorms / Resources
- "Group by tag" toggle — items organized under their tag headers (high-prio always at top)
- Collapse/Expand All button + click each tag header to collapse individually
- Tag groups stay in stable order when completing items (no reshuffling)
- "High prio" filter toggle
- "Completed" toggle
- "New" section at top — recently created items float above everything regardless of filters
- Clickable due dates with calendar popover (add or change dates inline)
- Priority indicators
- All preferences persist across restarts
- Editing an item with #tags auto-strips tags from title and creates tag associations

### Tags
- Primary organizational unit (replaces clusters)
- Hierarchical: parent tags with sub-tags always visible below them
- Created automatically from `#hashtags` in your dumps
- Double-click to rename — updates everywhere (dumps, docs, items, relationships)
- Rename to an existing tag → they merge automatically
- Right-click any tag anywhere in the app → **Open Master Doc** (slides in a panel from the right)
- Right-click → **Delete Tag** to remove it
- Drag tags onto each other → choose **Make sub-tag** or **Merge** from the dialog
- Click the expand chevron → see inline bullets and items for that tag without leaving the view
- Click a tag → see its items + Master Doc side-by-side
- Dragging shows a visual preview of the item or tag being moved

### Master Docs
- Per-topic persistent documents tied to tags
- Header shows the parent tag + all sub-tags at a glance
- **Rich text editor** with full keyboard support:
  - `Cmd+B` / `Cmd+I` / `Cmd+U` → bold / italic / underline (works on selection OR toggles typing mode for next input)
  - `Cmd+Shift+X` → strikethrough (same)
  - `Tab` / `Shift-Tab` → indent / outdent bullets
  - `Enter` continues the current list type (bullet, numbered, checklist)
- Formatting toolbar: Bold, Italic, Underline, Strikethrough, Bullet, Numbered list, Checklist, Heading menu (H1/H2/H3), font size
- AI-powered drag-to-insert: drop bullets or items, AI places them in the right section
- Drag items from Items view → AI sorts + marks item as "incorporated" (shaded, bottom)
- Empty doc prompt: "Create sections from AI?" vs "Just append as list?"
- **AI Synthesize**: gathers all bullets tagged with this tag OR any of its sub-tags, restructures into clean doc
- Synthesize preview with Accept/Dismiss before committing
- Editable title field
- Sub-tag settings (gear icon)
- Accessible from right-click on any tag, tag detail view, or Docs sidebar tab

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

### One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/inaayat/dumpster/main/install.sh | bash
```

This clones the repo, builds a release binary, installs to `/Applications/Dumpster.app`, and opens the app.

### Manual

```bash
git clone https://github.com/inaayat/dumpster.git ~/dumpster
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
open "$APP"
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
