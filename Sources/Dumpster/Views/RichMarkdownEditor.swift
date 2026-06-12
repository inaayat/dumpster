import SwiftUI
import AppKit

// MARK: - Public API

struct RichMarkdownEditorWithHandle: View {
    @Binding var markdown: String
    @ObservedObject var handle: RichMarkdownEditorHandle
    var fontSize: CGFloat = 13

    var body: some View {
        RichMarkdownEditorView(markdown: $markdown, handle: handle, fontSize: fontSize)
    }
}

class RichMarkdownEditorHandle: ObservableObject {
    weak var coordinator: RichMarkdownEditorCoordinator?

    func toggleBold() { coordinator?.toggleBold() }
    func toggleItalic() { coordinator?.toggleItalic() }
    func toggleHeading(level: Int = 2) { coordinator?.toggleHeading(level: level) }
    func toggleBullet() { coordinator?.toggleBullet() }
}

// MARK: - NSViewRepresentable

private struct RichMarkdownEditorView: NSViewRepresentable {
    @Binding var markdown: String
    @ObservedObject var handle: RichMarkdownEditorHandle
    var fontSize: CGFloat

    func makeCoordinator() -> RichMarkdownEditorCoordinator {
        let coord = RichMarkdownEditorCoordinator(markdown: $markdown, fontSize: fontSize)
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

// MARK: - Coordinator

class RichMarkdownEditorCoordinator: NSObject, NSTextViewDelegate {
    var markdown: Binding<String>
    weak var textView: NSTextView?
    var isInternalEdit = false
    var lastMarkdown = ""
    var fontSize: CGFloat

    init(markdown: Binding<String>, fontSize: CGFloat) {
        self.markdown = markdown
        self.fontSize = fontSize
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

        let safeRange = NSRange(location: min(selectedRange.location, attrStr.length), length: 0)
        textView.setSelectedRange(safeRange)
        isInternalEdit = false
    }

    private func markdownToAttributed(_ md: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = md.components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            result.append(styledLine(line))
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

        if line.hasPrefix("## ") {
            return styledText(String(line.dropFirst(3)), font: h2Font, indent: 0, bullet: nil, blockType: .heading2)
        }
        if line.hasPrefix("### ") {
            return styledText(String(line.dropFirst(4)), font: h3Font, indent: 0, bullet: nil, blockType: .heading3)
        }

        // Nested bullets
        let nestedPatterns = ["      - ", "      * ", "      • ",
                              "    - ", "    * ", "    • ",
                              "  - ", "  * ", "  • ",
                              "\t\t- ", "\t\t* ", "\t\t• ",
                              "\t- ", "\t* ", "\t• "]
        for pattern in nestedPatterns {
            if line.hasPrefix(pattern) {
                let text = String(line.dropFirst(pattern.count))
                let level = indentLevel(of: line)
                return styledText(text, font: bodyFont, indent: level, bullet: "◦", blockType: .bullet(level: level))
            }
        }

        // Top-level bullet
        for pattern in ["- ", "* ", "• "] {
            if line.hasPrefix(pattern) {
                let text = String(line.dropFirst(pattern.count))
                return styledText(text, font: bodyFont, indent: 1, bullet: "•", blockType: .bullet(level: 1))
            }
        }

        // Arrow bullet (AI-inserted)
        if line.hasPrefix("→ ") {
            return styledText(String(line.dropFirst(2)), font: bodyFont, indent: 1, bullet: "→", blockType: .bullet(level: 1))
        }

        return styledText(line, font: bodyFont, indent: 0, bullet: nil, blockType: .paragraph)
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

    private func styledText(_ text: String, font: NSFont, indent: Int, bullet: String?, blockType: MarkdownBlockType) -> NSAttributedString {
        let para = NSMutableParagraphStyle()
        let indentPts: CGFloat = CGFloat(indent) * 20.0

        if let bullet {
            para.headIndent = indentPts + 20
            para.firstLineHeadIndent = indentPts
            para.paragraphSpacingBefore = 2
            para.tabStops = [NSTextTab(textAlignment: .left, location: indentPts + 20)]

            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: para,
                .markdownBlockType: blockType
            ]
            let result = NSMutableAttributedString(string: "\(bullet)\t", attributes: attrs)
            result.append(applyInlineFormatting(text, baseFont: font, paragraphStyle: para, blockType: blockType))
            return result
        } else {
            para.headIndent = 0
            para.firstLineHeadIndent = 0
            if font.pointSize > fontSize {
                para.paragraphSpacingBefore = 8
                para.paragraphSpacing = 4
            }
            return applyInlineFormatting(text, baseFont: font, paragraphStyle: para, blockType: blockType)
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

        // Parse bold (**) and italic (*) markers
        let segments = parseInlineMarkers(text)
        for seg in segments {
            var attrs = baseAttrs
            var font = baseFont
            if seg.bold {
                font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
                attrs[.markdownInlineBold] = true
            }
            if seg.italic {
                font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                attrs[.markdownInlineItalic] = true
            }
            attrs[.font] = font
            result.append(NSAttributedString(string: seg.text, attributes: attrs))
        }
        return result
    }

    private struct InlineSegment {
        let text: String
        let bold: Bool
        let italic: Bool
    }

    private func parseInlineMarkers(_ text: String) -> [InlineSegment] {
        var segments: [InlineSegment] = []
        var remaining = text[text.startIndex...]

        while !remaining.isEmpty {
            // Bold: **text**
            if remaining.hasPrefix("**") {
                let after = remaining[remaining.index(remaining.startIndex, offsetBy: 2)...]
                if let end = after.range(of: "**") {
                    let boldText = String(after[after.startIndex..<end.lowerBound])
                    segments.append(InlineSegment(text: boldText, bold: true, italic: false))
                    remaining = after[end.upperBound...]
                    continue
                }
            }

            // Italic: *text* (single asterisk, not followed by another *)
            if remaining.hasPrefix("*") && !remaining.hasPrefix("**") {
                let after = remaining[remaining.index(after: remaining.startIndex)...]
                if let end = after.range(of: "*") {
                    let italicText = String(after[after.startIndex..<end.lowerBound])
                    if !italicText.isEmpty && !italicText.contains("\n") {
                        segments.append(InlineSegment(text: italicText, bold: false, italic: true))
                        remaining = after[end.upperBound...]
                        continue
                    }
                }
            }

            // Plain text until next marker
            var plainEnd = remaining.index(after: remaining.startIndex)
            while plainEnd < remaining.endIndex {
                let rest = remaining[plainEnd...]
                if rest.hasPrefix("**") || (rest.hasPrefix("*") && !rest.hasPrefix("**")) {
                    break
                }
                plainEnd = remaining.index(after: plainEnd)
            }
            let plain = String(remaining[remaining.startIndex..<plainEnd])
            segments.append(InlineSegment(text: plain, bold: false, italic: false))
            remaining = remaining[plainEnd...]
        }

        return segments
    }

    // MARK: - Attributed String → Markdown

    func attributedToMarkdown(_ attrStr: NSAttributedString) -> String {
        var lines: [String] = []
        let paragraphs = attrStr.string.components(separatedBy: "\n")

        var charIndex = 0
        for para in paragraphs {
            let paraRange = NSRange(location: charIndex, length: para.utf16.count)
            lines.append(attributedLineToMarkdown(attrStr, range: paraRange))
            charIndex += para.utf16.count + 1
        }
        return lines.joined(separator: "\n")
    }

    private func attributedLineToMarkdown(_ attrStr: NSAttributedString, range: NSRange) -> String {
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

        let contentText = extractContent(from: attrStr, range: safeRange, blockType: blockType)

        switch blockType {
        case .heading2: return "## \(contentText)"
        case .heading3: return "### \(contentText)"
        case .bullet(let level):
            let indent = String(repeating: "  ", count: max(0, level - 1))
            return "\(indent)- \(contentText)"
        case .paragraph: return contentText
        }
    }

    private func extractContent(from attrStr: NSAttributedString, range: NSRange, blockType: MarkdownBlockType) -> String {
        let text = (attrStr.string as NSString).substring(with: range)

        var charOffset = 0
        if case .bullet = blockType {
            for prefix in ["•\t", "◦\t", "→\t"] {
                if text.hasPrefix(prefix) {
                    charOffset = prefix.utf16.count
                    break
                }
            }
        }

        let contentRange = NSRange(location: range.location + charOffset, length: range.length - charOffset)
        guard contentRange.length > 0 && contentRange.location + contentRange.length <= attrStr.length else {
            // Fallback: strip bullet prefix manually
            var clean = text
            for prefix in ["•\t", "◦\t", "→\t"] {
                if clean.hasPrefix(prefix) { clean = String(clean.dropFirst(prefix.count)); break }
            }
            return clean
        }

        var result = ""
        attrStr.enumerateAttributes(in: contentRange) { attrs, segRange, _ in
            let segText = (attrStr.string as NSString).substring(with: segRange)
            let isBold = (attrs[.markdownInlineBold] as? Bool) == true
            let isItalic = (attrs[.markdownInlineItalic] as? Bool) == true

            if isBold {
                result += "**\(segText)**"
            } else if isItalic {
                result += "*\(segText)*"
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
        markdown.wrappedValue = md
        isInternalEdit = false
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertTab(_:)) {
            indentCurrentLine(textView, increase: true)
            return true
        }
        if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
            indentCurrentLine(textView, increase: false)
            return true
        }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            return handleNewline(textView)
        }
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

        let lineText = (storage.string as NSString).substring(with: lineRange).trimmingCharacters(in: .newlines)
        let isEmpty = ["•\t", "◦\t", "→\t"].contains(where: { lineText == $0 || lineText.trimmingCharacters(in: .whitespaces) == String($0.first!) })

        if isEmpty {
            isInternalEdit = true
            storage.replaceCharacters(in: lineRange, with: "\n")
            textView.setSelectedRange(NSRange(location: lineRange.location + 1, length: 0))
            let md = attributedToMarkdown(textView.attributedString())
            lastMarkdown = md
            markdown.wrappedValue = md
            isInternalEdit = false
            return true
        }

        let bulletChar = level > 1 ? "◦" : "•"
        let newBullet = "\n\(bulletChar)\t"

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
        storage.insert(NSAttributedString(string: newBullet, attributes: attrs), at: cursorLoc)
        textView.setSelectedRange(NSRange(location: cursorLoc + newBullet.utf16.count, length: 0))

        let md = attributedToMarkdown(textView.attributedString())
        lastMarkdown = md
        markdown.wrappedValue = md
        isInternalEdit = false
        return true
    }

    private func handleDeleteAtBulletStart(_ textView: NSTextView) -> Bool {
        let storage = textView.textStorage!
        let cursorLoc = textView.selectedRange().location
        let lineRange = (storage.string as NSString).lineRange(for: NSRange(location: cursorLoc, length: 0))
        let lineText = (storage.string as NSString).substring(with: lineRange)

        for prefix in ["•\t", "◦\t", "→\t"] {
            if lineText.hasPrefix(prefix) && cursorLoc == lineRange.location + prefix.utf16.count {
                isInternalEdit = true
                let prefixRange = NSRange(location: lineRange.location, length: prefix.utf16.count)
                storage.replaceCharacters(in: prefixRange, with: "")
                let newLineRange = NSRange(location: lineRange.location, length: max(0, lineRange.length - prefix.utf16.count - 1))
                if newLineRange.length > 0 {
                    storage.removeAttribute(.markdownBlockType, range: newLineRange)
                    storage.addAttribute(.paragraphStyle, value: NSMutableParagraphStyle(), range: newLineRange)
                }
                textView.setSelectedRange(NSRange(location: lineRange.location, length: 0))
                let md = attributedToMarkdown(textView.attributedString())
                lastMarkdown = md
                markdown.wrappedValue = md
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
        let lineIndex = beforeCursor.components(separatedBy: "\n").count - 1

        guard lineIndex < lines.count else { isInternalEdit = false; return }
        let line = lines[lineIndex]

        let bulletRegex = try? NSRegularExpression(pattern: "^(\\s*)([-*•])\\s")
        if let match = bulletRegex?.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) {
            let indentRange = Range(match.range(at: 1), in: line)!
            let spaces = String(line[indentRange]).count
            if increase {
                lines[lineIndex] = "  " + line
            } else if spaces >= 2 {
                lines[lineIndex] = String(line.dropFirst(2))
            }
        } else if ["- ", "* ", "• "].contains(where: { line.hasPrefix($0) }) && increase {
            lines[lineIndex] = "  " + line
        } else {
            isInternalEdit = false
            return
        }

        let newMd = lines.joined(separator: "\n")
        lastMarkdown = newMd
        markdown.wrappedValue = newMd
        loadMarkdown(newMd)
        isInternalEdit = false
    }

    // MARK: - Toolbar Actions

    func toggleBold() {
        guard let textView else { return }
        let range = textView.selectedRange()
        guard range.length > 0 else { return }

        isInternalEdit = true
        let md = attributedToMarkdown(textView.attributedString())
        var lines = md.components(separatedBy: "\n")

        let selectedText = (textView.textStorage!.string as NSString).substring(with: range)
        let beforeSelection = (textView.textStorage!.string as NSString).substring(to: range.location)
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
        markdown.wrappedValue = newMd
        loadMarkdown(newMd)
        isInternalEdit = false
    }

    func toggleItalic() {
        guard let textView else { return }
        let range = textView.selectedRange()
        guard range.length > 0 else { return }

        isInternalEdit = true
        let md = attributedToMarkdown(textView.attributedString())
        var lines = md.components(separatedBy: "\n")

        let selectedText = (textView.textStorage!.string as NSString).substring(with: range)
        let beforeSelection = (textView.textStorage!.string as NSString).substring(to: range.location)
        let lineIndex = beforeSelection.components(separatedBy: "\n").count - 1

        if lineIndex < lines.count {
            let line = lines[lineIndex]
            if line.contains("*\(selectedText)*") && !line.contains("**\(selectedText)**") {
                lines[lineIndex] = line.replacingOccurrences(of: "*\(selectedText)*", with: selectedText)
            } else if let textRange = line.range(of: selectedText) {
                lines[lineIndex] = line.replacingCharacters(in: textRange, with: "*\(selectedText)*")
            }
        }

        let newMd = lines.joined(separator: "\n")
        lastMarkdown = newMd
        markdown.wrappedValue = newMd
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
            for bp in ["- ", "* ", "• ", "  - ", "  * ", "  • "] {
                if line.hasPrefix(bp) { line = String(line.dropFirst(bp.count)); break }
            }
            line = prefix + line
        }

        lines[lineIndex] = line
        let newMd = lines.joined(separator: "\n")
        lastMarkdown = newMd
        markdown.wrappedValue = newMd
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
        markdown.wrappedValue = newMd
        loadMarkdown(newMd)
        isInternalEdit = false
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
    static let markdownInlineItalic = NSAttributedString.Key("markdownInlineItalic")
}
