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
    func toggleUnderline() { coordinator?.toggleUnderline() }
    func toggleStrikethrough() { coordinator?.toggleStrikethrough() }
    func toggleHeading(level: Int = 2) { coordinator?.toggleHeading(level: level) }
    func toggleBullet() { coordinator?.toggleBullet() }
    func toggleNumberedList() { coordinator?.toggleNumberedList() }
    func toggleChecklist() { coordinator?.toggleChecklist() }
    func handleTab(increase: Bool) { coordinator?.handleTab(increase: increase) }
}

// MARK: - Custom NSTextView for Keyboard Shortcuts

private final class FormattingTextView: NSTextView {
    weak var formattingDelegate: RichMarkdownEditorCoordinator?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if flags.contains(.command) {
            let chars = event.charactersIgnoringModifiers ?? ""

            if flags.contains(.shift) && (chars == "x" || chars == "X") {
                formattingDelegate?.toggleStrikethrough()
                return true
            }

            switch chars {
            case "b":
                formattingDelegate?.toggleBold()
                return true
            case "i":
                formattingDelegate?.toggleItalic()
                return true
            case "u":
                formattingDelegate?.toggleUnderline()
                return true
            default:
                break
            }
        }

        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Handle Tab/Shift-Tab before calling super so SwiftUI focus navigation doesn't eat it
        if event.keyCode == 48 {
            if flags.contains(.shift) {
                formattingDelegate?.handleTab(increase: false)
            } else {
                formattingDelegate?.handleTab(increase: true)
            }
            return
        }

        if flags.contains(.command) {
            let chars = event.charactersIgnoringModifiers ?? ""
            switch chars {
            case "b":
                formattingDelegate?.toggleBold()
                return
            case "i":
                formattingDelegate?.toggleItalic()
                return
            case "u":
                formattingDelegate?.toggleUnderline()
                return
            default:
                break
            }
        }
        super.keyDown(with: event)
    }
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
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false

        let textView = FormattingTextView()
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
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        textView.delegate = context.coordinator
        textView.formattingDelegate = context.coordinator
        context.coordinator.textView = textView
        context.coordinator.loadMarkdown(markdown)
        handle.coordinator = context.coordinator

        scrollView.documentView = textView
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
        let h1Font = NSFont.boldSystemFont(ofSize: fontSize + 8)
        let h2Font = NSFont.boldSystemFont(ofSize: fontSize + 5)
        let h3Font = NSFont.boldSystemFont(ofSize: fontSize + 2)

        if line.hasPrefix("# ") && !line.hasPrefix("## ") {
            return styledText(String(line.dropFirst(2)), font: h1Font, indent: 0, bullet: nil, blockType: .heading1)
        }
        if line.hasPrefix("## ") {
            return styledText(String(line.dropFirst(3)), font: h2Font, indent: 0, bullet: nil, blockType: .heading2)
        }
        if line.hasPrefix("### ") {
            return styledText(String(line.dropFirst(4)), font: h3Font, indent: 0, bullet: nil, blockType: .heading3)
        }

        // Checklist items
        let checklistPatterns: [(String, Bool, Int)] = [
            ("      - [x] ", true, 3), ("      - [ ] ", false, 3),
            ("    - [x] ", true, 2), ("    - [ ] ", false, 2),
            ("  - [x] ", true, 1), ("  - [ ] ", false, 1),
            ("- [x] ", true, 0), ("- [ ] ", false, 0),
        ]
        for (pattern, checked, indentLvl) in checklistPatterns {
            if line.hasPrefix(pattern) {
                let text = String(line.dropFirst(pattern.count))
                let level = indentLvl + 1
                let checkChar = checked ? "☑" : "☐"
                return styledText(text, font: bodyFont, indent: level, bullet: checkChar, blockType: .checklist(level: level, checked: checked))
            }
        }

        // Numbered list
        let numberedRegex = try? NSRegularExpression(pattern: "^(\\s*)(\\d+)\\.\\s")
        if let match = numberedRegex?.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) {
            let indentRange = Range(match.range(at: 1), in: line)!
            let numRange = Range(match.range(at: 2), in: line)!
            let spaces = String(line[indentRange]).count
            let num = String(line[numRange])
            let level = max(1, spaces / 2 + 1)
            let text = String(line[line.index(line.startIndex, offsetBy: match.range.length)...])
            return styledText(text, font: bodyFont, indent: level, bullet: "\(num).", blockType: .numbered(level: level, num: Int(num) ?? 1))
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
        // 0 spaces → level 1, 2 spaces → level 2, 4 spaces → level 3, etc.
        return min(spaces / 2 + 1, 4)
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
            if seg.underline {
                attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
                attrs[.markdownInlineUnderline] = true
            }
            if seg.strikethrough {
                attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                attrs[.markdownInlineStrikethrough] = true
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
        let underline: Bool
        let strikethrough: Bool
    }

    private func parseInlineMarkers(_ text: String) -> [InlineSegment] {
        var segments: [InlineSegment] = []
        var remaining = text[text.startIndex...]

        while !remaining.isEmpty {
            // Strikethrough: ~~text~~
            if remaining.hasPrefix("~~") {
                let after = remaining[remaining.index(remaining.startIndex, offsetBy: 2)...]
                if let end = after.range(of: "~~") {
                    let stText = String(after[after.startIndex..<end.lowerBound])
                    segments.append(InlineSegment(text: stText, bold: false, italic: false, underline: false, strikethrough: true))
                    remaining = after[end.upperBound...]
                    continue
                }
            }

            // Bold: **text**
            if remaining.hasPrefix("**") {
                let after = remaining[remaining.index(remaining.startIndex, offsetBy: 2)...]
                if let end = after.range(of: "**") {
                    let boldText = String(after[after.startIndex..<end.lowerBound])
                    segments.append(InlineSegment(text: boldText, bold: true, italic: false, underline: false, strikethrough: false))
                    remaining = after[end.upperBound...]
                    continue
                }
            }

            // Underline: __text__
            if remaining.hasPrefix("__") {
                let after = remaining[remaining.index(remaining.startIndex, offsetBy: 2)...]
                if let end = after.range(of: "__") {
                    let ulText = String(after[after.startIndex..<end.lowerBound])
                    segments.append(InlineSegment(text: ulText, bold: false, italic: false, underline: true, strikethrough: false))
                    remaining = after[end.upperBound...]
                    continue
                }
            }

            // Italic: *text*
            if remaining.hasPrefix("*") && !remaining.hasPrefix("**") {
                let after = remaining[remaining.index(after: remaining.startIndex)...]
                if let end = after.range(of: "*") {
                    let italicText = String(after[after.startIndex..<end.lowerBound])
                    if !italicText.isEmpty && !italicText.contains("\n") {
                        segments.append(InlineSegment(text: italicText, bold: false, italic: true, underline: false, strikethrough: false))
                        remaining = after[end.upperBound...]
                        continue
                    }
                }
            }

            // Plain text until next marker
            var plainEnd = remaining.index(after: remaining.startIndex)
            while plainEnd < remaining.endIndex {
                let rest = remaining[plainEnd...]
                if rest.hasPrefix("~~") || rest.hasPrefix("**") || rest.hasPrefix("__") || (rest.hasPrefix("*") && !rest.hasPrefix("**")) {
                    break
                }
                plainEnd = remaining.index(after: plainEnd)
            }
            let plain = String(remaining[remaining.startIndex..<plainEnd])
            segments.append(InlineSegment(text: plain, bold: false, italic: false, underline: false, strikethrough: false))
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
        case .heading1: return "# \(contentText)"
        case .heading2: return "## \(contentText)"
        case .heading3: return "### \(contentText)"
        case .bullet(let level):
            let indent = String(repeating: "  ", count: max(0, level - 1))
            return "\(indent)- \(contentText)"
        case .numbered(let level, let num):
            let indent = String(repeating: "  ", count: max(0, level - 1))
            return "\(indent)\(num). \(contentText)"
        case .checklist(let level, let checked):
            let indent = String(repeating: "  ", count: max(0, level - 1))
            return "\(indent)- [\(checked ? "x" : " ")] \(contentText)"
        case .paragraph: return contentText
        }
    }

    private func extractContent(from attrStr: NSAttributedString, range: NSRange, blockType: MarkdownBlockType) -> String {
        let text = (attrStr.string as NSString).substring(with: range)

        var charOffset = 0
        switch blockType {
        case .bullet, .numbered, .checklist:
            for prefix in ["•\t", "◦\t", "→\t", "☑\t", "☐\t"] {
                if text.hasPrefix(prefix) {
                    charOffset = prefix.utf16.count
                    break
                }
            }
            if charOffset == 0 {
                // Numbered list: "1.\t" etc.
                let numRegex = try? NSRegularExpression(pattern: "^\\d+\\.\\t")
                if let match = numRegex?.firstMatch(in: text, range: NSRange(location: 0, length: text.utf16.count)) {
                    charOffset = match.range.length
                }
            }
        default:
            break
        }

        let contentRange = NSRange(location: range.location + charOffset, length: range.length - charOffset)
        guard contentRange.length > 0 && contentRange.location + contentRange.length <= attrStr.length else {
            var clean = text
            for prefix in ["•\t", "◦\t", "→\t", "☑\t", "☐\t"] {
                if clean.hasPrefix(prefix) { clean = String(clean.dropFirst(prefix.count)); break }
            }
            return clean
        }

        var result = ""
        attrStr.enumerateAttributes(in: contentRange) { attrs, segRange, _ in
            let segText = (attrStr.string as NSString).substring(with: segRange)
            let isBold = (attrs[.markdownInlineBold] as? Bool) == true
            let isItalic = (attrs[.markdownInlineItalic] as? Bool) == true
            let isUnderline = (attrs[.markdownInlineUnderline] as? Bool) == true
            let isStrikethrough = (attrs[.markdownInlineStrikethrough] as? Bool) == true

            if isBold {
                result += "**\(segText)**"
            } else if isItalic {
                result += "*\(segText)*"
            } else if isUnderline {
                result += "__\(segText)__"
            } else if isStrikethrough {
                result += "~~\(segText)~~"
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

        let lineText = (storage.string as NSString).substring(with: lineRange).trimmingCharacters(in: .newlines)

        switch blockType {
        case .bullet(let level):
            let isEmpty = ["•\t", "◦\t", "→\t"].contains(where: { lineText == $0 || lineText.trimmingCharacters(in: .whitespaces) == String($0.first!) })
            if isEmpty {
                return convertToPlainLine(textView, lineRange: lineRange)
            }
            let bulletChar = level > 1 ? "◦" : "•"
            return insertNewListItem(textView, at: cursorLoc, prefix: "\(bulletChar)\t", level: level, blockType: .bullet(level: level))

        case .numbered(let level, let num):
            let isEmpty = lineText.range(of: "^\\d+\\.\\t$", options: .regularExpression) != nil
            if isEmpty {
                return convertToPlainLine(textView, lineRange: lineRange)
            }
            let nextNum = num + 1
            return insertNewListItem(textView, at: cursorLoc, prefix: "\(nextNum).\t", level: level, blockType: .numbered(level: level, num: nextNum))

        case .checklist(let level, _):
            let isEmpty = ["☑\t", "☐\t"].contains(where: { lineText == $0 })
            if isEmpty {
                return convertToPlainLine(textView, lineRange: lineRange)
            }
            return insertNewListItem(textView, at: cursorLoc, prefix: "☐\t", level: level, blockType: .checklist(level: level, checked: false))

        default:
            return false
        }
    }

    private func convertToPlainLine(_ textView: NSTextView, lineRange: NSRange) -> Bool {
        let storage = textView.textStorage!
        isInternalEdit = true
        storage.replaceCharacters(in: lineRange, with: "\n")
        textView.setSelectedRange(NSRange(location: lineRange.location + 1, length: 0))
        let md = attributedToMarkdown(textView.attributedString())
        lastMarkdown = md
        markdown.wrappedValue = md
        isInternalEdit = false
        return true
    }

    private func insertNewListItem(_ textView: NSTextView, at cursorLoc: Int, prefix: String, level: Int, blockType: MarkdownBlockType) -> Bool {
        let storage = textView.textStorage!
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
            .markdownBlockType: blockType
        ]

        let newItem = "\n\(prefix)"
        storage.insert(NSAttributedString(string: newItem, attributes: attrs), at: cursorLoc)
        textView.setSelectedRange(NSRange(location: cursorLoc + newItem.utf16.count, length: 0))

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

        let prefixes = ["•\t", "◦\t", "→\t", "☑\t", "☐\t"]
        for prefix in prefixes {
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

        // Numbered list prefix: "1.\t"
        let numRegex = try? NSRegularExpression(pattern: "^\\d+\\.\\t")
        if let match = numRegex?.firstMatch(in: lineText, range: NSRange(location: 0, length: lineText.utf16.count)) {
            if cursorLoc == lineRange.location + match.range.length {
                isInternalEdit = true
                let prefixRange = NSRange(location: lineRange.location, length: match.range.length)
                storage.replaceCharacters(in: prefixRange, with: "")
                let newLineRange = NSRange(location: lineRange.location, length: max(0, lineRange.length - match.range.length - 1))
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

        let listRegex = try? NSRegularExpression(pattern: "^(\\s*)([-*•]|\\d+\\.|\\- \\[[x ]\\])\\s")
        if let match = listRegex?.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) {
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

    func handleTab(increase: Bool) {
        guard let textView else { return }
        indentCurrentLine(textView, increase: increase)
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

    func toggleUnderline() {
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
            if line.contains("__\(selectedText)__") {
                lines[lineIndex] = line.replacingOccurrences(of: "__\(selectedText)__", with: selectedText)
            } else if let textRange = line.range(of: selectedText) {
                lines[lineIndex] = line.replacingCharacters(in: textRange, with: "__\(selectedText)__")
            }
        }

        let newMd = lines.joined(separator: "\n")
        lastMarkdown = newMd
        markdown.wrappedValue = newMd
        loadMarkdown(newMd)
        isInternalEdit = false
    }

    func toggleStrikethrough() {
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
            if line.contains("~~\(selectedText)~~") {
                lines[lineIndex] = line.replacingOccurrences(of: "~~\(selectedText)~~", with: selectedText)
            } else if let textRange = line.range(of: selectedText) {
                lines[lineIndex] = line.replacingCharacters(in: textRange, with: "~~\(selectedText)~~")
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

        let prefix: String
        switch level {
        case 1: prefix = "# "
        case 3: prefix = "### "
        default: prefix = "## "
        }

        // Remove any existing heading prefix
        for hp in ["### ", "## ", "# "] {
            if line.hasPrefix(hp) {
                line = String(line.dropFirst(hp.count))
                if hp == prefix {
                    // Toggle off — already this heading level
                    lines[lineIndex] = line
                    let newMd = lines.joined(separator: "\n")
                    lastMarkdown = newMd
                    markdown.wrappedValue = newMd
                    loadMarkdown(newMd)
                    isInternalEdit = false
                    return
                }
                break
            }
        }

        // Strip bullet prefix if present
        for bp in ["- ", "* ", "• ", "  - ", "  * ", "  • "] {
            if line.hasPrefix(bp) { line = String(line.dropFirst(bp.count)); break }
        }

        lines[lineIndex] = prefix + line
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
        } else if line.hasPrefix("## ") || line.hasPrefix("### ") || line.hasPrefix("# ") {
            for hp in ["### ", "## ", "# "] {
                if line.hasPrefix(hp) { line = "- " + String(line.dropFirst(hp.count)); break }
            }
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

    func toggleNumberedList() {
        guard let textView else { return }
        isInternalEdit = true
        let md = attributedToMarkdown(textView.attributedString())
        var lines = md.components(separatedBy: "\n")

        let cursorLoc = textView.selectedRange().location
        let beforeCursor = (textView.textStorage!.string as NSString).substring(to: cursorLoc)
        let lineIndex = beforeCursor.components(separatedBy: "\n").count - 1

        guard lineIndex < lines.count else { isInternalEdit = false; return }
        var line = lines[lineIndex]

        // Already a numbered list item — toggle off
        let numRegex = try? NSRegularExpression(pattern: "^(\\s*)\\d+\\.\\s")
        if let match = numRegex?.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) {
            line = String(line[line.index(line.startIndex, offsetBy: match.range.length)...])
        } else {
            // Strip bullet if present
            for bp in ["- ", "* ", "• "] {
                if line.hasPrefix(bp) { line = String(line.dropFirst(bp.count)); break }
            }
            line = "1. " + line
        }

        lines[lineIndex] = line
        let newMd = lines.joined(separator: "\n")
        lastMarkdown = newMd
        markdown.wrappedValue = newMd
        loadMarkdown(newMd)
        isInternalEdit = false
    }

    func toggleChecklist() {
        guard let textView else { return }
        isInternalEdit = true
        let md = attributedToMarkdown(textView.attributedString())
        var lines = md.components(separatedBy: "\n")

        let cursorLoc = textView.selectedRange().location
        let beforeCursor = (textView.textStorage!.string as NSString).substring(to: cursorLoc)
        let lineIndex = beforeCursor.components(separatedBy: "\n").count - 1

        guard lineIndex < lines.count else { isInternalEdit = false; return }
        var line = lines[lineIndex]

        // Already a checklist item — toggle off
        let checkRegex = try? NSRegularExpression(pattern: "^(\\s*)- \\[[x ]\\] ")
        if let match = checkRegex?.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) {
            let indentRange = Range(match.range(at: 1), in: line)!
            let indent = String(line[indentRange])
            line = indent + String(line[line.index(line.startIndex, offsetBy: match.range.length)...])
        } else {
            // Strip bullet if present
            for bp in ["- ", "* ", "• "] {
                if line.hasPrefix(bp) { line = String(line.dropFirst(bp.count)); break }
            }
            line = "- [ ] " + line
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
    case heading1
    case heading2
    case heading3
    case bullet(level: Int)
    case numbered(level: Int, num: Int)
    case checklist(level: Int, checked: Bool)
    case paragraph
}

extension NSAttributedString.Key {
    static let markdownBlockType = NSAttributedString.Key("markdownBlockType")
    static let markdownInlineBold = NSAttributedString.Key("markdownInlineBold")
    static let markdownInlineItalic = NSAttributedString.Key("markdownInlineItalic")
    static let markdownInlineUnderline = NSAttributedString.Key("markdownInlineUnderline")
    static let markdownInlineStrikethrough = NSAttributedString.Key("markdownInlineStrikethrough")
}
