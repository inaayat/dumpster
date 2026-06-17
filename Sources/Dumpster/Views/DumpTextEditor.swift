import SwiftUI
import AppKit

class DumpEditorHandle: ObservableObject {
    weak var coordinator: DumpTextEditor.Coordinator?

    func insertCompletion(partial: String, full: String) {
        coordinator?.insertCompletion(partial: partial, full: full)
    }
}

final class GrowingNSTextView: NSTextView {
    override var intrinsicContentSize: NSSize {
        guard let lm = layoutManager, let tc = textContainer else { return super.intrinsicContentSize }
        lm.ensureLayout(for: tc)
        let h = lm.usedRect(for: tc).height + textContainerInset.height * 2
        return NSSize(width: NSView.noIntrinsicMetric, height: h)
    }

    override func didChangeText() {
        super.didChangeText()
        invalidateIntrinsicContentSize()
    }
}

struct DumpTextEditor: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat = 13
    var focusOnAppear: Bool = false
    var handle: DumpEditorHandle? = nil
    var onHeightChange: ((CGFloat) -> Void)? = nil
    var onPartialTag: ((String?) -> Void)? = nil
    var onTabPress: (() -> Bool)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> GrowingNSTextView {
        let tv = GrowingNSTextView()

        tv.isRichText = true
        tv.allowsUndo = true
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.textContainerInset = NSSize(width: 8, height: 8)
        tv.backgroundColor = .clear
        tv.drawsBackground = false

        let font = NSFont(name: "Inter", size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
        tv.font = font
        tv.typingAttributes = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]

        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        let para = NSMutableParagraphStyle()
        para.lineSpacing = 4
        tv.defaultParagraphStyle = para

        tv.delegate = context.coordinator
        context.coordinator.textView = tv
        handle?.coordinator = context.coordinator
        context.coordinator.applyColoring(text)

        return tv
    }

    func updateNSView(_ nsView: GrowingNSTextView, context: Context) {
        let coord = context.coordinator
        coord.parent = self
        guard !coord.isInternalEdit else { return }

        if text != coord.lastText {
            coord.applyColoring(text)
            if text.hasSuffix("• "), let tv = coord.textView {
                let len = tv.textStorage?.length ?? 0
                tv.setSelectedRange(NSRange(location: len, length: 0))
            }
        }

        if focusOnAppear && !coord.hasFocused && !text.isEmpty {
            coord.hasFocused = true
            nsView.window?.makeFirstResponder(nsView)
            let len = nsView.textStorage?.length ?? 0
            nsView.setSelectedRange(NSRange(location: len, length: 0))
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: DumpTextEditor
        weak var textView: GrowingNSTextView?
        var isInternalEdit = false
        var lastText = ""
        var hasFocused = false

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
            colorHashtags(in: attrStr, font: font, paragraphStyle: para)
            styleDeleteLines(in: attrStr, font: font, paragraphStyle: para)

            textView.textStorage?.setAttributedString(attrStr)
            let safeRange = NSRange(location: min(selectedRange.location, attrStr.length), length: 0)
            textView.setSelectedRange(safeRange)

            isInternalEdit = false
            emitHeight()
        }

        private func emitHeight() {
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      let tv = self.textView,
                      let lm = tv.layoutManager,
                      let tc = tv.textContainer else { return }
                lm.ensureLayout(for: tc)
                let h = lm.usedRect(for: tc).height + tv.textContainerInset.height * 2
                self.parent.onHeightChange?(h)
            }
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
                case "backlog": color = NSColor.systemGray.withAlphaComponent(0.8)
                default: color = NSColor(red: 0.15, green: 0.3, blue: 0.65, alpha: 1.0)
                }

                attrStr.addAttribute(.foregroundColor, value: color, range: tagRange)
                let isMagicTag = ["action", "prio", "brainstorm", "win", "save", "delete", "resource", "backlog"].contains(tagName)
                if isMagicTag {
                    let boldFont = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
                    attrStr.addAttribute(.font, value: boldFont, range: tagRange)
                }
            }
        }

        private func styleDeleteLines(in attrStr: NSMutableAttributedString, font: NSFont, paragraphStyle: NSParagraphStyle) {
            let text = attrStr.string
            let lines = text.components(separatedBy: "\n")
            var charOffset = 0

            for line in lines {
                let lineRange = NSRange(location: charOffset, length: line.utf16.count)
                if line.lowercased().contains("#delete") {
                    let italicFont = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                    attrStr.addAttribute(.font, value: italicFont, range: lineRange)
                    attrStr.addAttribute(.foregroundColor, value: NSColor.systemRed.withAlphaComponent(0.7), range: lineRange)
                    attrStr.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: lineRange)
                }
                charOffset += line.utf16.count + 1
            }
        }

        // MARK: - Autocomplete

        func insertCompletion(partial: String, full: String) {
            guard let textView else { return }
            let text = textView.string
            let cursorLoc = textView.selectedRange().location
            guard cursorLoc <= text.utf16.count else { return }
            let utf16End = text.utf16.index(text.utf16.startIndex, offsetBy: cursorLoc)
            guard let strEnd = utf16End.samePosition(in: text) else { return }
            let prefix = String(text[..<strEnd])
            guard let matchRange = prefix.range(of: "#\(partial)", options: [.backwards, .caseInsensitive]) else { return }
            let nsRange = NSRange(matchRange, in: prefix)
            let replacement = "#\(full) "

            isInternalEdit = true
            textView.textStorage?.replaceCharacters(in: nsRange, with: replacement)
            let newCursorLoc = nsRange.location + replacement.utf16.count
            let newText = textView.string
            lastText = newText
            parent.text = newText

            let font = NSFont(name: "Inter", size: parent.fontSize) ?? NSFont.systemFont(ofSize: parent.fontSize)
            let para = NSMutableParagraphStyle()
            para.lineSpacing = 4
            let baseAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor, .paragraphStyle: para]
            let attrStr = NSMutableAttributedString(string: newText, attributes: baseAttrs)
            colorHashtags(in: attrStr, font: font, paragraphStyle: para)
            styleDeleteLines(in: attrStr, font: font, paragraphStyle: para)
            textView.textStorage?.setAttributedString(attrStr)
            textView.setSelectedRange(NSRange(location: min(newCursorLoc, newText.utf16.count), length: 0))
            isInternalEdit = false

            parent.onPartialTag?(nil)
        }

        private func extractPartialTag(_ text: String, cursorAt utf16Loc: Int) -> String? {
            guard utf16Loc > 0, utf16Loc <= text.utf16.count else { return nil }
            let utf16End = text.utf16.index(text.utf16.startIndex, offsetBy: utf16Loc)
            guard let strEnd = utf16End.samePosition(in: text) else { return nil }
            let prefix = String(text[..<strEnd])
            guard let matchRange = prefix.range(of: #"#([\w\-]+)$"#, options: .regularExpression) else { return nil }
            let partial = String(prefix[matchRange].dropFirst())
            return partial.isEmpty ? nil : partial
        }

        // MARK: - NSTextViewDelegate

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                if parent.onTabPress?() == true { return true }
            }
            return false
        }

        func textDidBeginEditing(_ notification: Notification) {
            guard let textView, textView.string.isEmpty else { return }
            isInternalEdit = true
            textView.string = "• "
            lastText = "• "
            parent.text = "• "
            applyColoring("• ")
            textView.setSelectedRange(NSRange(location: 2, length: 0))
            isInternalEdit = false
        }

        func textDidChange(_ notification: Notification) {
            guard !isInternalEdit, let textView else { return }
            isInternalEdit = true
            let newText = textView.string
            lastText = newText
            parent.text = newText

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
            textView.textStorage?.setAttributedString(attrStr)
            let safeRange = NSRange(location: min(selectedRange.location, attrStr.length), length: 0)
            textView.setSelectedRange(safeRange)

            isInternalEdit = false
            emitHeight()

            let partial = extractPartialTag(newText, cursorAt: selectedRange.location)
            parent.onPartialTag?(partial)
        }
    }
}
