import SwiftUI
import YunjianCore

#if os(macOS)
import AppKit
import Markdown
#endif

public struct YunjianMenuCommands: Commands {
    private let root: AppRootViewModel

    public init(root: AppRootViewModel) {
        self.root = root
    }

    public var body: some Commands {
#if os(macOS)
        CommandGroup(replacing: .appInfo) {
            Button(L10n.format("app.menu.about", L10n.text("app.title"))) {
                YunjianAboutPanel.show()
            }
        }
#endif

        // 文件菜单：补齐打开/保存/另存为/打印等
        CommandGroup(replacing: .newItem) {
            Button(L10n.text("common.new")) { Task { await root.createDocument() } }
                .keyboardShortcut("n", modifiers: [.command])

#if os(macOS)
            Button(L10n.text("file.open")) { root.openFile() }
                .keyboardShortcut("o", modifiers: [.command])

            Menu(L10n.text("file.openRecent")) {
                if root.recentFileURLs.isEmpty {
                    Text(L10n.text("doc.menu.noRecent"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(root.recentFileURLs, id: \.self) { url in
                        Button(url.lastPathComponent) { root.openRecentFile(url: url) }
                    }
                    Divider()
                    Button(L10n.text("file.clearRecent")) { root.clearRecentFiles() }
                }
            }
#endif
        }

        CommandGroup(replacing: .saveItem) {
            Button(L10n.text("common.save")) { Task { await root.saveActiveDocument() } }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(root.activeEditor == nil || (!root.canSave && root.activeEditor?.document.fileURL != nil))

#if os(macOS)
            Button(L10n.text("file.saveAs")) { root.saveAs() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(root.activeEditor == nil)
#endif
        }

#if os(macOS)
        CommandGroup(after: .saveItem) {
            Divider()

            Button(L10n.text("file.closeDocument")) { Task { await root.closeDocument() } }
                .keyboardShortcut("w", modifiers: [.command])
                .disabled(root.activeEditor == nil)

            Button(L10n.text("file.closeWindow")) { root.closeWindow() }
                .keyboardShortcut("w", modifiers: [.command, .shift])

            Button(L10n.text("file.newWindow")) { root.openNewWindow() }
                .keyboardShortcut("n", modifiers: [.command, .shift])

            Divider()

            Button(L10n.text("file.revealInFinder")) { root.revealInFinder() }
                .disabled(root.activeEditor?.document.fileURL == nil)
        }

        CommandGroup(replacing: .printItem) {
            Button(L10n.text("file.pageSetup")) { root.pageSetup() }
            Button(L10n.text("file.print")) { root.printDocument() }
                .keyboardShortcut("p", modifiers: [.command])
                .disabled(root.activeEditor == nil)
        }
#endif

        // 编辑菜单：系统项走 responder chain；自定义项在这里补齐
        CommandGroup(after: .pasteboard) {
#if os(macOS)
            Divider()

            Button(L10n.text("edit.oneClickNewline")) { Task { await root.editAddBlankLinesForWholeDocument() } }

            Button(L10n.text("edit.pasteAsPNG")) { root.pasteAsPNG() }

            Button(L10n.text("edit.pasteAsPlainText")) { root.pasteAsPlainText() }

            Button(L10n.text("edit.pasteHTMLAsMarkdown")) { root.pasteHTMLAsMarkdown() }

            Divider()

            Button(L10n.text("edit.insertCNSpace")) { Task { await root.insertSpaceBetweenChineseAndLatin() } }

            Button(L10n.text("edit.insertHTMLEntity")) { Task { await root.insertHTMLEntity() } }
#endif
        }

        // 语法（自定义顶级菜单）
        CommandMenu(L10n.text("syntax.menu.title")) {
            Button(L10n.text("syntax.bold")) { Task { await root.syntaxBold() } }
                .keyboardShortcut("b", modifiers: [.command])
            Button(L10n.text("syntax.italic")) { Task { await root.syntaxItalic() } }
                .keyboardShortcut("i", modifiers: [.command])
            Button(L10n.text("syntax.underline")) { Task { await root.syntaxUnderline() } }
                .keyboardShortcut("u", modifiers: [.command])
            Button(L10n.text("syntax.strikethrough")) { Task { await root.syntaxStrikethrough() } }

            Divider()

            Button(L10n.text("syntax.link")) { Task { await root.syntaxLink() } }
                .keyboardShortcut("k", modifiers: [.command])
            Button(L10n.text("syntax.imageSyntax")) { Task { await root.syntaxImageSyntax() } }
            Button(L10n.text("syntax.insertFile")) { root.insertFileOrImage() }

            Divider()

            Button(L10n.text("syntax.table")) { Task { await root.syntaxTable() } }
            Button(L10n.text("syntax.ul")) { Task { await root.syntaxUnorderedList() } }
            Button(L10n.text("syntax.ol")) { Task { await root.syntaxOrderedList() } }
            Button(L10n.text("syntax.task")) { Task { await root.syntaxTaskList() } }
            Button(L10n.text("syntax.quote")) { Task { await root.syntaxQuote() } }

            Divider()

            Button(L10n.text("syntax.inlineCode")) { Task { await root.syntaxInlineCode() } }
            Button(L10n.text("syntax.codeBlock")) { Task { await root.syntaxCodeBlock() } }
            Button(L10n.text("syntax.inlineMath")) { Task { await root.syntaxInlineMath() } }
            Button(L10n.text("syntax.mathBlock")) { Task { await root.syntaxMathBlock() } }
            Button(L10n.text("syntax.hr")) { Task { await root.syntaxHorizontalRule() } }
            Button(L10n.text("syntax.htmlComment")) { Task { await root.syntaxHTMLComment() } }

            Divider()

            Menu(L10n.text("syntax.heading")) {
                ForEach(1...6, id: \.self) { level in
                    Button(L10n.format("syntax.headingN", level)) { Task { await root.syntaxHeading(level: level) } }
                }
            }

            Divider()

            Button(L10n.text("syntax.indent")) { Task { await root.syntaxIndent() } }
            Button(L10n.text("syntax.outdent")) { Task { await root.syntaxOutdent() } }
            Button(L10n.text("syntax.newParagraph")) { Task { await root.syntaxNewParagraph() } }

            Divider()

            Button(L10n.text("syntax.insertDate")) { Task { await root.insertCurrentDate() } }
            Button(L10n.text("syntax.insertTime")) { Task { await root.insertCurrentTime() } }
        }

        // 视图菜单（补齐截图里的条目；未实现的先做可切换的状态位）
        CommandGroup(after: .toolbar) {
#if os(macOS)
            Divider()
            Button(L10n.text("view.showDocLocation")) { root.toggleShowDocumentLocation() }
                .keyboardShortcut("j", modifiers: [.command, .shift])

            Divider()
            Button(L10n.text("view.editorOnly")) { root.setLayout(.editorOnly) }
                .keyboardShortcut("1", modifiers: [.command])
            Button(L10n.text("view.twoColumn")) { root.setLayout(.twoColumn) }
                .keyboardShortcut("2", modifiers: [.command])
            Button(L10n.text("view.threeColumn")) { root.setLayout(.threeColumn) }
                .keyboardShortcut("3", modifiers: [.command])

            Divider()
            Button(L10n.text("view.togglePreviewEditor")) { root.togglePreviewEditor() }
                .keyboardShortcut("r", modifiers: [.command])
            Button(L10n.text("view.toggleEditPreview")) { root.toggleEditAndPreviewSideBySide() }
                .keyboardShortcut("4", modifiers: [.command])
            Button(L10n.text("view.focusMode")) { root.toggleFocusMode() }
                .keyboardShortcut("5", modifiers: [.command])
            Button(L10n.text("view.outline")) { root.toggleOutline() }
                .keyboardShortcut("7", modifiers: [.command])

            Divider()
            Button(L10n.text("view.imageUploadWindow")) { root.openImageUploadWindow() }
            Button(L10n.text("view.documentAttributes")) { root.openDocumentAttributes() }
                .keyboardShortcut("8", modifiers: [.command])
            Button(L10n.text("view.windowAlwaysOnTop")) { root.toggleAlwaysOnTop() }

            Divider()
            Menu(L10n.text("view.customizeToolbar")) {
                Button(L10n.text("view.toggleToolbar")) { root.toggleToolbar() }
                    .keyboardShortcut("t", modifiers: [.command, .option])
                Button(L10n.text("view.toggleTabBar")) { root.toggleTabBar() }
            }

            Divider()
            Button(L10n.text("view.resetFont")) { root.resetFontSize() }
                .keyboardShortcut("0", modifiers: [.command])
            Button(L10n.text("view.increaseFont")) { root.increaseFontSize() }
                .keyboardShortcut("=", modifiers: [.command])
            Button(L10n.text("view.decreaseFont")) { root.decreaseFontSize() }
                .keyboardShortcut("-", modifiers: [.command])

            Divider()
            Button(L10n.text("view.prevTab")) { root.previousTab() }
                .keyboardShortcut("[", modifiers: [.command, .shift])
            Button(L10n.text("view.nextTab")) { root.nextTab() }
                .keyboardShortcut("]", modifiers: [.command, .shift])

            Divider()
            Button(L10n.text("view.highlightCurrentLine")) { root.toggleHighlightCurrentLine() }

            Divider()
            Button(L10n.text("view.typewriterMode")) { root.toggleTypewriterMode() }

            Divider()
            Button(L10n.text("view.darkMode")) { root.toggleDarkMode() }
                .keyboardShortcut("l", modifiers: [.command, .option])

            Divider()
            Menu(L10n.text("view.listStyle")) {
                Button(L10n.text("view.listStyle.default")) { }
                Button(L10n.text("view.listStyle.compact")) { }
            }

            Divider()
            Button(L10n.text("view.enterFullScreen")) { root.enterFullScreen() }

            Divider()
                Button(L10n.text("view.openLibraryMode")) { root.openLibraryMode() }
                Button(L10n.text("view.openFolderMode")) { root.openFolder() }
#endif
        }

        // 发布（截图里的条目）
        CommandMenu(L10n.text("publish.menu.title")) {
#if os(macOS)
            Button(L10n.text("publish.copyHTML")) { root.copyHTML() }
                .keyboardShortcut("c", modifiers: [.command, .option])
            Button(L10n.text("publish.copyRichText")) { root.copyRichText() }

            Divider()

            Button(L10n.text("publish.exportOrCopyImage")) { root.exportOrCopyImage() }
            Button(L10n.text("publish.exportTextbundle")) { root.exportTextbundle() }
            Button(L10n.text("publish.exportPDF")) { root.exportPDF() }
            Button(L10n.text("publish.exportHTML")) { root.exportHTML() }
            Button(L10n.text("publish.exportMarkdown")) { root.exportMarkdown() }
            Button(L10n.text("publish.exportEpub")) { root.exportEpub() }
            Button(L10n.text("publish.exportRTF")) { root.exportRTF() }
            Button(L10n.text("publish.exportDocx")) { root.exportDocx() }

            Divider()

            Button(L10n.text("publish.uploadImages")) { root.uploadLocalImagesToImageHost() }

            Divider()

            Button(L10n.text("publish.setupWordpressEvernote")) { }
                .disabled(true)

            Divider()
            Button(L10n.text("help.autoblog")) { root.openAutoBlogWebsite() }
#endif
        }

        // 帮助：替换系统默认“AppName 帮助”（未配置 Help Book 时会提示未找到帮助文档）
        CommandGroup(replacing: .help) {
#if os(macOS)
            Button(L10n.text("help.helpDocs")) { root.openHelpDocs() }
            Button(L10n.text("help.markdownSyntax")) { root.openMarkdownSyntax() }

            Divider()
            Button(L10n.text("help.homepage")) { root.openProjectHomepage() }
            Button(L10n.text("help.releaseNotes")) { root.openReleaseNotes() }
            Button(L10n.text("help.reportIssue")) { root.reportIssue() }

            Divider()
            Button(L10n.text("help.sendFeedback")) { root.sendFeedback() }
#endif
        }
    }
}
