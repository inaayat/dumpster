import SwiftUI
import AppKit

struct DumpTextEditor: NSViewRepresentable {
    @Binding var text: String
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
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.font = NSFont(name: "Inter", size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
        textView.typingAttributes = [
            .font: NSFont(name: "Inter", size: fontSize) ?? NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: NSColor.labelColor
        ]

        // Line spacing
        let para = NSMutableParagraphStyle()
        para.lineSpacing = 4
        textView.defaultParagraphStyle = para

        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        context.coordinator.applyColoring(text)

        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let coord = context.coordinator
        guard !coord.isInternalEdit else { return }

        if text != coord.lastText {
            coord.applyColoring(text)
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: DumpTextEditor
        weak var textView: NSTextView?
        var isInternalEdit = false
        var lastText = ""

        init(_ parent: DumpTextEditor) {
            self.parent = parent
            super.init()
        }

        func applyColoring(_ text: String) {
            guard let textView else { return }
            isInternalEdit = true
            lastText = text

            let selectedRange = textView.selectedRange()

            let font = NSFont(name: "Inter", size: parent.fontSize) ?? NSFont.systemFont(ofSize: parent.fontSize)
            let para = NSMutableParagraphStyle()
            para.lineSpacing = 4

            let baseAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: para
            ]

            let attrStr = NSMutableAttributedString(string: text, attributes: baseAttrs)

            // Color magic tags
            colorHashtags(in: attrStr, font: font, paragraphStyle: para)

            // Style #delete lines
            styleDeleteLines(in: attrStr, font: font, paragraphStyle: para)

            // Style [retired] markers
            styleRetiredMarkers(in: attrStr)

            textView.textStorage?.setAttributedString(attrStr)
            let safeRange = NSRange(location: min(selectedRange.location, attrStr.length), length: 0)
            textView.setSelectedRange(safeRange)

            isInternalEdit = false
        }

        private func colorHashtags(in attrStr: NSMutableAttributedString, font: NSFont, paragraphStyle: NSParagraphStyle) {
            let text = attrStr.string
            let pattern = #"#([\w\-]+)"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: text.utf16.count))

            for match in matches {
                let tagRange = match.range
                let tagNameRange = match.range(at: 1)
                guard let nameRange = Range(tagNameRange, in: text) else { continue }
                let tagName = String(text[nameRange]).lowercased()

                let color: NSColor
                switch tagName {
                case "action": color = NSColor(Theme.successColor)
                case "prio": color = NSColor(Theme.warnColor)
                case "brainstorm": color = NSColor(Theme.brainstormColor)
                case "win": color = NSColor(Theme.warnColor).withAlphaComponent(0.8)
                case "save": color = NSColor(Theme.accent)
                case "delete": color = NSColor.systemGray
                case "resource": color = NSColor(Theme.accent)
                default: color = NSColor.systemBlue
                }

                attrStr.addAttribute(.foregroundColor, value: color, range: tagRange)
                let boldFont = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
                attrStr.addAttribute(.font, value: boldFont, range: tagRange)
            }
        }

        private func styleDeleteLines(in attrStr: NSMutableAttributedString, font: NSFont, paragraphStyle: NSParagraphStyle) {
            let text = attrStr.string
            let lines = text.components(separatedBy: "\n")
            var charOffset = 0

            for line in lines {
                let lineRange = NSRange(location: charOffset, length: line.utf16.count)
                if line.lowercased().contains("#delete") && !line.contains(DumpBullet.retiredMarker) {
                    // Strikethrough + red italic for the whole line
                    let italicFont = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                    attrStr.addAttribute(.font, value: italicFont, range: lineRange)
                    attrStr.addAttribute(.foregroundColor, value: NSColor.systemRed.withAlphaComponent(0.7), range: lineRange)
                    attrStr.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: lineRange)
                }
                charOffset += line.utf16.count + 1 // +1 for newline
            }
        }

        private func styleRetiredMarkers(in attrStr: NSMutableAttributedString) {
            let text = attrStr.string
            let marker = DumpBullet.retiredMarker
            var searchRange = text.startIndex..<text.endIndex
            while let range = text.range(of: marker, range: searchRange) {
                let nsRange = NSRange(range, in: text)
                attrStr.addAttribute(.foregroundColor, value: NSColor.systemGray.withAlphaComponent(0.4), range: nsRange)
                attrStr.addAttribute(.font, value: NSFont.systemFont(ofSize: parent.fontSize - 2), range: nsRange)
                searchRange = range.upperBound..<text.endIndex
            }
        }

        // MARK: - NSTextViewDelegate

        func textDidChange(_ notification: Notification) {
            guard !isInternalEdit, let textView else { return }
            isInternalEdit = true
            let newText = textView.string
            lastText = newText
            parent.text = newText

            // Re-apply coloring without resetting cursor
            let selectedRange = textView.selectedRange()
            let font = NSFont(name: "Inter", size: parent.fontSize) ?? NSFont.systemFont(ofSize: parent.fontSize)
            let para = NSMutableParagraphStyle()
            para.lineSpacing = 4

            let baseAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: para
            ]

            let attrStr = NSMutableAttributedString(string: newText, attributes: baseAttrs)
            colorHashtags(in: attrStr, font: font, paragraphStyle: para)
            styleDeleteLines(in: attrStr, font: font, paragraphStyle: para)
            styleRetiredMarkers(in: attrStr)

            textView.textStorage?.setAttributedString(attrStr)
            let safeRange = NSRange(location: min(selectedRange.location, attrStr.length), length: 0)
            textView.setSelectedRange(safeRange)

            isInternalEdit = false
        }
    }
}
