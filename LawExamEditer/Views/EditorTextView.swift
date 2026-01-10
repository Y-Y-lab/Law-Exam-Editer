import SwiftUI

struct EditorTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var findQuery: String
    @Binding var findStatusMessage: String?
    let findAction: FindAction?
    let onTextChange: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.allowsUndo = true
        textView.delegate = context.coordinator

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        textView.backgroundColor = NSColor.textBackgroundColor
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        context.coordinator.updateFind(query: findQuery)
        if let action = findAction, action.id != context.coordinator.lastActionID {
            context.coordinator.handleAction(action)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private let parent: EditorTextView
        private var matchRanges: [NSRange] = []
        private var currentMatchIndex = 0
        var lastActionID: UUID?

        init(_ parent: EditorTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.onTextChange()
            updateFind(query: parent.findQuery)
        }

        func updateFind(query: String) {
            guard let textView = currentTextView else { return }
            clearHighlights(in: textView)
            guard !query.isEmpty else {
                parent.findStatusMessage = nil
                return
            }
            matchRanges = ranges(for: query, in: textView.string)
            if matchRanges.isEmpty {
                parent.findStatusMessage = "No matches"
            } else {
                parent.findStatusMessage = nil
                currentMatchIndex = min(currentMatchIndex, matchRanges.count - 1)
                highlightMatch(at: currentMatchIndex, in: textView)
            }
        }

        func handleAction(_ action: FindAction) {
            guard let textView = currentTextView else { return }
            lastActionID = action.id
            switch action.type {
            case .next:
                selectNextMatch(in: textView)
            case .previous:
                selectPreviousMatch(in: textView)
            case .close:
                clearHighlights(in: textView)
            }
        }

        private var currentTextView: NSTextView? {
            NSApp.keyWindow?.firstResponder as? NSTextView
        }

        private func ranges(for query: String, in text: String) -> [NSRange] {
            guard !query.isEmpty else { return [] }
            var ranges: [NSRange] = []
            let nsText = text as NSString
            var searchRange = NSRange(location: 0, length: nsText.length)
            while true {
                let foundRange = nsText.range(of: query, options: .caseInsensitive, range: searchRange)
                if foundRange.location == NSNotFound { break }
                ranges.append(foundRange)
                let nextLocation = foundRange.location + foundRange.length
                searchRange = NSRange(location: nextLocation, length: nsText.length - nextLocation)
            }
            return ranges
        }

        private func clearHighlights(in textView: NSTextView) {
            let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
            textView.textStorage?.removeAttribute(.backgroundColor, range: fullRange)
        }

        private func selectNextMatch(in textView: NSTextView) {
            guard !matchRanges.isEmpty else { return }
            currentMatchIndex = (currentMatchIndex + 1) % matchRanges.count
            highlightMatch(at: currentMatchIndex, in: textView)
        }

        private func selectPreviousMatch(in textView: NSTextView) {
            guard !matchRanges.isEmpty else { return }
            currentMatchIndex = (currentMatchIndex - 1 + matchRanges.count) % matchRanges.count
            highlightMatch(at: currentMatchIndex, in: textView)
        }

        private func highlightMatch(at index: Int, in textView: NSTextView) {
            clearHighlights(in: textView)
            guard index >= 0, index < matchRanges.count else { return }
            let range = matchRanges[index]
            textView.textStorage?.addAttribute(.backgroundColor, value: NSColor.systemYellow, range: range)
            textView.scrollRangeToVisible(range)
            textView.setSelectedRange(range)
        }
    }
}

