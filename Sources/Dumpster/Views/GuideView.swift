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

                // Workflow
                guideSection("Your Workflow", icon: "arrow.right.circle.fill") {
                    step("1", "Dump", "Open the app → type freely in the Daily Dump. Each line is a bullet.")
                    step("2", "Tag", "Add #hashtags inline to organize by topic. Tags become your projects.")
                    step("3", "Magic Tags", "Use special tags to instantly create items on Enter (see below).")
                    step("4", "Review", "Hit 'Analyze with AI' for ambiguous bullets — AI proposes items and tags.")
                    step("5", "Build Knowledge", "Click a tag → open Master Doc → drag bullets in. AI organizes them.")
                }

                // Magic Tags
                guideSection("Magic Tags", icon: "wand.and.stars") {
                    magicRow("#action", "Creates an action item (task to do)", Theme.successColor)
                    magicRow("#prio", "Makes it high priority (combine with #action, or use alone)", .red)
                    magicRow("#brainstorm", "Creates a brainstorm item (idea to explore)", Theme.brainstormColor)
                    magicRow("#win", "Logs an achievement to your Wins", Theme.warnColor)
                    magicRow("#save", "Appends the bullet to all tagged Master Docs", Theme.accent)
                    magicRow("#resource", "Creates a resource item (link/reference)", Theme.resourceColor)
                    magicRow("#delete", "Deletes items matching that bullet's text", .gray)

                    tip("Magic tags are processed instantly when you type a space after the tag — no need to press Enter")
                    tip("Processed bullets get marked [acknowledged] to prevent duplicates")
                    tip("Magic tags render in color inline as you type")

                    Text("Example: • follow up with Sarah about budget #finance #action #prio")
                        .font(.inter(11))
                        .foregroundStyle(Theme.textMuted)
                        .padding(.top, 4)
                    Text("→ Creates a HIGH PRIORITY action \"follow up with Sarah about budget\" tagged with #finance")
                        .font(.inter(11))
                        .foregroundStyle(Theme.accent)
                }

                // Tags & Master Docs
                guideSection("Tags & Master Docs", icon: "number") {
                    tip("Tags are created automatically from your #hashtags — no setup needed")
                    tip("Adding a #tag to any bullet at any time registers it immediately")
                    tip("Double-click a tag pill to rename it — updates everywhere (dumps, docs, items)")
                    tip("Click a tag in the Dump view to see all its bullets across all days")
                    tip("Click 'Master Doc' to open the doc panel alongside the bullets")
                    tip("Drag bullets into the doc — AI places them in the right section")
                    tip("Items view: drag item cards into the Master Doc panel to incorporate them")
                    tip("Incorporated items get shaded and move to the bottom of the list")
                    tip("Master Doc has rich text: headings, bullets, indentation (Tab/Shift-Tab)")
                    tip("Sub-tags: drag one tag onto another → choose 'Make sub-tag'")
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
                    tip("Ctrl+Option+N → floating panel to quick-add a bullet from anywhere")
                    tip("Menu bar trash icon → Add Note / Open Dumpster")
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
}
