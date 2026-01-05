import SwiftUI
import YunjianCore

public struct YunjianCommands: Commands {
    private let root: AppRootViewModel

    public init(root: AppRootViewModel) {
        self.root = root
    }

    public var body: some Commands {
        CommandMenu(L10n.text("doc.menu.title")) {
            Button(L10n.text("common.new")) {
                Task { await root.createDocument() }
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button(L10n.text("common.save")) {
                Task { await root.saveActiveDocument() }
            }
            .keyboardShortcut("s", modifiers: [.command])
            .disabled(!root.canSave)

            Button(L10n.text("common.delete")) {
                Task { await root.deleteSelected() }
            }
#if os(macOS)
            .keyboardShortcut(.delete, modifiers: [.command])
#endif
            .disabled(root.selectedDocumentID == nil)

            Divider()

            Menu(L10n.text("doc.menu.openRecent")) {
                if root.recentDocuments.isEmpty {
                    Text(L10n.text("doc.menu.noRecent"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(root.recentDocuments) { doc in
                        Button(doc.title.isEmpty ? L10n.text("library.untitled") : doc.title) {
                            Task { await root.openDocument(id: doc.id) }
                        }
                    }
                }
            }

            if !root.collaborationStatusText.isEmpty {
                Divider()
                Text(L10n.format("doc.menu.status", root.collaborationStatusText))
                    .foregroundStyle(.secondary)
            }
        }

        CommandMenu(L10n.text("sync.menu.title")) {
            Button(L10n.text("sync.menu.syncNow")) {
                Task { await root.syncNow() }
            }
            .keyboardShortcut("r", modifiers: [.command])

            Divider()

            Text(root.syncStateText)
                .foregroundStyle(.secondary)
        }

        CommandMenu(L10n.text("collab.menu.title")) {
            if root.isCollaborationAvailable {
                Button(L10n.text("collab.menu.join")) {
                    Task { await root.joinCollaborationForSelection() }
                }
                .disabled(root.selectedDocumentID == nil || root.isSelectedDocumentJoined)

                Button(L10n.text("collab.menu.leave")) {
                    Task { await root.leaveCollaborationForSelection() }
                }
                .disabled(root.selectedDocumentID == nil || !root.isSelectedDocumentJoined)
            } else {
                Text(L10n.text("collab.menu.unavailable"))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
