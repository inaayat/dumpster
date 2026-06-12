import SwiftUI
import AppKit

struct RichMarkdownEditor: NSViewRepresentable {
    @Binding var markdown: String
    var fontSize: CGFloat = 13

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.isRichText = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.usesFindPanel = true
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.font = NSFont.systemFont(ofSize: fontSize)

        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        context.coordinator.loadMarkdown(markdown)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard nsView.documentView is NSTextView else { return }
        let coord = context.coordinator

        if coord.fontSize != fontSize {
            coord.fontSize = fontSize
            coord.loadMarkdown(markdown)
        }

        if !coord.isInternalEdit && markdown != coord.lastMarkdown {
            coord.loadMarkdown(markdown)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichMarkdownEditor
        weak var textView: NSTextView?
        var isInternalEdit = false
        var lastMarkdown = ""
        var fontSize: CGFloat

        init(_ parent: RichMarkdownEditor) {
            self.parent = parent
            self.fontSize = parent.fontSize
            super.init()
        }

        // MARK: - Markdown → Attributed String

        func loadMarkdown(_ md: String) {
            guard let textView else { return }
            lastMarkdown = md
            isInternalEdit = true

            let selectedRange = textView.selectedRange()
            let attrStr = markdownToAttributed(md)
            textView.textStorage?.setAttributedString(attrStr)

            let safeRange = NSRange(
                location: min(selectedRange.location, attrStr.length),
                length: 0
            )
            textView.setSelectedRange(safeRange)

            isInternalEdit = false
        }

        func markdownToAttributed(_ md: String) -> NSAttributedString {
            let result = NSMutableAttributedString()
            let lines = md.components(separatedBy: "\n")

            for (index, line) in lines.enumerated() {
                let attrLine = styledLine(line)
                result.append(attrLine)
                if index < lines.count - 1 {
                    result.append(NSAttributedString(string: "\n"))
                }
            }

            return result
        }

        private func styledLine(_ line: String) -> NSAttributedString {
            let bodyFont = NSFont.systemFont(ofSize: fontSize)
            let h2Font = NSFont.boldSystemFont(ofSize: fontSize + 5)
            let h3Font = NSFont.boldSystemFont(ofSize: fontSize + 2)

            // Heading 2
            if line.hasPrefix("## ") {
                let text = String(line.dropFirst(3))
                return styledText(text, font: h2Font, indent: 0, bullet: nil)
            }

            // Heading 3
            if line.hasPrefix("### ") {
                let text = String(line.dropFirst(4))
                return styledText(text, font: h3Font, indent: 0, bullet: nil)
            }

            // Nested bullet (4 spaces or tab + marker)
            let nestedPatterns = ["      - ", "      * ", "      • ",
                                  "    - ", "    * ", "    • ",
                                  "  - ", "  * ", "  • ",
                                  "\t\t- ", "\t\t* ", "\t\t• ",
                                  "\t- ", "\t* ", "\t• "]
            for pattern in nestedPatterns {
                if line.hasPrefix(pattern) {
                    let text = String(line.dropFirst(pattern.count))
                    let level = indentLevel(of: line)
                    return styledText(text, font: bodyFont, indent: level, bullet: "◦")
                }
            }

            // Top-level bullet
            let bulletPatterns = ["- ", "* ", "• "]
            for pattern in bulletPatterns {
                if line.hasPrefix(pattern) {
                    let text = String(line.dropFirst(pattern.count))
                    return styledText(text, font: bodyFont, indent: 1, bullet: "•")
                }
            }

            // Arrow bullet (AI-inserted markers)
            if line.hasPrefix("→ ") {
                let text = String(line.dropFirst(2))
                return styledText(text, font: bodyFont, indent: 1, bullet: "→")
            }

            // Plain text
            return styledText(line, font: bodyFont, indent: 0, bullet: nil)
        }

        private func indentLevel(of line: String) -> Int {
            var spaces = 0
            for ch in line {
                if ch == " " { spaces += 1 }
                else if ch == "\t" { spaces += 2 }
                else { break }
            }
            return max(1, min(spaces / 2, 4))
        }

        private func styledText(_ text: String, font: NSFont, indent: Int, bullet: String?) -> NSAttributedString {
            let para = NSMutableParagraphStyle()
            let indentPts: CGFloat = CGFloat(indent) * 20.0

            if let bullet {
                para.headIndent = indentPts + 20
                para.firstLineHeadIndent = indentPts
                para.paragraphSpacingBefore = 2

                let tabStop = NSTextTab(textAlignment: .left, location: indentPts + 20)
                para.tabStops = [tabStop]

                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: para,
                    .markdownBlockType: MarkdownBlockType.bullet(level: indent)
                ]
                let result = NSMutableAttributedString(string: "\(bullet)\t", attributes: attrs)
                result.append(applyInlineFormatting(text, baseFont: font, paragraphStyle: para, blockType: .bullet(level: indent)))
                return result
            } else {
                para.headIndent = 0
                para.firstLineHeadIndent = 0
                if font.pointSize > fontSize {
                    para.paragraphSpacingBefore = 8
                    para.paragraphSpacing = 4
                }

                let blockType: MarkdownBlockType = font.pointSize >= fontSize + 5 ? .heading2 :
                                                   font.pointSize >= fontSize + 2 ? .heading3 : .paragraph
                let result = applyInlineFormatting(text, baseFont: font, paragraphStyle: para, blockType: blockType)
                return result
            }
        }

        private func applyInlineFormatting(_ text: String, baseFont: NSFont, paragraphStyle: NSParagraphStyle, blockType: MarkdownBlockType) -> NSAttributedString {
            let result = NSMutableAttributedString()
            let baseAttrs: [NSAttributedString.Key: Any] = [
                .font: baseFont,
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle,
                .markdownBlockType: blockType
            ]

            var remaining = text
            while let boldStart = remaining.range(of: "**") {
                let before = String(remaining[remaining.startIndex..<boldStart.lowerBound])
                if !before.isEmpty {
                    result.append(NSAttributedString(string: before, attributes: baseAttrs))
                }
                remaining = String(remaining[boldStart.upperBound...])
                if let boldEnd = remaining.range(of: "**") {
                    let boldText = String(remaining[remaining.startIndex..<boldEnd.lowerBound])
                    let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
                    var boldAttrs = baseAttrs
                    boldAttrs[.font] = boldFont
                    boldAttrs[.markdownInlineBold] = true
                    result.append(NSAttributedString(string: boldText, attributes: boldAttrs))
                    remaining = String(remaining[boldEnd.upperBound...])
                } else {
                    result.append(NSAttributedString(string: "**", attributes: baseAttrs))
                }
            }
            if !remaining.isEmpty {
                result.append(NSAttributedString(string: remaining, attributes: baseAttrs))
            }
            return result
        }

        // MARK: - Attributed String → Markdown

        func attributedToMarkdown(_ attrStr: NSAttributedString) -> String {
            var lines: [String] = []
            let fullString = attrStr.string
            let paragraphs = fullString.components(separatedBy: "\n")

            var charIndex = 0
            for para in paragraphs {
                let paraRange = NSRange(location: charIndex, length: para.utf16.count)
                let line = attributedLineToMarkdown(attrStr, range: paraRange, text: para)
                lines.append(line)
                charIndex += para.utf16.count + 1
            }

            return lines.joined(separator: "\n")
        }

        private func attributedLineToMarkdown(_ attrStr: NSAttributedString, range: NSRange, text: String) -> String {
            guard range.length > 0 else { return "" }

            let safeRange = NSRange(location: range.location, length: min(range.length, attrStr.length - range.location))
            guard safeRange.length > 0 else { return "" }

            var blockType: MarkdownBlockType = .paragraph
            attrStr.enumerateAttribute(.markdownBlockType, in: safeRange) { value, _, stop in
                if let type = value as? MarkdownBlockType {
                    blockType = type
                    stop.pointee = true
                }
            }

            let contentText = extractPlainContent(from: attrStr, range: safeRange, blockType: blockType)

            switch blockType {
            case .heading2:
                return "## \(contentText)"
            case .heading3:
                return "### \(contentText)"
            case .bullet(let level):
                let indent = String(repeating: "  ", count: max(0, level - 1))
                return "\(indent)- \(contentText)"
            case .paragraph:
                return contentText
            }
        }

        private func extractPlainContent(from attrStr: NSAttributedString, range: NSRange, blockType: MarkdownBlockType) -> String {
            var result = ""
            let text = (attrStr.string as NSString).substring(with: range)

            // Strip bullet character + tab prefix for bullet lines
            var cleanText = text
            if case .bullet = blockType {
                let bulletPrefixes = ["•\t", "◦\t", "→\t"]
                for prefix in bulletPrefixes {
                    if cleanText.hasPrefix(prefix) {
                        cleanText = String(cleanText.dropFirst(prefix.count))
                        break
                    }
                }
            }

            // Re-add bold markers around bold text
            var charOffset = 0
            if case .bullet = blockType {
                let bulletPrefixes = ["•\t", "◦\t", "→\t"]
                for prefix in bulletPrefixes {
                    if text.hasPrefix(prefix) {
                        charOffset = prefix.utf16.count
                        break
                    }
                }
            }

            let contentRange = NSRange(location: range.location + charOffset, length: range.length - charOffset)
            guard contentRange.length > 0 && contentRange.location + contentRange.length <= attrStr.length else {
                return cleanText
            }

            var segments: [(String, Bool)] = []
            attrStr.enumerateAttribute(.markdownInlineBold, in: contentRange) { value, segRange, _ in
                let segText = (attrStr.string as NSString).substring(with: segRange)
                let isBold = (value as? Bool) == true
                segments.append((segText, isBold))
            }

            if segments.isEmpty {
                return cleanText
            }

            result = ""
            for (segText, isBold) in segments {
                if isBold {
                    result += "**\(segText)**"
                } else {
                    result += segText
                }
            }
            return result
        }

        // MARK: - NSTextViewDelegate

        func textDidChange(_ notification: Notification) {
            guard !isInternalEdit, let textView else { return }
            isInternalEdit = true
            let md = attributedToMarkdown(textView.attributedString())
            lastMarkdown = md
            parent.markdown = md
            isInternalEdit = false
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Tab → indent
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                indentCurrentLine(textView, increase: true)
                return true
            }

            // Shift-Tab → outdent
            if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                indentCurrentLine(textView, increase: false)
                return true
            }

            // Enter → continue bullet
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                return handleNewline(textView)
            }

            // Delete at start of bullet → remove bullet
            if commandSelector == #selector(NSResponder.deleteBackward(_:)) {
                return handleDeleteAtBulletStart(textView)
            }

            return false
        }

        // MARK: - Keyboard Handlers

        private func handleNewline(_ textView: NSTextView) -> Bool {
            let storage = textView.textStorage!
            let cursorLoc = textView.selectedRange().location
            let lineRange = (storage.string as NSString).lineRange(for: NSRange(location: cursorLoc, length: 0))

            // Check if current line is a bullet
            var blockType: MarkdownBlockType = .paragraph
            if lineRange.length > 0 && lineRange.location < storage.length {
                storage.enumerateAttribute(.markdownBlockType, in: NSRange(location: lineRange.location, length: min(1, storage.length - lineRange.location))) { value, _, stop in
                    if let type = value as? MarkdownBlockType {
                        blockType = type
                        stop.pointee = true
                    }
                }
            }

            guard case .bullet(let level) = blockType else { return false }

            // Check if bullet is empty (just the bullet char + tab)
            let lineText = (storage.string as NSString).substring(with: lineRange).trimmingCharacters(in: .newlines)
            let bulletPrefixes = ["•\t", "◦\t", "→\t"]
            let isEmpty = bulletPrefixes.contains(where: { lineText == $0 || lineText.trimmingCharacters(in: .whitespaces) == String($0.first!) })

            if isEmpty {
                // Empty bullet → remove it and insert plain newline
                isInternalEdit = true
                storage.replaceCharacters(in: lineRange, with: "\n")
                textView.setSelectedRange(NSRange(location: lineRange.location + 1, length: 0))
                let md = attributedToMarkdown(textView.attributedString())
                lastMarkdown = md
                parent.markdown = md
                isInternalEdit = false
                return true
            }

            // Continue bullet
            let bulletChar = level > 1 ? "◦" : "•"
            let newBullet = "\n\(bulletChar)\t"
            let insertLoc = cursorLoc

            isInternalEdit = true

            let para = NSMutableParagraphStyle()
            let indentPts: CGFloat = CGFloat(level) * 20.0
            para.headIndent = indentPts + 20
            para.firstLineHeadIndent = indentPts
            para.paragraphSpacingBefore = 2
            para.tabStops = [NSTextTab(textAlignment: .left, location: indentPts + 20)]

            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: para,
                .markdownBlockType: MarkdownBlockType.bullet(level: level)
            ]
            let attrBullet = NSAttributedString(string: newBullet, attributes: attrs)
            storage.insert(attrBullet, at: insertLoc)
            textView.setSelectedRange(NSRange(location: insertLoc + newBullet.utf16.count, length: 0))

            let md = attributedToMarkdown(textView.attributedString())
            lastMarkdown = md
            parent.markdown = md
            isInternalEdit = false
            return true
        }

        private func handleDeleteAtBulletStart(_ textView: NSTextView) -> Bool {
            let storage = textView.textStorage!
            let cursorLoc = textView.selectedRange().location
            let lineRange = (storage.string as NSString).lineRange(for: NSRange(location: cursorLoc, length: 0))

            // Check if we're at the content start of a bullet (right after bullet+tab)
            let lineText = (storage.string as NSString).substring(with: lineRange)
            let bulletPrefixes = ["•\t", "◦\t", "→\t"]
            for prefix in bulletPrefixes {
                if lineText.hasPrefix(prefix) && cursorLoc == lineRange.location + prefix.utf16.count {
                    // Remove the bullet prefix
                    isInternalEdit = true
                    let prefixRange = NSRange(location: lineRange.location, length: prefix.utf16.count)
                    storage.replaceCharacters(in: prefixRange, with: "")

                    // Remove block type attribute from remaining line
                    let newLineRange = NSRange(location: lineRange.location, length: max(0, lineRange.length - prefix.utf16.count - 1))
                    if newLineRange.length > 0 {
                        storage.removeAttribute(.markdownBlockType, range: newLineRange)
                        let plainPara = NSMutableParagraphStyle()
                        storage.addAttribute(.paragraphStyle, value: plainPara, range: newLineRange)
                    }

                    textView.setSelectedRange(NSRange(location: lineRange.location, length: 0))
                    let md = attributedToMarkdown(textView.attributedString())
                    lastMarkdown = md
                    parent.markdown = md
                    isInternalEdit = false
                    return true
                }
            }
            return false
        }

        private func indentCurrentLine(_ textView: NSTextView, increase: Bool) {
            isInternalEdit = true
            let md = attributedToMarkdown(textView.attributedString())
            var lines = md.components(separatedBy: "\n")

            let cursorLoc = textView.selectedRange().location
            let beforeCursor = (textView.textStorage!.string as NSString).substring(to: cursorLoc)
            let currentLineIndex = beforeCursor.components(separatedBy: "\n").count - 1

            guard currentLineIndex < lines.count else { isInternalEdit = false; return }
            let line = lines[currentLineIndex]

            // Only indent/outdent bullet lines
            let bulletPatterns = ["- ", "* ", "• "]
            let indentedBulletRegex = try? NSRegularExpression(pattern: "^(\\s*)([-*•])\\s")

            if let match = indentedBulletRegex?.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) {
                let indentRange = Range(match.range(at: 1), in: line)!
                let currentIndent = String(line[indentRange])
                let spaces = currentIndent.count

                if increase {
                    lines[currentLineIndex] = "  " + line
                } else if spaces >= 2 {
                    lines[currentLineIndex] = String(line.dropFirst(2))
                }
            } else if bulletPatterns.contains(where: { line.hasPrefix($0) }) && increase {
                lines[currentLineIndex] = "  " + line
            } else if !increase && line.hasPrefix("  ") {
                lines[currentLineIndex] = String(line.dropFirst(2))
            } else {
                isInternalEdit = false
                return
            }

            let newMd = lines.joined(separator: "\n")
            lastMarkdown = newMd
            parent.markdown = newMd
            loadMarkdown(newMd)
            isInternalEdit = false
        }

        // MARK: - Public Formatting Methods

        func toggleBold() {
            guard let textView else { return }
            let range = textView.selectedRange()
            guard range.length > 0 else { return }

            isInternalEdit = true
            let md = attributedToMarkdown(textView.attributedString())
            var lines = md.components(separatedBy: "\n")

            // Simple approach: toggle ** around selection in markdown
            let selectedText = (textView.textStorage!.string as NSString).substring(with: range)

            // Find the text in the current markdown and wrap/unwrap
            let fullText = textView.textStorage!.string
            let beforeSelection = (fullText as NSString).substring(to: range.location)
            let lineIndex = beforeSelection.components(separatedBy: "\n").count - 1

            if lineIndex < lines.count {
                let line = lines[lineIndex]
                if line.contains("**\(selectedText)**") {
                    lines[lineIndex] = line.replacingOccurrences(of: "**\(selectedText)**", with: selectedText)
                } else if let textRange = line.range(of: selectedText) {
                    lines[lineIndex] = line.replacingCharacters(in: textRange, with: "**\(selectedText)**")
                }
            }

            let newMd = lines.joined(separator: "\n")
            lastMarkdown = newMd
            parent.markdown = newMd
            loadMarkdown(newMd)
            isInternalEdit = false
        }

        func toggleHeading(level: Int) {
            guard let textView else { return }
            isInternalEdit = true
            let md = attributedToMarkdown(textView.attributedString())
            var lines = md.components(separatedBy: "\n")

            let cursorLoc = textView.selectedRange().location
            let beforeCursor = (textView.textStorage!.string as NSString).substring(to: cursorLoc)
            let lineIndex = beforeCursor.components(separatedBy: "\n").count - 1

            guard lineIndex < lines.count else { isInternalEdit = false; return }
            var line = lines[lineIndex]

            let prefix = level == 2 ? "## " : "### "
            let otherPrefix = level == 2 ? "### " : "## "

            if line.hasPrefix(prefix) {
                line = String(line.dropFirst(prefix.count))
            } else if line.hasPrefix(otherPrefix) {
                line = prefix + String(line.dropFirst(otherPrefix.count))
            } else {
                // Strip bullet prefix if present
                let bulletPrefixes = ["- ", "* ", "• ", "  - ", "  * ", "  • "]
                for bp in bulletPrefixes {
                    if line.hasPrefix(bp) { line = String(line.dropFirst(bp.count)); break }
                }
                line = prefix + line
            }

            lines[lineIndex] = line
            let newMd = lines.joined(separator: "\n")
            lastMarkdown = newMd
            parent.markdown = newMd
            loadMarkdown(newMd)
            isInternalEdit = false
        }

        func toggleBullet() {
            guard let textView else { return }
            isInternalEdit = true
            let md = attributedToMarkdown(textView.attributedString())
            var lines = md.components(separatedBy: "\n")

            let cursorLoc = textView.selectedRange().location
            let beforeCursor = (textView.textStorage!.string as NSString).substring(to: cursorLoc)
            let lineIndex = beforeCursor.components(separatedBy: "\n").count - 1

            guard lineIndex < lines.count else { isInternalEdit = false; return }
            var line = lines[lineIndex]

            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
                line = String(line.dropFirst(2))
            } else if line.hasPrefix("## ") || line.hasPrefix("### ") {
                let headingPrefix = line.hasPrefix("## ") ? "## " : "### "
                line = "- " + String(line.dropFirst(headingPrefix.count))
            } else {
                line = "- " + line
            }

            lines[lineIndex] = line
            let newMd = lines.joined(separator: "\n")
            lastMarkdown = newMd
            parent.markdown = newMd
            loadMarkdown(newMd)
            isInternalEdit = false
        }
    }
}

// MARK: - Custom Attributed String Keys

enum MarkdownBlockType: Hashable {
    case heading2
    case heading3
    case bullet(level: Int)
    case paragraph
}

extension NSAttributedString.Key {
    static let markdownBlockType = NSAttributedString.Key("markdownBlockType")
    static let markdownInlineBold = NSAttributedString.Key("markdownInlineBold")
}

// MARK: - Editor Handle (for toolbar actions)

class RichMarkdownEditorHandle: ObservableObject {
    weak var coordinator: RichMarkdownEditor.Coordinator?

    func toggleBold() { coordinator?.toggleBold() }
    func toggleHeading(level: Int = 2) { coordinator?.toggleHeading(level: level) }
    func toggleBullet() { coordinator?.toggleBullet() }
}

struct RichMarkdownEditorWithHandle: View {
    @Binding var markdown: String
    @ObservedObject var handle: RichMarkdownEditorHandle
    var fontSize: CGFloat = 13

    var body: some View {
        RichMarkdownEditorInner(markdown: $markdown, handle: handle, fontSize: fontSize)
    }
}

private struct RichMarkdownEditorInner: NSViewRepresentable {
    @Binding var markdown: String
    @ObservedObject var handle: RichMarkdownEditorHandle
    var fontSize: CGFloat

    func makeCoordinator() -> RichMarkdownEditor.Coordinator {
        let editor = RichMarkdownEditor(markdown: $markdown, fontSize: fontSize)
        let coord = RichMarkdownEditor.Coordinator(editor)
        handle.coordinator = coord
        return coord
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.isRichText = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.usesFindPanel = true
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.font = NSFont.systemFont(ofSize: fontSize)

        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        context.coordinator.loadMarkdown(markdown)

        handle.coordinator = context.coordinator

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let coord = context.coordinator

        if coord.fontSize != fontSize {
            coord.fontSize = fontSize
            coord.loadMarkdown(markdown)
        }

        if !coord.isInternalEdit && markdown != coord.lastMarkdown {
            coord.loadMarkdown(markdown)
        }

        handle.coordinator = context.coordinator
    }
}
