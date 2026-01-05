import SwiftUI
import EditorEngine
import YunjianCore

public struct EditorScreen: View {
    @State private var viewModel: EditorViewModel
    private let fontDelta: Double
    private let highlightCurrentLine: Bool

#if os(macOS)
    @State private var macSelection: NSRange = .init(location: 0, length: 0)
#endif

    public init(viewModel: EditorViewModel, fontDelta: Double = 0) {
        _viewModel = State(initialValue: viewModel)
        self.fontDelta = fontDelta
        self.highlightCurrentLine = false
    }

    public init(viewModel: EditorViewModel, fontDelta: Double = 0, highlightCurrentLine: Bool) {
        _viewModel = State(initialValue: viewModel)
        self.fontDelta = fontDelta
        self.highlightCurrentLine = highlightCurrentLine
    }

    public var body: some View {
        VStack(spacing: 8) {
            TextField(L10n.text("editor.titlePlaceholder"), text: Binding(
                get: { viewModel.document.title },
                set: { viewModel.updateTitle($0) }
            ))
            .textFieldStyle(.roundedBorder)

#if os(macOS)
            MacTextView(
                text: Binding(
                    get: { viewModel.document.body },
                    set: { viewModel.updateBody($0) }
                ),
                selection: $macSelection
                ,
                fontSize: CGFloat(NSFont.systemFontSize + fontDelta),
                highlightCurrentLine: highlightCurrentLine
            )
            .onChange(of: macSelection) { _, newValue in
                viewModel.updateSelection(location: newValue.location, length: newValue.length)
            }
#else
            TextEditor(text: Binding(
                get: { viewModel.document.body },
                set: { viewModel.updateBody($0) }
            ))
            .font(.system(size: 17 + fontDelta, weight: .regular, design: .monospaced))
#endif
        }
        .padding()
        .task {
            // MVP：自动保存策略后续再做。
        }
    }
}
