#if os(macOS)

import AppKit
import Foundation
import Markdown
import UniformTypeIdentifiers
import EditorEngine
import YunjianCore

extension AppRootViewModel {
    // MARK: - File IO

    func promptForSaveURL(defaultFilename: String) async -> URL? {
        await withCheckedContinuation { continuation in
            let panel = NSSavePanel()
            panel.nameFieldStringValue = defaultFilename
            panel.allowedContentTypes = [.plainText]
            panel.canCreateDirectories = true

            panel.begin { response in
                continuation.resume(returning: (response == .OK) ? panel.url : nil)
            }
        }
    }

    func openFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.text, .plainText, .utf8PlainText]

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { await self.openFile(url: url) }
        }
    }

    func openRecentFile(url: URL) {
        Task { await openFile(url: url) }
    }

    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { await self.openFolder(url: url) }
        }
    }

    private func openFolder(url: URL) async {
        openedFolderURL = url

        let built: [WorkspaceNode] = await Task.detached(priority: .userInitiated) {
            Self.buildWorkspaceTree(root: url)
        }.value

        folderTree = built
    }

    private nonisolated static func buildWorkspaceTree(root: URL) -> [WorkspaceNode] {
        let allowedExtensions: Set<String> = ["md", "markdown", "txt"]
        return buildChildren(of: root, allowedExtensions: allowedExtensions)
    }

    private nonisolated static func buildChildren(
        of directoryURL: URL,
        allowedExtensions: Set<String>
    ) -> [WorkspaceNode] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey, .isSymbolicLinkKey],
            options: [.skipsPackageDescendants]
        ) else {
            return []
        }

        var directories: [WorkspaceNode] = []
        var files: [WorkspaceNode] = []

        for url in urls {
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isHiddenKey, .isSymbolicLinkKey]) else {
                continue
            }
            if values.isHidden == true { continue }
            if values.isSymbolicLink == true { continue }

            if values.isDirectory == true {
                let children = buildChildren(of: url, allowedExtensions: allowedExtensions)
                // Keep empty directories out to avoid noisy trees.
                if children.isEmpty { continue }
                directories.append(WorkspaceNode(url: url, isDirectory: true, children: children))
            } else {
                let ext = url.pathExtension.lowercased()
                guard allowedExtensions.contains(ext) else { continue }
                files.append(WorkspaceNode(url: url, isDirectory: false))
            }
        }

        directories.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        files.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return directories + files
    }

    public func openFile(url: URL) async {
        let didStartSecurityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if didStartSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let body: String

            // Prefer UTF-8, but fall back to auto-detection and finally a lossy UTF-8 decode.
            if let s = try? String(contentsOf: url, encoding: .utf8) {
                body = s
            } else if let s = try? String(contentsOf: url) {
                body = s
            } else {
                let data = try Data(contentsOf: url)
                body = String(decoding: data, as: UTF8.self)
            }

            let title = url.deletingPathExtension().lastPathComponent
            let doc = YunjianCore.Document(title: title, body: body, fileURL: url)
            try? await storage.upsertDocument(doc)
            await load()
            await openDocument(id: doc.id)
            noteRecentFile(url)
        } catch {
            let alert = NSAlert()
            alert.messageText = "无法打开文件"
            alert.informativeText = "\(url.path)\n\n\(error.localizedDescription)"
            alert.addButton(withTitle: "好")
            alert.runModal()
        }
    }

    func saveAs() {
        guard let editor = activeEditor else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = (editor.document.title.isEmpty ? "Untitled" : editor.document.title) + ".md"
        panel.allowedContentTypes = [.plainText]

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { await self.save(to: url) }
        }
    }

    func save(to url: URL) async {
        guard let editor = activeEditor else { return }
        do {
            try editor.document.body.write(to: url, atomically: true, encoding: .utf8)
            editor.markSaved(fileURL: url)
            try? await storage.upsertDocument(editor.document)
            await load()
            noteRecentFile(url)
        } catch {
        }
    }

    func revealInFinder() {
        guard let url = activeEditor?.document.fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func closeWindow() {
        NSApp.keyWindow?.performClose(nil)
    }

    func openNewWindow() {
        // 先尽量使用系统动作；后续可换成 SwiftUI openWindow 多窗口。
        NSApp.sendAction(#selector(NSApplication.newWindowForTab(_:)), to: nil, from: nil)
    }

    func pageSetup() {
        let pageLayout = NSPageLayout()
        pageLayout.runModal()
    }

    func printDocument() {
        guard let body = activeEditor?.document.body else { return }
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 595, height: 842))
        textView.string = body
        textView.font = NSFont.userFixedPitchFont(ofSize: NSFont.systemFontSize)

        let printInfo = NSPrintInfo.shared
        let op = NSPrintOperation(view: textView, printInfo: printInfo)
        op.run()
    }

    // MARK: - Recent files

    private var recentDefaultsKey: String { "yunjian.recentFileURLs" }

    func loadRecentFilesFromDefaults() {
        guard let raw = UserDefaults.standard.array(forKey: recentDefaultsKey) as? [String] else {
            recentFileURLs = []
            return
        }
        recentFileURLs = raw.compactMap { URL(string: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .prefix(15)
            .map { $0 }
    }

    func noteRecentFile(_ url: URL) {
        NSDocumentController.shared.noteNewRecentDocumentURL(url)

        var urls = recentFileURLs
        urls.removeAll { $0 == url }
        urls.insert(url, at: 0)
        urls = Array(urls.prefix(15))
        recentFileURLs = urls

        UserDefaults.standard.set(urls.map { $0.absoluteString }, forKey: recentDefaultsKey)
    }

    func clearRecentFiles() {
        recentFileURLs = []
        UserDefaults.standard.removeObject(forKey: recentDefaultsKey)
    }

    // MARK: - Clipboard / Edit extras

    func pasteAsPlainText() {
        guard let s = NSPasteboard.general.string(forType: .string) else { return }
        Task { await applyToActiveEditor { $0.replaceSelection(with: s) } }
    }

    func pasteAsPNG() {
        guard let image = NSImage(pasteboard: .general) else { return }

        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "T", with: "-")
            .replacingOccurrences(of: "Z", with: "")

        let fileManager = FileManager.default
        let preferredDir: URL? = activeEditor?.document.fileURL?.deletingLastPathComponent()

        let fallbackDir = fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Yunjian", isDirectory: true)

        let dir = preferredDir ?? fallbackDir
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)

        let filenameBase = "paste-\(timestamp)"
        var fileURL = dir.appendingPathComponent(filenameBase).appendingPathExtension("png")
        var collisionIndex = 2
        while fileManager.fileExists(atPath: fileURL.path) {
            fileURL = dir.appendingPathComponent("\(filenameBase)-\(collisionIndex)").appendingPathExtension("png")
            collisionIndex += 1
        }

        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else { return }

        do {
            try png.write(to: fileURL)
            let markdown: String
            if preferredDir != nil {
                // 已保存文档：图片与 md 同目录，插入相对路径，便于移动/同步。
                let encodedName = fileURL.lastPathComponent.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fileURL.lastPathComponent
                markdown = "![](\(encodedName))"
            } else {
                markdown = "![](\(fileURL.absoluteString))"
            }
            Task { await applyToActiveEditor { $0.replaceSelection(with: markdown) } }
        } catch {
            if preferredDir != nil {
                // 若目标目录不可写（权限/只读等），回退到图片目录。
                try? fileManager.createDirectory(at: fallbackDir, withIntermediateDirectories: true)
                var fallbackURL = fallbackDir.appendingPathComponent(filenameBase).appendingPathExtension("png")
                var fallbackCollisionIndex = 2
                while fileManager.fileExists(atPath: fallbackURL.path) {
                    fallbackURL = fallbackDir.appendingPathComponent("\(filenameBase)-\(fallbackCollisionIndex)").appendingPathExtension("png")
                    fallbackCollisionIndex += 1
                }

                do {
                    try png.write(to: fallbackURL)
                    let markdown = "![](\(fallbackURL.absoluteString))"
                    Task { await applyToActiveEditor { $0.replaceSelection(with: markdown) } }
                } catch {
                    // ignore
                }
            }
        }
    }

    func pasteHTMLAsMarkdown() {
        if let html = NSPasteboard.general.string(forType: .html) {
            let md = basicHTMLToMarkdown(html)
            Task { await applyToActiveEditor { $0.replaceSelection(with: md) } }
            return
        }
        // fallback
        pasteAsPlainText()
    }

    func insertSpaceBetweenChineseAndLatin() async {
        await applyToActiveEditor { editor in
            let source = editor.document.body
            editor.updateBody(insertCNSpace(source))
        }
    }

    func insertHTMLEntity() async {
        await applyToActiveEditor { editor in
            editor.replaceSelection(with: "&nbsp;")
        }
    }

    // MARK: - Publish

    func copyHTML() {
        guard let body = activeEditor?.document.body else { return }
        let html = HTMLFormatter.format(body)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(html, forType: .string)
        NSPasteboard.general.setString(html, forType: .html)
    }

    func copyRichText() {
        guard let editor = activeEditor else { return }
        let selected = editor.selectedTextOrAll()
        let attr = NSAttributedString(string: selected)
        guard let rtf = try? attr.data(from: NSRange(location: 0, length: attr.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(rtf, forType: .rtf)
    }

    func exportOrCopyImage() {
        guard let editor = activeEditor else { return }
        let text = editor.document.body

        let attr = NSAttributedString(string: text, attributes: [.font: NSFont.userFixedPitchFont(ofSize: 13) ?? NSFont.systemFont(ofSize: 13)])
        let size = NSSize(width: 800, height: max(600, CGFloat(attr.length) * 0.6))
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.textBackgroundColor.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        attr.draw(in: NSRect(x: 20, y: 20, width: size.width - 40, height: size.height - 40))
        image.unlockFocus()

        let panel = NSSavePanel()
        panel.nameFieldStringValue = (editor.document.title.isEmpty ? "Untitled" : editor.document.title) + ".png"
        panel.allowedContentTypes = [.png]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            guard let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:])
            else { return }
            try? png.write(to: url)
        }
    }

    func exportMarkdown() { exportText(ext: "md", content: activeEditor?.document.body ?? "") }

    func exportHTML() {
        let html = HTMLFormatter.format(activeEditor?.document.body ?? "")
        exportText(ext: "html", content: html)
    }

    func exportRTF() {
        let text = activeEditor?.document.body ?? ""
        let attr = NSAttributedString(string: text)
        let rtf = (try? attr.data(from: NSRange(location: 0, length: attr.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])) ?? Data()
        exportData(ext: "rtf", data: rtf)
    }

    func exportPDF() {
        let text = activeEditor?.document.body ?? ""
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 595, height: 842))
        textView.string = text
        textView.font = NSFont.userFixedPitchFont(ofSize: 12)
        let data = textView.dataWithPDF(inside: textView.bounds)
        exportData(ext: "pdf", data: data)
    }

    func exportEpub() { exportText(ext: "epub", content: activeEditor?.document.body ?? "") }
    func exportDocx() { exportText(ext: "docx", content: activeEditor?.document.body ?? "") }
    func exportTextbundle() { exportText(ext: "textbundle", content: activeEditor?.document.body ?? "") }

    func uploadLocalImagesToImageHost() {
        // MVP：先复用“图片上传窗口”入口，提供本地插图能力。
        openImageUploadWindow()
    }

    // MARK: - Help

    func openHelpDocs() {
        openURLString("https://github.com/ChenyuHeee/Yunjian/blob/main/docs/help.md")
    }

    func openProjectHomepage() {
        openURLString("https://github.com/ChenyuHeee/Yunjian")
    }

    func openReleaseNotes() {
        openURLString("https://github.com/ChenyuHeee/Yunjian/releases")
    }

    func reportIssue() {
        openURLString("https://github.com/ChenyuHeee/Yunjian/issues/new")
    }

    func openMarkdownSyntax() {
        openURLString("https://commonmark.org/help/")
    }

    func sendFeedback() {
        // 简化：打开邮件
        openURLString("mailto:feedback@yunjian.app")
    }

    private func openURLString(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }

    func openAutoBlogWebsite() {
        if let url = URL(string: "https://github.com/ChenyuHeee/AutoBlog") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Syntax actions

    func syntaxBold() async { await applyToActiveEditor { $0.wrapSelection(prefix: "**", suffix: "**") } }
    func syntaxItalic() async { await applyToActiveEditor { $0.wrapSelection(prefix: "*", suffix: "*") } }
    func syntaxUnderline() async { await applyToActiveEditor { $0.wrapSelection(prefix: "<u>", suffix: "</u>") } }
    func syntaxStrikethrough() async { await applyToActiveEditor { $0.wrapSelection(prefix: "~~", suffix: "~~") } }

    func syntaxLink() async {
        await applyToActiveEditor { editor in
            let selected = editor.selectedTextOrEmpty()
            if selected.isEmpty {
                editor.replaceSelection(with: "[](url)")
            } else {
                editor.replaceSelection(with: "[\(selected)](url)")
            }
        }
    }

    func syntaxImageSyntax() async {
        await applyToActiveEditor { editor in
            editor.replaceSelection(with: "![](path)")
        }
    }

    func insertFileOrImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { await self.applyToActiveEditor { editor in
                let isImage = ["png", "jpg", "jpeg", "gif", "webp"].contains(url.pathExtension.lowercased())
                let linkText = url.lastPathComponent

                let finalURL: URL
                if isImage, let copied = self.copyToAttachmentsIfNeeded(sourceURL: url, documentID: editor.document.id) {
                    finalURL = copied
                } else {
                    finalURL = url
                }

                let markdown = isImage
                    ? "![](" + finalURL.absoluteString + ")"
                    : "[" + linkText + "](" + finalURL.absoluteString + ")"
                editor.replaceSelection(with: markdown)
            } }
        }
    }

    func insertImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .gif, .webP]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { await self.applyToActiveEditor { editor in
                let finalURL = self.copyToAttachmentsIfNeeded(sourceURL: url, documentID: editor.document.id) ?? url
                editor.replaceSelection(with: "![](\(finalURL.absoluteString))")
            } }
        }
    }

    func syntaxTable() async {
        await applyToActiveEditor { editor in
            editor.replaceSelection(with: "| Header | Header |\n| --- | --- |\n| Cell | Cell |\n")
        }
    }

    func syntaxUnorderedList() async { await applyToActiveEditor { $0.prefixLines("- ") } }
    func syntaxOrderedList() async { await applyToActiveEditor { $0.prefixLines("1. ") } }
    func syntaxTaskList() async { await applyToActiveEditor { $0.prefixLines("- [ ] ") } }
    func syntaxQuote() async { await applyToActiveEditor { $0.prefixLines("> ") } }

    func syntaxInlineCode() async { await applyToActiveEditor { $0.wrapSelection(prefix: "`", suffix: "`") } }

    func syntaxCodeBlock() async {
        await applyToActiveEditor { editor in
            editor.wrapSelection(prefix: "```\n", suffix: "\n```")
        }
    }

    func syntaxInlineMath() async { await applyToActiveEditor { $0.wrapSelection(prefix: "$", suffix: "$") } }
    func syntaxMathBlock() async { await applyToActiveEditor { $0.wrapSelection(prefix: "$$\n", suffix: "\n$$") } }

    func syntaxHorizontalRule() async { await applyToActiveEditor { $0.replaceSelection(with: "\n---\n") } }

    func syntaxHTMLComment() async { await applyToActiveEditor { $0.wrapSelection(prefix: "<!-- ", suffix: " -->") } }

    func syntaxHeading(level: Int) async {
        await applyToActiveEditor { editor in
            editor.applyHeading(level: level)
        }
    }

    func syntaxIndent() async { await applyToActiveEditor { $0.indentLines(by: 2) } }
    func syntaxOutdent() async { await applyToActiveEditor { $0.outdentLines(by: 2) } }
    func syntaxNewParagraph() async { await applyToActiveEditor { $0.replaceSelection(with: "\n\n") } }

    func editAddBlankLinesForWholeDocument() async {
        await applyToActiveEditor { editor in
            let source = editor.document.body as NSString
            let length = source.length
            guard length > 0 else { return }

            let selectionLocation = max(0, min(editor.selection.location, length))
            var insertedBeforeSelection = 0

            func trimForStructureChecks(_ s: String) -> String {
                s.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            func isFenceDelimiter(_ trimmed: String) -> String? {
                if trimmed.hasPrefix("```") { return "```" }
                if trimmed.hasPrefix("~~~") { return "~~~" }
                return nil
            }

            func isMathBlockDelimiter(_ trimmed: String) -> Bool {
                trimForStructureChecks(trimmed) == "$$"
            }

            func isHeadingLine(_ trimmed: String) -> Bool {
                // ATX headings: #, ##, ... ######
                var hashes = 0
                for ch in trimmed {
                    if ch == "#" { hashes += 1; continue }
                    break
                }
                if hashes == 0 || hashes > 6 { return false }
                let idx = trimmed.index(trimmed.startIndex, offsetBy: hashes)
                return idx < trimmed.endIndex && trimmed[idx] == " "
            }

            func isBlockQuoteLine(_ trimmed: String) -> Bool {
                trimmed.hasPrefix(">")
            }

            func isHorizontalRuleLine(_ trimmed: String) -> Bool {
                // Markdown HR: at least 3 of '-', '*', '_' with optional spaces.
                let compact = trimmed.replacingOccurrences(of: " ", with: "")
                guard compact.count >= 3 else { return false }
                guard let first = compact.first else { return false }
                if first != "-" && first != "*" && first != "_" { return false }
                for ch in compact {
                    if ch != first { return false }
                }
                return true
            }

            func isTableRowLine(_ trimmed: String) -> Bool {
                // Conservative: treat any pipe-containing line as table-ish.
                // This avoids inserting blank lines inside Markdown tables.
                if !trimmed.contains("|") { return false }
                if isFenceDelimiter(trimmed) != nil { return false }
                if isMathBlockDelimiter(trimmed) { return false }
                return true
            }

            func isListItemStart(_ trimmed: String) -> Bool {
                // Conservative: treat all Markdown list starters as "list block".
                // - unordered: -, +, *
                // - ordered: 1. / 1)
                // - task: - [ ] / - [x]
                let t = trimmed
                if t.hasPrefix("- [ ") || t.hasPrefix("- [x]") || t.hasPrefix("- [X]") { return true }
                if t.hasPrefix("* [ ") || t.hasPrefix("* [x]") || t.hasPrefix("* [X]") { return true }
                if t.hasPrefix("+ [ ") || t.hasPrefix("+ [x]") || t.hasPrefix("+ [X]") { return true }
                if t.hasPrefix("- ") || t.hasPrefix("* ") || t.hasPrefix("+ ") { return true }

                // Ordered list: starts with digits then '.' or ')'
                var digitsCount = 0
                for ch in t {
                    if ch >= "0" && ch <= "9" { digitsCount += 1; continue }
                    break
                }
                if digitsCount > 0 {
                    let idx = t.index(t.startIndex, offsetBy: digitsCount)
                    if idx < t.endIndex {
                        let rest = t[idx...]
                        if rest.hasPrefix(". ") || rest.hasPrefix(") ") { return true }
                    }
                }

                return false
            }

            func isPlainParagraphLine(_ trimmed: String) -> Bool {
                if trimmed.isEmpty { return false }
                if isListItemStart(trimmed) { return false }
                if isBlockQuoteLine(trimmed) { return false }
                if isHeadingLine(trimmed) { return false }
                if isHorizontalRuleLine(trimmed) { return false }
                if isTableRowLine(trimmed) { return false }
                if isFenceDelimiter(trimmed) != nil { return false }
                if isMathBlockDelimiter(trimmed) { return false }
                return true
            }

            var inCodeFence = false
            var activeFence: String? = nil
            var inMathBlock = false
            var inListBlock = false
            var inQuoteBlock = false
            var inTableBlock = false

            let output = NSMutableString()
            var cursor = 0
            var lineIndex = 0

            while cursor < length {
                let lineStart = cursor
                var lineEnd = cursor
                var hasNewline = false

                while lineEnd < length {
                    let c = source.character(at: lineEnd)
                    if c == 10 {
                        hasNewline = true
                        break
                    }
                    lineEnd += 1
                }

                let contentRange = NSRange(location: lineStart, length: lineEnd - lineStart)
                let rawLine = source.substring(with: contentRange)
                let trimmed = trimForStructureChecks(rawLine)

                // Peek next line trimmed (for deciding whether to insert a blank line).
                var nextTrimmed = ""
                if hasNewline {
                    let nextStart = min(lineEnd + 1, length)
                    if nextStart < length {
                        var nextEnd = nextStart
                        while nextEnd < length, source.character(at: nextEnd) != 10 { nextEnd += 1 }
                        let nextRaw = source.substring(with: NSRange(location: nextStart, length: nextEnd - nextStart))
                        nextTrimmed = trimForStructureChecks(nextRaw)
                    }
                }

                // Append this line (including its existing newline, if any).
                if hasNewline {
                    output.append(source.substring(with: NSRange(location: lineStart, length: (lineEnd - lineStart) + 1)))
                } else {
                    output.append(source.substring(with: NSRange(location: lineStart, length: lineEnd - lineStart)))
                }

                // Update structural states based on the current line.
                if let fence = isFenceDelimiter(trimmed) {
                    if !inCodeFence {
                        inCodeFence = true
                        activeFence = fence
                    } else if activeFence == fence {
                        inCodeFence = false
                        activeFence = nil
                    }
                }

                if isMathBlockDelimiter(trimmed) {
                    inMathBlock.toggle()
                }

                if trimmed.isEmpty {
                    inListBlock = false
                    inQuoteBlock = false
                    inTableBlock = false
                } else if !inListBlock, isListItemStart(trimmed) {
                    inListBlock = true
                } else if !inQuoteBlock, isBlockQuoteLine(trimmed) {
                    inQuoteBlock = true
                } else if !inTableBlock, isTableRowLine(trimmed) {
                    inTableBlock = true
                }

                // Decide whether to insert an extra '\n' after this newline.
                if hasNewline {
                    let newlineIndex = lineEnd
                    let nextIsNewline = (lineEnd + 1 < length) && (source.character(at: lineEnd + 1) == 10)

                    if !nextIsNewline {
                        let shouldInsert =
                            !inCodeFence &&
                            !inMathBlock &&
                            !inListBlock &&
                            !inQuoteBlock &&
                            !inTableBlock &&
                            isPlainParagraphLine(trimmed) &&
                            isPlainParagraphLine(nextTrimmed)

                        if shouldInsert {
                            output.append("\n")
                            if newlineIndex < selectionLocation { insertedBeforeSelection += 1 }
                        }
                    }
                }

                cursor = hasNewline ? (lineEnd + 1) : lineEnd
                lineIndex += 1
                _ = lineIndex // keep variables tidy; helpful for debugging if needed
            }

            let newBody = output as String
            guard newBody != editor.document.body else { return }

            editor.updateBody(newBody)
            editor.updateSelection(location: selectionLocation + insertedBeforeSelection, length: editor.selection.length)
        }
    }

    func insertCurrentDate() async {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let s = f.string(from: Date())
        await applyToActiveEditor { $0.replaceSelection(with: s) }
    }

    func insertCurrentTime() async {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        let s = f.string(from: Date())
        await applyToActiveEditor { $0.replaceSelection(with: s) }
    }

    // MARK: - Helpers

    private func exportText(ext: String, content: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = (activeEditor?.document.title.isEmpty == false ? activeEditor!.document.title : "Untitled") + "." + ext
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func exportData(ext: String, data: Data) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = (activeEditor?.document.title.isEmpty == false ? activeEditor!.document.title : "Untitled") + "." + ext
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? data.write(to: url)
        }
    }

    private func applyToActiveEditor(_ block: (EditorViewModel) -> Void) async {
        guard let editor = activeEditor else { return }
        block(editor)
    }

    private func copyToAttachmentsIfNeeded(sourceURL: URL, documentID: DocumentID) -> URL? {
        let fm = FileManager.default
        guard let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }

        let folder = base
            .appendingPathComponent("Yunjian", isDirectory: true)
            .appendingPathComponent("Attachments", isDirectory: true)
            .appendingPathComponent(documentID.rawValue.uuidString, isDirectory: true)

        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            return nil
        }

        let ext = sourceURL.pathExtension
        let baseName = sourceURL.deletingPathExtension().lastPathComponent

        func candidateURL(_ index: Int?) -> URL {
            let name = index == nil ? baseName : "\(baseName)-\(index!)"
            return folder.appendingPathComponent(name).appendingPathExtension(ext)
        }

        var dest = candidateURL(nil)
        var i = 1
        while fm.fileExists(atPath: dest.path) {
            dest = candidateURL(i)
            i += 1
        }

        do {
            try fm.copyItem(at: sourceURL, to: dest)
            return dest
        } catch {
            // If copying fails, fall back to using the original URL.
            return nil
        }
    }

    private func basicHTMLToMarkdown(_ html: String) -> String {
        var s = html
        s = s.replacingOccurrences(of: "\\r", with: "")
        s = s.replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "<br/>", with: "\n", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "<br />", with: "\n", options: .caseInsensitive)

        // strong/em/code
        s = s.replacingOccurrences(of: "(?is)<(strong|b)>(.*?)</(strong|b)>", with: "**$2**", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?is)<(em|i)>(.*?)</(em|i)>", with: "*$2*", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?is)<code>(.*?)</code>", with: "`$1`", options: .regularExpression)

        // links
        s = s.replacingOccurrences(of: "(?is)<a\\s+[^>]*href=\"([^\"]+)\"[^>]*>(.*?)</a>", with: "[$2]($1)", options: .regularExpression)

        // paragraphs
        s = s.replacingOccurrences(of: "(?is)</p>", with: "\n\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?is)<p[^>]*>", with: "", options: .regularExpression)

        // strip remaining tags
        s = s.replacingOccurrences(of: "(?is)<[^>]+>", with: "", options: .regularExpression)

        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func insertCNSpace(_ input: String) -> String {
        // Han <-> Latin/Digit spacing
        let patterns: [(String, String)] = [
            ("([\\p{Han}])([A-Za-z0-9])", "$1 $2"),
            ("([A-Za-z0-9])([\\p{Han}])", "$1 $2")
        ]

        var s = input
        for (p, r) in patterns {
            s = s.replacingOccurrences(of: p, with: r, options: .regularExpression)
        }
        return s
    }
}

#endif
