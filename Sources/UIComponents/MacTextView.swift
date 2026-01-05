#if os(macOS)

import AppKit
import SwiftUI

struct MacTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange

    var fontSize: CGFloat
    var highlightCurrentLine: Bool

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacTextView
        var isProgrammaticChange = false
        private var lastHighlightedRange: NSRange?

        init(_ parent: MacTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if isProgrammaticChange { return }
            // Avoid breaking IME (e.g. Chinese Pinyin) composition. While there is marked text,
            // syncing through SwiftUI can trigger a programmatic re-apply that cancels composition.
            if textView.hasMarkedText() { return }
            if parent.text != textView.string {
                parent.text = textView.string
            }

            updateCurrentLineHighlightIfNeeded(textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if isProgrammaticChange { return }
            if textView.hasMarkedText() { return }
            let range = textView.selectedRange()
            if parent.selection != range {
                parent.selection = range
            }

            updateCurrentLineHighlightIfNeeded(textView)
        }

        func updateCurrentLineHighlightIfNeeded(_ textView: NSTextView) {
            guard let layoutManager = textView.layoutManager else { return }

            if let lastHighlightedRange {
                layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: lastHighlightedRange)
                self.lastHighlightedRange = nil
            }

            guard parent.highlightCurrentLine else { return }

            let nsText = textView.string as NSString
            guard nsText.length > 0 else { return }

            let selectionLocation = textView.selectedRange().location
            let safeLocation: Int
            if selectionLocation == NSNotFound {
                safeLocation = 0
            } else if selectionLocation >= nsText.length {
                safeLocation = max(0, nsText.length - 1)
            } else {
                safeLocation = max(0, selectionLocation)
            }

            let lineRange = nsText.lineRange(for: NSRange(location: safeLocation, length: 0))
            let color = NSColor.controlAccentColor.withAlphaComponent(0.12)
            layoutManager.addTemporaryAttribute(.backgroundColor, value: color, forCharacterRange: lineRange)
            lastHighlightedRange = lineRange
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = true
        textView.allowsUndo = true
        textView.usesFindPanel = true
        textView.isIncrementalSearchingEnabled = true
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.delegate = context.coordinator
        textView.string = text
        textView.setSelectedRange(selection)

        context.coordinator.updateCurrentLineHighlightIfNeeded(textView)

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        context.coordinator.parent = self

        if textView.font?.pointSize != fontSize {
            textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        }

        // While composing (IME marked text), do not re-apply string/selection programmatically.
        // Re-applying during composition commonly cancels Chinese/Japanese input.
        if textView.hasMarkedText() {
            return
        }

        if textView.string != text {
            context.coordinator.isProgrammaticChange = true
            textView.string = text
            context.coordinator.isProgrammaticChange = false
        }

        if textView.selectedRange() != selection {
            context.coordinator.isProgrammaticChange = true
            textView.setSelectedRange(selection)
            context.coordinator.isProgrammaticChange = false
        }

        context.coordinator.updateCurrentLineHighlightIfNeeded(textView)
    }
}

#endif
