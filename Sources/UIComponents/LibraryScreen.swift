import SwiftUI
import EditorEngine
import YunjianCore

public struct LibraryScreen: View {
    @State private var root: AppRootViewModel

    public init(root: AppRootViewModel) {
        _root = State(initialValue: root)
    }

    public var body: some View {
        @Bindable var root = root
        NavigationSplitView {
            List(selection: $root.selectedDocumentID) {
#if os(macOS)
                if !root.recentFileURLs.isEmpty {
                    Section(L10n.text("sidebar.recentFiles")) {
                        ForEach(root.recentFileURLs, id: \.self) { url in
                            Button(url.lastPathComponent) {
                                root.openRecentFile(url: url)
                            }
                        }
                    }
                }
#endif

                Section(L10n.text("sidebar.documents")) {
                ForEach(root.documents) { doc in
                    Text(doc.title.isEmpty ? L10n.text("library.untitled") : doc.title)
                        .tag(doc.id)
                }
                }
            }
            .toolbar {
                Button(L10n.text("common.new")) { Task { await root.createDocument() } }
                Button(L10n.text("common.delete")) { Task { await root.deleteSelected() } }
            }
            .task { await root.load() }
            .onChange(of: root.selectedDocumentID) { _, _ in
                Task { await root.openSelectedDocumentIfNeeded() }
            }
        } detail: {
            if root.isLoadingEditor {
                ProgressView()
            } else if let editorVM = root.activeEditor {
                Group {
                    switch root.editorPresentation {
                    case .editor:
                        EditorScreen(viewModel: editorVM, fontDelta: root.editorFontDelta, highlightCurrentLine: root.highlightCurrentLine)
                    case .preview:
                        MarkdownPreview(editor: editorVM)
                    case .split:
                        HStack(spacing: 0) {
                            EditorScreen(viewModel: editorVM, fontDelta: root.editorFontDelta, highlightCurrentLine: root.highlightCurrentLine)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            Divider()
                            MarkdownPreview(editor: editorVM)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
                .toolbar {
                    Button(L10n.text("common.save")) {
                        Task { await root.saveActiveDocument() }
                    }
                    .disabled(!root.canSave)
                }
            } else {
                HomeView()
            }
        }
        .sheet(isPresented: $root.isDocumentAttributesPresented) {
            if let doc = root.activeEditor?.document {
                DocumentAttributesView(document: doc)
            } else {
                HomeView()
            }
        }
        .sheet(isPresented: $root.isImageUploadPresented) {
            ImageUploadSheet(root: root)
        }
    }
}

private struct HomeView: View {
    var body: some View {
        VStack(spacing: 10) {
            Text(L10n.text("app.title"))
                .font(.largeTitle)
                .bold()
            Text(L10n.text("home.subtitle"))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
