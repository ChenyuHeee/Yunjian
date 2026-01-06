import Foundation
import Observation
import EditorEngine
import StorageService
import SyncEngine
import YunjianCore

#if os(macOS)
import AppKit
#endif

@MainActor
@Observable
public final class AppRootViewModel {
    public struct WorkspaceNode: Identifiable, Hashable, Sendable {
        public let url: URL
        public let isDirectory: Bool
        public var children: [WorkspaceNode]?

        public init(url: URL, isDirectory: Bool, children: [WorkspaceNode]? = nil) {
            self.url = url
            self.isDirectory = isDirectory
            self.children = children
        }

        public var id: URL { url }
        public var name: String { url.lastPathComponent }
    }

    public private(set) var documents: [Document] = []
    public var selectedDocumentID: DocumentID?

    public private(set) var syncState: SyncState = .idle

    public private(set) var activeEditor: EditorViewModel?
    public private(set) var isLoadingEditor: Bool = false

    public private(set) var joinedCollaborationDocumentIDs: Set<DocumentID> = []

    // View state (macOS menu binds to these)
    public enum LayoutMode: String, Hashable, Sendable {
        case editorOnly
        case twoColumn
        case threeColumn
    }

    public private(set) var layoutMode: LayoutMode = .twoColumn
    public private(set) var isOutlineVisible: Bool = false
    public private(set) var isFocusMode: Bool = false
    public private(set) var showDocumentLocationInNav: Bool = false
    public private(set) var prefersDarkMode: Bool = false
    public private(set) var highlightCurrentLine: Bool = false
    public private(set) var isTypewriterMode: Bool = false

    public private(set) var editorFontDelta: Double = 0

    // Sheets / panels
    public var isDocumentAttributesPresented: Bool = false
    public var isImageUploadPresented: Bool = false

    public enum EditorPresentation: String, Hashable, Sendable {
        case editor
        case preview
        case split
    }

    public private(set) var editorPresentation: EditorPresentation = .editor
    private var lastSinglePresentation: EditorPresentation = .editor

    // Recent files (macOS)
    public var recentFileURLs: [URL] = []

    // Folder mode (macOS)
    public internal(set) var openedFolderURL: URL?
    public internal(set) var folderTree: [WorkspaceNode] = []

    public let storage: StorageServiceProtocol
    public let sync: SyncEngineProtocol
    public let collaboration: CollaborationEngineProtocol?

    public init(storage: StorageServiceProtocol, sync: SyncEngineProtocol, collaboration: CollaborationEngineProtocol? = nil) {
        self.storage = storage
        self.sync = sync
        self.collaboration = collaboration
    }

    public var isCollaborationAvailable: Bool { collaboration != nil }

    public var isSelectedDocumentJoined: Bool {
        guard let id = selectedDocumentID else { return false }
        return joinedCollaborationDocumentIDs.contains(id)
    }

    public var collaborationStatusText: String {
        guard selectedDocumentID != nil else { return "" }
        return isSelectedDocumentJoined ? L10n.text("collab.state.joined") : L10n.text("collab.state.notJoined")
    }

    public var syncStateText: String {
        switch syncState {
        case .idle:
            return L10n.text("sync.state.idle")
        case .syncing:
            return L10n.text("sync.state.syncing")
        case .error(_):
            return L10n.text("sync.state.error")
        }
    }

    public func load() async {
        do {
            documents = try await storage.listDocuments()
        } catch {
            documents = []
        }

        startObservingSyncStateIfNeeded()

        await openSelectedDocumentIfNeeded()

    #if os(macOS)
        loadRecentFilesFromDefaults()
    #endif
    }

    public var recentDocuments: [Document] {
        Array(documents.prefix(10))
    }

    public func openDocument(id: DocumentID) async {
        selectedDocumentID = id
        await openSelectedDocumentIfNeeded()
    }

    public func openSelectedDocumentIfNeeded() async {
        guard let id = selectedDocumentID else {
            activeEditor = nil
            return
        }

        if let activeEditor, activeEditor.document.id == id {
            return
        }

        isLoadingEditor = true
        defer { isLoadingEditor = false }

        do {
            let doc = try await storage.loadDocument(id: id)
            activeEditor = EditorViewModel(document: doc, storage: storage, sync: sync)
        } catch {
            activeEditor = nil
        }
    }

    // MARK: - View / Menu state

    public func setLayout(_ mode: LayoutMode) {
        layoutMode = mode
    }

    public func toggleOutline() {
        isOutlineVisible.toggle()
    }

    public func toggleFocusMode() {
        isFocusMode.toggle()
    }

    public func toggleShowDocumentLocation() {
        showDocumentLocationInNav.toggle()
    }

    public func toggleDarkMode() {
        prefersDarkMode.toggle()
    }

    public func toggleHighlightCurrentLine() {
        highlightCurrentLine.toggle()
    }

    public func toggleTypewriterMode() {
        isTypewriterMode.toggle()
    }

    public func resetFontSize() { editorFontDelta = 0 }
    public func increaseFontSize() { editorFontDelta = min(editorFontDelta + 1, 12) }
    public func decreaseFontSize() { editorFontDelta = max(editorFontDelta - 1, -6) }

    public func previousTab() {
#if os(macOS)
        NSApp.sendAction(#selector(NSWindow.selectPreviousTab(_:)), to: nil, from: nil)
#endif
    }

    public func nextTab() {
#if os(macOS)
        NSApp.sendAction(#selector(NSWindow.selectNextTab(_:)), to: nil, from: nil)
#endif
    }

    public func togglePreviewEditor() {
        let nextSingle: EditorPresentation
        switch lastSinglePresentation {
        case .editor:
            nextSingle = .preview
        default:
            nextSingle = .editor
        }

        editorPresentation = nextSingle
        lastSinglePresentation = nextSingle
    }

    public func toggleEditAndPreviewSideBySide() {
        if editorPresentation == .split {
            editorPresentation = lastSinglePresentation
        } else {
            if editorPresentation != .split {
                lastSinglePresentation = editorPresentation
            }
            editorPresentation = .split
        }
    }

    public func openImageUploadWindow() {
        isImageUploadPresented = true
    }

    public func openDocumentAttributes() {
        isDocumentAttributesPresented = true
    }

    public func toggleAlwaysOnTop() {
#if os(macOS)
        guard let window = NSApp.keyWindow else { return }
        window.level = (window.level == .floating) ? .normal : .floating
#endif
    }

    public func toggleToolbar() {
#if os(macOS)
        NSApp.sendAction(#selector(NSWindow.toggleToolbarShown(_:)), to: nil, from: nil)
#endif
    }

    public func toggleTabBar() {
#if os(macOS)
        NSApp.sendAction(#selector(NSWindow.toggleTabBar(_:)), to: nil, from: nil)
#endif
    }

    public func enterFullScreen() {
#if os(macOS)
        NSApp.keyWindow?.toggleFullScreen(nil)
#endif
    }

    private var isObservingSync = false
    private func startObservingSyncStateIfNeeded() {
        guard !isObservingSync else { return }
        isObservingSync = true

        Task {
            for await state in sync.stateStream {
                await MainActor.run {
                    self.syncState = state
                }
            }
        }
    }

    public func syncNow() async {
        await sync.requestSync(reason: "menu-sync")
        // 不强制 reload editor，避免覆盖未保存草稿；仅刷新列表。
        do {
            documents = try await storage.listDocuments()
        } catch {
            documents = []
        }
    }

    public func joinCollaborationForSelection() async {
        guard let collaboration, let id = selectedDocumentID else { return }
        try? await collaboration.join(documentID: id)
        joinedCollaborationDocumentIDs.insert(id)
    }

    public func leaveCollaborationForSelection() async {
        guard let collaboration, let id = selectedDocumentID else { return }
        await collaboration.leave(documentID: id)
        joinedCollaborationDocumentIDs.remove(id)
    }

    public func createDocument() async {
        let doc = Document(title: L10n.text("library.untitled"), body: "")
        try? await storage.upsertDocument(doc)
        await load()
        await openDocument(id: doc.id)
        await sync.requestSync(reason: "create-document")
    }

    public func deleteSelected() async {
        guard let id = selectedDocumentID else { return }
        try? await storage.deleteDocument(id: id)
        selectedDocumentID = nil
        activeEditor = nil
        await load()
        await sync.requestSync(reason: "delete-document")
    }

    public var canSave: Bool {
        activeEditor?.isDirty == true
    }

    public func saveActiveDocument() async {
        guard let activeEditor else { return }

#if os(macOS)
        if let url = activeEditor.document.fileURL {
            await save(to: url)
            return
        }

        if let url = await promptForSaveURL(defaultFilename: (activeEditor.document.title.isEmpty ? "Untitled" : activeEditor.document.title) + ".md") {
            await save(to: url)
        }
        return
#else
        try? await activeEditor.save()
        // 保存后刷新列表排序
        do {
            documents = try await storage.listDocuments()
        } catch {
            documents = []
        }
#endif
    }

    public func closeDocument() async {
        selectedDocumentID = nil
        activeEditor = nil
    }

    public func openLibraryMode() {
        openedFolderURL = nil
        folderTree = []
    }
}
