import SwiftUI

struct GuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dumpster")
                            .font(.inter(28, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Dump your thoughts. Let them sort themselves out.")
                            .font(.inter(13))
                            .foregroundStyle(Theme.textMuted)
                    }
                }

                Divider()

                // Visual Flow
                VStack(alignment: .leading, spacing: 12) {
                    Text("The Flow")
                        .font(.inter(16, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 0) {
                            flowCard(
                                icon: "square.and.pencil",
                                color: Theme.accent,
                                title: "Dump",
                                detail: "Open the app. Type one thought per bullet — no structure needed."
                            )
                            flowArrow()
                            flowCard(
                                icon: "number",
                                color: Color.blue.opacity(0.85),
                                title: "Tag",
                                detail: "Add #hashtags inline as you type. Tags auto-register — no setup."
                            )
                            flowArrow()
                            flowCard(
                                icon: "wand.and.stars",
                                color: Theme.successColor,
                                title: "Magic Tags",
                                detail: "Type #action #prio then press Enter → high-priority item created instantly."
                            )
                            flowArrow()
                            flowCard(
                                icon: "square.stack.fill",
                                color: Theme.brainstormColor,
                                title: "Triage",
                                detail: "Items land in Actions, Brainstorms, and Resources. Set due dates, mark done."
                            )
                            flowArrow()
                            flowCard(
                                icon: "doc.text.fill",
                                color: Theme.warnColor,
                                title: "Master Docs",
                                detail: "Right-click any tag → Open Master Doc. Drag bullets in — AI organizes them."
                            )
                            flowArrow()
                            flowCard(
                                icon: "sparkles",
                                color: Theme.accent,
                                title: "Synthesize",
                                detail: "Hit Synthesize to let AI rewrite the doc from all bullets with that tag."
                            )
                        }
                        .padding(.bottom, 4)
                    }

                    // Knowledge loop note
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.textMuted)
                        Text("The loop: every new bullet you tag feeds into that tag's Master Doc via Synthesize.")
                            .font(.inter(11))
                            .foregroundStyle(Theme.textMuted)
                    }
                    .padding(.top, 2)
                }

                // Magic Tags
                guideSection("Magic Tags", icon: "wand.and.stars") {
                    magicRow("#action", "Creates an action item (task to do)", Theme.successColor)
                    magicRow("#prio", "High priority — combine with #action, or use alone", .red)
                    magicRow("#brainstorm", "Creates a brainstorm item (idea to explore)", Theme.brainstormColor)
                    magicRow("#win", "Logs an achievement to your Wins", Theme.warnColor)
                    magicRow("#save", "Appends the bullet to all tagged Master Docs", Theme.accent)
                    magicRow("#resource", "Creates a resource item (link/reference)", Theme.resourceColor)
                    magicRow("#delete", "Deletes items matching that bullet's text", .gray)

                    tip("Magic tags fire when you press Enter — type all your tags first, then hit Enter")
                    tip("This means #action #prio together always creates a high-priority item correctly")
                    tip("Processed bullets get marked [acknowledged] to prevent duplicates")
                    tip("Magic tags render in color and bold inline as you type")
                    tip("Quick Dump panel (Ctrl+Option+N) also processes magic tags")

                    Text("Example: • follow up with Sarah about budget #finance #action #prio")
                        .font(.inter(11))
                        .foregroundStyle(Theme.textMuted)
                        .padding(.top, 4)
                    Text("→ Press Enter → HIGH PRIORITY action tagged #finance")
                        .font(.inter(11))
                        .foregroundStyle(Theme.accent)
                }

                // Tags & Master Docs
                guideSection("Tags & Master Docs", icon: "number") {
                    tip("Tags are created automatically from your #hashtags — no setup needed")
                    tip("Double-click a tag pill to rename it — updates everywhere (dumps, docs, items)")
                    tip("Rename a tag to one that already exists → they merge automatically")
                    tip("Right-click any tag anywhere in the app → 'Open Master Doc' slides in a panel")
                    tip("Right-click a tag → 'Delete Tag' to remove it")
                    tip("Master Doc header shows the tag + all its sub-tags at a glance")
                    tip("Drag bullets into the doc — AI places them in the right section")
                    tip("Items view: drag item cards into the Master Doc panel to incorporate them")
                    tip("Dragging shows a visual preview of what you're moving")
                    tip("Incorporated items get shaded and move to the bottom of the list")
                    tip("'Synthesize' gathers bullets from the tag AND all its sub-tags, then rewrites with AI")
                    tip("Sub-tags: drag one tag onto another in the Tags view to create a parent-child relationship")
                    tip("Tag merge: drag one tag pill onto another in the Dump view to merge them")
                }

                // Master Doc Rich Text
                guideSection("Master Doc Formatting", icon: "doc.richtext") {
                    tip("Cmd+B / Cmd+I / Cmd+U → bold / italic / underline selected text")
                    tip("Cmd+Shift+X → strikethrough selected text")
                    tip("Tab → indent a bullet one level deeper (Shift-Tab to outdent)")
                    tip("Enter continues the same list type (bullet, numbered, checklist)")
                    tip("Toolbar: bullet list, numbered list, checklist, headings (Title/Heading/Subheading)")
                    tip("Heading menu sets H1 / H2 / H3 — click again to toggle off")
                    tip("Font size A- / A+ in toolbar adjusts the whole document")
                }

                // Items View
                guideSection("Items View", icon: "square.stack.fill") {
                    tip("Filter by category: All / Actions / Brainstorms / Resources")
                    tip("'Group by tag' toggle organizes items under their tag headers")
                    tip("Collapse/Expand All button + click each tag header to toggle")
                    tip("Tag groups stay in place when you complete items — no shuffling")
                    tip("'High prio' toggle shows only urgent items")
                    tip("Click a due date badge to change it (or add one)")
                    tip("Newly created items float to the top for 5 minutes so you can triage")
                }

                // Keyboard & System
                guideSection("Keyboard & System", icon: "keyboard") {
                    tip("Ctrl+Option+N → floating Quick Dump panel to add a bullet from anywhere")
                    tip("Menu bar trash icon → Add Note / Open Dumpster / Export Data")
                    tip("Export Data exports all dumps as a Markdown file")
                    tip("Launches at login automatically")
                    tip("All data is local (SQLite) — nothing leaves your machine")
                    tip("AI is optional via Ollama — everything works without it")
                }

                // Bro Mode
                guideSection("Dark Mode", icon: "moon.fill") {
                    tip("Toggle 'lights off' at the bottom of the sidebar")
                    tip("Teal and orange glow against the dark background")
                }
            }
            .padding(32)
        }
        .background(Theme.canvas)
    }

    @ViewBuilder
    private func guideSection(_ title: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text(title)
                    .font(.inter(16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }
            content()
        }
    }

    private func step(_ number: String, _ title: String, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.inter(11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Theme.accent, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.inter(13, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                Text(desc).font(.inter(12)).foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func magicRow(_ tag: String, _ desc: String, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Text(tag)
                .font(.inter(11, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 90, alignment: .leading)
            Text(desc)
                .font(.inter(12))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 2)
    }

    private func tip(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.inter(12))
                .foregroundStyle(Theme.accent)
            Text(text)
                .font(.inter(12))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func flowCard(icon: String, color: Color, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(title)
                .font(.inter(13, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(detail)
                .font(.inter(11))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(2)
            Spacer(minLength: 0)
        }
        .frame(width: 148, height: 170, alignment: .top)
        .padding(14)
        .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .strokeBorder(Theme.cardBorder, lineWidth: 1)
        )
    }

    private func flowArrow() -> some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.textMuted.opacity(0.5))
            .frame(width: 24)
            .padding(.top, 30)
    }
}
