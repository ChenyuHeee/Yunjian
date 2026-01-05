import SwiftUI
import YunjianCore

public struct DocumentAttributesView: View {
    private let document: Document

    public init(document: Document) {
        self.document = document
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("view.documentAttributes"))
                .font(.title2)
                .bold()

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                row(L10n.text("doc.attr.title"), value: displayTitle)
                row(L10n.text("doc.attr.location"), value: displayLocation)
                row(L10n.text("doc.attr.createdAt"), value: formatDate(document.createdAt))
                row(L10n.text("doc.attr.updatedAt"), value: formatDate(document.updatedAt))
                row(L10n.text("doc.attr.characters"), value: "\(characterCount)")
                row(L10n.text("doc.attr.words"), value: "\(wordCount)")
                row(L10n.text("doc.attr.lines"), value: "\(lineCount)")
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 320)
    }

    private var displayTitle: String {
        document.title.isEmpty ? L10n.text("library.untitled") : document.title
    }

    private var displayLocation: String {
        guard let url = document.fileURL else { return L10n.text("doc.attr.notSaved") }
        return url.path
    }

    private var characterCount: Int {
        document.body.count
    }

    private var wordCount: Int {
        document.body.split { $0.isWhitespace || $0.isNewline }.count
    }

    private var lineCount: Int {
        // Count lines including empty trailing line if present.
        if document.body.isEmpty { return 0 }
        return document.body.split(separator: "\n", omittingEmptySubsequences: false).count
    }

    private func formatDate(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .medium)
    }

    @ViewBuilder
    private func row(_ title: String, value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
    }
}
