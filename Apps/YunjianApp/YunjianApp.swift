import SwiftUI
import StorageService
import SyncEngine
import UIComponents
import YunjianCore

#if os(macOS)
import AppKit
import UniformTypeIdentifiers

private enum YunjianAppShared {
    static var root: AppRootViewModel?
    static var isTerminating: Bool = false
}

@MainActor
final class YunjianAppDelegate: NSObject, NSApplicationDelegate {
    private var fallbackWindow: NSWindow?
    private var windowDelegates: [ObjectIdentifier: NSWindowDelegate] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        debugLog("didFinishLaunching")
        bringMainWindowToFront(retryCount: 10)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let root = YunjianAppShared.root else { return .terminateNow }
        guard YunjianAppShared.isTerminating == false else { return .terminateNow }

        guard root.activeEditor?.isDirty == true else { return .terminateNow }

        YunjianAppShared.isTerminating = true

        let alert = NSAlert()
        alert.messageText = L10n.text("closeConfirm.title")
        alert.informativeText = L10n.text("closeConfirm.message")
        alert.addButton(withTitle: L10n.text("common.save"))
        alert.addButton(withTitle: L10n.text("closeConfirm.dontSave"))
        alert.addButton(withTitle: L10n.text("common.cancel"))

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            requestSaveForTermination(root: root)
            return .terminateLater
        case .alertSecondButtonReturn:
            NSApp.reply(toApplicationShouldTerminate: true)
            return .terminateLater
        default:
            YunjianAppShared.isTerminating = false
            NSApp.reply(toApplicationShouldTerminate: false)
            return .terminateLater
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            debugLog("reopen(hasVisibleWindows: false)")
            bringMainWindowToFront(retryCount: 10)
        }
        return true
    }

    private func bringMainWindowToFront(retryCount: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NSRunningApplication.current.activate(options: [.activateAllWindows])
            NSApp.activate(ignoringOtherApps: true)
            NSApp.unhide(nil)

            self.debugLog("bringToFront(retryCount: \(retryCount))")

            // If SwiftUI decided not to auto-create a window (e.g. state restore / last window closed),
            // try poking the responder chain for common “new/show windows” actions.
            if NSApp.windows.isEmpty {
                NSApp.sendAction(#selector(NSApplication.arrangeInFront(_:)), to: nil, from: nil)
                NSApp.sendAction(#selector(NSWindow.newWindowForTab(_:)), to: nil, from: nil)
            }

            // If we still have no keyable window, create a fallback hosting window.
            if self.pickBestWindow() == nil {
                self.createFallbackWindowIfNeeded()
            }

            if let window = self.pickBestWindow() {
                self.attachUnsavedChangesHandlerIfNeeded(to: window)
                if window.isMiniaturized {
                    window.deminiaturize(nil)
                }
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                NSRunningApplication.current.activate(options: [.activateAllWindows])
                return
            }

            if retryCount > 0 {
                self.bringMainWindowToFront(retryCount: retryCount - 1)
            }
        }
    }

    private func pickBestWindow() -> NSWindow? {
        if let window = NSApp.keyWindow { return window }
        if let window = NSApp.mainWindow { return window }
        if let window = NSApp.orderedWindows.first(where: { $0.isVisible && $0.canBecomeKey }) { return window }
        if let window = NSApp.windows.first(where: { $0.isVisible && $0.canBecomeKey }) { return window }
        if let window = NSApp.orderedWindows.first(where: { $0.canBecomeKey }) { return window }
        if let window = NSApp.windows.first(where: { $0.canBecomeKey }) { return window }
        if let window = NSApp.orderedWindows.first { return window }
        return NSApp.windows.first
    }

    private func createFallbackWindowIfNeeded() {
        guard fallbackWindow == nil else { return }
        guard let root = YunjianAppShared.root else { return }

        let rect = NSRect(x: 0, y: 0, width: 900, height: 450)
        let style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]

        let window = NSWindow(contentRect: rect, styleMask: style, backing: .buffered, defer: false)
        window.title = L10n.text("app.title")
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: LibraryScreen(root: root))
        window.center()
        window.makeKeyAndOrderFront(nil)

        attachUnsavedChangesHandlerIfNeeded(to: window)

        fallbackWindow = window
        debugLog("createdFallbackWindow")
    }

    private func attachUnsavedChangesHandlerIfNeeded(to window: NSWindow) {
        let key = ObjectIdentifier(window)
        guard windowDelegates[key] == nil else { return }

        let delegate = UnsavedChangesWindowDelegate(owner: self)
        window.delegate = delegate
        windowDelegates[key] = delegate
    }

    private func requestSaveForTermination(root: AppRootViewModel) {
        guard let editor = root.activeEditor else {
            NSApp.reply(toApplicationShouldTerminate: true)
            return
        }

        if let url = editor.document.fileURL {
            do {
                try editor.document.body.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                // If writing fails, treat as cancel.
                YunjianAppShared.isTerminating = false
                NSApp.reply(toApplicationShouldTerminate: false)
                return
            }

            Task {
                await root.saveActiveDocument()
                self.noteRecentFile(url, root: root)
                NSApp.reply(toApplicationShouldTerminate: true)
            }
            return
        }

        // No fileURL: show Save Panel.
        let panel = NSSavePanel()
        panel.nameFieldStringValue = (editor.document.title.isEmpty ? "Untitled" : editor.document.title) + ".md"
        panel.allowedContentTypes = [.plainText]
        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                YunjianAppShared.isTerminating = false
                NSApp.reply(toApplicationShouldTerminate: false)
                return
            }

            Task {
                let ok = await self.saveEditorToFileURL(url, root: root)
                if ok {
                    self.noteRecentFile(url, root: root)
                    NSApp.reply(toApplicationShouldTerminate: true)
                } else {
                    YunjianAppShared.isTerminating = false
                    NSApp.reply(toApplicationShouldTerminate: false)
                }
            }
        }
    }

    @MainActor
    private func saveEditorToFileURL(_ url: URL, root: AppRootViewModel) async -> Bool {
        guard let editor = root.activeEditor else { return false }
        do {
            try editor.document.body.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            return false
        }

        var updated = editor.document
        updated.fileURL = url
        try? await root.storage.upsertDocument(updated)
        await root.load()
        await root.openDocument(id: updated.id)
        await root.saveActiveDocument()

        return true
    }

    private func noteRecentFile(_ url: URL, root: AppRootViewModel) {
        NSDocumentController.shared.noteNewRecentDocumentURL(url)

        var urls = root.recentFileURLs
        urls.removeAll { $0 == url }
        urls.insert(url, at: 0)
        urls = Array(urls.prefix(15))
        root.recentFileURLs = urls

        UserDefaults.standard.set(urls.map { $0.absoluteString }, forKey: "yunjian.recentFileURLs")
    }

    private func debugLog(_ message: String) {
        let windows = NSApp.windows
        let ordered = NSApp.orderedWindows
        let keyTitle = NSApp.keyWindow?.title ?? "nil"
        let mainTitle = NSApp.mainWindow?.title ?? "nil"
        let summary = "active=\(NSApp.isActive) windows=\(windows.count) ordered=\(ordered.count) key=\(keyTitle) main=\(mainTitle)"
        print("[YunjianApp] \(message) | \(summary)")

        for (index, window) in windows.prefix(8).enumerated() {
            let typeName = String(describing: type(of: window))
            let title = window.title
            let visible = window.isVisible
            let keyable = window.canBecomeKey
            let mini = window.isMiniaturized
            let level = window.level.rawValue
            let frame = window.frame
            print("[YunjianApp]   [\(index)] \(typeName) title=\"\(title)\" visible=\(visible) keyable=\(keyable) mini=\(mini) level=\(level) frame=\(NSStringFromRect(frame))")
        }
    }
}

@MainActor
private final class UnsavedChangesWindowDelegate: NSObject, NSWindowDelegate {
    private weak var owner: YunjianAppDelegate?

    init(owner: YunjianAppDelegate) {
        self.owner = owner
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        owner?.windowShouldClose(sender) ?? true
    }
}

extension YunjianAppDelegate {
    fileprivate func windowShouldClose(_ window: NSWindow) -> Bool {
        if YunjianAppShared.isTerminating {
            return true
        }

        guard let root = YunjianAppShared.root else { return true }
        guard root.activeEditor?.isDirty == true else { return true }

        let alert = NSAlert()
        alert.messageText = L10n.text("closeConfirm.title")
        alert.informativeText = L10n.text("closeConfirm.message")
        alert.addButton(withTitle: L10n.text("common.save"))
        alert.addButton(withTitle: L10n.text("closeConfirm.dontSave"))
        alert.addButton(withTitle: L10n.text("common.cancel"))

        alert.beginSheetModal(for: window) { response in
            switch response {
            case .alertFirstButtonReturn:
                self.requestSaveThenClose(window: window, root: root)
            case .alertSecondButtonReturn:
                Task {
                    await root.closeDocument()
                    window.performClose(nil)
                }
            default:
                break
            }
        }

        return false
    }

    private func requestSaveThenClose(window: NSWindow, root: AppRootViewModel) {
        guard let editor = root.activeEditor else { return }

        if let url = editor.document.fileURL {
            do {
                try editor.document.body.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                return
            }

            Task {
                await root.saveActiveDocument()
                self.noteRecentFile(url, root: root)
                window.performClose(nil)
            }
            return
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = (editor.document.title.isEmpty ? "Untitled" : editor.document.title) + ".md"
        panel.allowedContentTypes = [.plainText]
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            Task {
                let ok = await self.saveEditorToFileURL(url, root: root)
                if ok {
                    self.noteRecentFile(url, root: root)
                    window.performClose(nil)
                }
            }
        }
    }
}
#endif

@main
struct YunjianApp: App {
#if os(macOS)
    @NSApplicationDelegateAdaptor(YunjianAppDelegate.self) private var delegate
#endif
    private let storage: InMemoryStorageService
    private let sync: StubSyncEngine
    private let collab: StubCollaborationEngine

    @State private var root: AppRootViewModel

    init() {
        let seed = [
            Document(title: "欢迎使用云简", body: "# 云简\n\n从这里开始写作。\n")
        ]
        let storage = InMemoryStorageService(seed: seed)
        let sync = StubSyncEngine(storage: storage)
        let collab = StubCollaborationEngine()

        self.storage = storage
        self.sync = sync
        self.collab = collab
        let rootVM = AppRootViewModel(storage: storage, sync: sync, collaboration: collab)
    #if os(macOS)
        YunjianAppShared.root = rootVM
    #endif
        _root = State(initialValue: rootVM)
    }

    var body: some Scene {
        WindowGroup {
            LibraryScreen(root: root)
        }
        .commands {
            YunjianMenuCommands(root: root)
        }

#if os(macOS)
        if #available(macOS 14.0, *) {
            YunjianMenuBarExtra(root: root)
        }
#endif
    }
}
