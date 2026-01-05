import SwiftUI
import StorageService
import SyncEngine
import UIComponents
import YunjianCore

#if os(macOS)
import AppKit

final class YunjianDevAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
#endif

@main
struct YunjianDevApp: App {
#if os(macOS)
    @NSApplicationDelegateAdaptor(YunjianDevAppDelegate.self) private var delegate
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
        _root = State(initialValue: AppRootViewModel(storage: storage, sync: sync, collaboration: collab))
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
