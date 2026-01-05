import SwiftUI

#if os(macOS)

@available(macOS 14.0, *)
public struct YunjianMenuBarExtra: Scene {
    private let root: AppRootViewModel

    public init(root: AppRootViewModel) {
        self.root = root
    }

    public var body: some Scene {
        MenuBarExtra(L10n.text("app.title")) {
            YunjianMenuBarExtraContent(root: root)
        }
    }
}

@available(macOS 14.0, *)
private struct YunjianMenuBarExtraContent: View {
    let root: AppRootViewModel

    var body: some View {
        Text(L10n.format("menubar.syncState", root.syncStateText))

        if !root.collaborationStatusText.isEmpty {
            Text(L10n.format("doc.menu.status", root.collaborationStatusText))
                .foregroundStyle(.secondary)
        }

        Divider()

        Button(L10n.text("common.save")) {
            Task { await root.saveActiveDocument() }
        }
        .disabled(!root.canSave)

        Button(L10n.text("sync.menu.syncNow")) {
            Task { await root.syncNow() }
        }

        if root.isCollaborationAvailable {
            Button(L10n.text("collab.menu.join")) {
                Task { await root.joinCollaborationForSelection() }
            }
            .disabled(root.selectedDocumentID == nil || root.isSelectedDocumentJoined)

            Button(L10n.text("collab.menu.leave")) {
                Task { await root.leaveCollaborationForSelection() }
            }
            .disabled(root.selectedDocumentID == nil || !root.isSelectedDocumentJoined)
        }

        Divider()

        Button(L10n.text("common.new")) {
            Task { await root.createDocument() }
        }
        Button(L10n.text("common.delete")) {
            Task { await root.deleteSelected() }
        }
        .disabled(root.selectedDocumentID == nil)
    }
}

#endif
