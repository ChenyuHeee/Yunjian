import Foundation
import Observation
import YunjianCore

@MainActor
@Observable
public final class EditorViewModel {
    public private(set) var document: Document
    public var isDirty: Bool = false

    public var selection: TextSelection = .empty

    private let storage: StorageServiceProtocol
    private let sync: SyncEngineProtocol?

    public init(document: Document, storage: StorageServiceProtocol, sync: SyncEngineProtocol?) {
        self.document = document
        self.storage = storage
        self.sync = sync
    }

    public func updateBody(_ body: String) {
        guard body != document.body else { return }
        document.body = body
        document.updatedAt = Date()
        isDirty = true
    }

    public func updateSelection(location: Int, length: Int) {
        selection = TextSelection(location: location, length: length)
    }

    public func replaceSelection(with replacement: String) {
        let current = document.body
        let nsRange = NSRange(location: selection.location, length: selection.length)
        guard let range = Range(nsRange, in: current) else { return }
        let updated = current.replacingCharacters(in: range, with: replacement)
        updateBody(updated)
        let newLocation = selection.location + (replacement as NSString).length
        updateSelection(location: newLocation, length: 0)
    }

    public func wrapSelection(prefix: String, suffix: String) {
        let current = document.body
        let nsRange = NSRange(location: selection.location, length: selection.length)
        guard let range = Range(nsRange, in: current) else { return }
        let selectedText = String(current[range])
        let replacement = prefix + selectedText + suffix
        let updated = current.replacingCharacters(in: range, with: replacement)
        updateBody(updated)
        updateSelection(location: selection.location + (prefix as NSString).length, length: (selectedText as NSString).length)
    }

    public func updateTitle(_ title: String) {
        guard title != document.title else { return }
        document.title = title
        document.updatedAt = Date()
        isDirty = true
    }

    public func save() async throws {
        guard isDirty else { return }
        try await storage.upsertDocument(document)
        isDirty = false
        await sync?.requestSync(reason: "local-save")
    }

    public func markSaved(fileURL: URL? = nil) {
        if let fileURL {
            document.fileURL = fileURL
        }
        isDirty = false
    }

    public func selectedTextOrEmpty() -> String {
        let current = document.body
        let nsRange = NSRange(location: selection.location, length: selection.length)
        guard let range = Range(nsRange, in: current) else { return "" }
        return String(current[range])
    }

    public func selectedTextOrAll() -> String {
        let selected = selectedTextOrEmpty()
        return selected.isEmpty ? document.body : selected
    }

    public func prefixLines(_ prefix: String) {
        let current = document.body
        let nsRange = NSRange(location: selection.location, length: selection.length)
        guard let range = Range(nsRange, in: current) else {
            // no valid selection; prefix current line
            applyToCurrentLine { line in prefix + line }
            return
        }

        let selectedText = String(current[range])
        let lines = selectedText.split(separator: "\n", omittingEmptySubsequences: false)
        let updatedLines = lines.map { prefix + $0 }
        replaceSelection(with: updatedLines.joined(separator: "\n"))
    }

    public func indentLines(by spaces: Int) {
        prefixLines(String(repeating: " ", count: spaces))
    }

    public func outdentLines(by spaces: Int) {
        let current = document.body
        let nsRange = NSRange(location: selection.location, length: selection.length)
        guard let range = Range(nsRange, in: current) else {
            applyToCurrentLine { line in
                String(line.drop(while: { $0 == " " }).dropFirst(min(spaces, line.prefix { $0 == " " }.count)))
            }
            return
        }

        let selectedText = String(current[range])
        let lines = selectedText.split(separator: "\n", omittingEmptySubsequences: false)
        let updatedLines = lines.map { line -> String in
            var s = String(line)
            var removed = 0
            while removed < spaces, s.hasPrefix(" ") {
                s.removeFirst()
                removed += 1
            }
            return s
        }
        replaceSelection(with: updatedLines.joined(separator: "\n"))
    }

    public func applyHeading(level: Int) {
        let prefix = String(repeating: "#", count: max(1, min(level, 6))) + " "
        applyToCurrentLine { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let withoutHashes = trimmed.replacingOccurrences(of: "^#{1,6}\\s+", with: "", options: .regularExpression)
            return prefix + withoutHashes
        }
    }

    private func applyToCurrentLine(_ transform: (String) -> String) {
        let current = document.body as NSString
        let loc = max(0, min(selection.location, current.length))

        let lineRange = current.lineRange(for: NSRange(location: loc, length: 0))
        let line = current.substring(with: lineRange)
        let newLine = transform(line)
        let updated = current.replacingCharacters(in: lineRange, with: newLine)
        updateBody(updated)
        updateSelection(location: lineRange.location + (newLine as NSString).length, length: 0)
    }
}
