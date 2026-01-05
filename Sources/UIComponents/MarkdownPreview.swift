import SwiftUI
import EditorEngine
import Foundation

#if canImport(WebKit)
import WebKit
#endif

#if canImport(Markdown)
import Markdown
#endif

public struct MarkdownPreview: View {
    private let editor: EditorViewModel

    public init(editor: EditorViewModel) {
        self.editor = editor
    }

    public var body: some View {
        @Bindable var editor = editor

#if canImport(WebKit) && canImport(Markdown)
        let baseDirectory = editor.document.fileURL?.deletingLastPathComponent()
        MarkdownWebView(markdown: editor.document.body, baseDirectory: baseDirectory)
#else
        ScrollView {
            Text(editor.document.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
#endif
    }
}

#if canImport(WebKit) && canImport(Markdown)
private struct MarkdownWebView {
    let markdown: String
    let baseDirectory: URL?
}

extension MarkdownWebView: View {
    var body: some View {
        MarkdownWebViewRepresentable(markdown: markdown, baseDirectory: baseDirectory)
    }
}

private struct MarkdownWebViewRepresentable {
    let markdown: String
    let baseDirectory: URL?
}

#if os(macOS)
extension MarkdownWebViewRepresentable: NSViewRepresentable {
    final class Coordinator {
        var lastHTML: String = ""
        var lastLoadedFileURL: URL?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let view = WKWebView(frame: .zero, configuration: config)
        view.setValue(false, forKey: "drawsBackground")
        view.allowsMagnification = true
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let html = renderHTML(from: markdown, baseDirectory: baseDirectory)
        guard html != context.coordinator.lastHTML else { return }
        context.coordinator.lastHTML = html

        // Load via file URL so WKWebView can render local file:// images.
        // User preference: allow preview to render file:// images from any path.
        let (fileURL, readAccessURL) = writePreviewHTML(html)
        if let fileURL, let readAccessURL {
            context.coordinator.lastLoadedFileURL = fileURL
            nsView.loadFileURL(fileURL, allowingReadAccessTo: readAccessURL)
        } else {
            // Fallback: still show content even if we can't persist the file.
            nsView.loadHTMLString(html, baseURL: nil)
        }
    }

    private func writePreviewHTML(_ html: String) -> (URL?, URL?) {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return (nil, nil)
        }

        let yunjianRoot = appSupport.appendingPathComponent("Yunjian", isDirectory: true)
        let previewDir = yunjianRoot.appendingPathComponent("Preview", isDirectory: true)
        do {
            try fm.createDirectory(at: previewDir, withIntermediateDirectories: true)
        } catch {
            return (nil, nil)
        }

        let fileURL = previewDir.appendingPathComponent("preview.html", isDirectory: false)
        do {
            try html.write(to: fileURL, atomically: true, encoding: .utf8)
            // Allow reading any local images referenced by file:// URLs.
            return (fileURL, URL(fileURLWithPath: "/", isDirectory: true))
        } catch {
            return (nil, nil)
        }
    }
}
#else
extension MarkdownWebViewRepresentable: UIViewRepresentable {
    final class Coordinator {
        var lastHTML: String = ""
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        WKWebView(frame: .zero)
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let html = renderHTML(from: markdown, baseDirectory: baseDirectory)
        guard html != context.coordinator.lastHTML else { return }
        context.coordinator.lastHTML = html
        uiView.loadHTMLString(html, baseURL: baseDirectory)
    }
}
#endif

private func renderHTML(from markdown: String, baseDirectory: URL?) -> String {
    // swift-markdown supports much more syntax than AttributedString(markdown:)
    // and gives us predictable output via HTML.
    let body = HTMLFormatter.format(markdown)
    return wrapHTML(body, baseDirectory: baseDirectory)
}

private func wrapHTML(_ body: String, baseDirectory: URL?) -> String {
    // Keep styling minimal and system-friendly (no hard-coded colors).
    // Let WebKit handle light/dark via color-scheme.
    let css = """
    :root { color-scheme: light dark; }
    body { margin: 16px; font: -apple-system-body; }
    pre, code { font-family: ui-monospace, Menlo, Monaco, SFMono-Regular, monospace; }
    pre { overflow-x: auto; white-space: pre; }
    img { max-width: 100%; height: auto; }
    table { border-collapse: collapse; }
    th, td { padding: 6px 10px; border: 1px solid rgba(127,127,127,0.35); }
    blockquote { margin: 0; padding-left: 12px; border-left: 3px solid rgba(127,127,127,0.35); }
        /* KaTeX tweaks */
        .katex-display { overflow-x: auto; overflow-y: hidden; }
    """

        // External assets (MIT licensed) for better preview fidelity.
        // If you want offline/air-gapped builds, we can vendor these into Resources later.
        let katexCSS = "https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css"
        let katexJS = "https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"
        let katexAutoRenderJS = "https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/contrib/auto-render.min.js"
        let highlightCSS = "https://cdn.jsdelivr.net/npm/highlight.js@11.9.0/styles/github.min.css"
        // Use the full bundle (common languages included). The /lib build is core-only and will not highlight.
        let highlightJS = "https://cdn.jsdelivr.net/npm/highlight.js@11.9.0/highlight.min.js"

        let bootJS = """
        (function() {
            function boot() {
                try {
                    if (window.hljs) { window.hljs.highlightAll(); }
                } catch (e) {}

                try {
                    if (window.renderMathInElement) {
                        window.renderMathInElement(document.body, {
                            delimiters: [
                                { left: "$$", right: "$$", display: true },
                                { left: "$", right: "$", display: false }
                            ],
                            throwOnError: false
                        });
                    }
                } catch (e) {}
            }

            if (document.readyState === "loading") {
                document.addEventListener("DOMContentLoaded", boot);
            } else {
                boot();
            }
        })();
        """

        let baseHref: String = {
                guard let dir = baseDirectory else { return "" }
                let href = URL(fileURLWithPath: dir.path, isDirectory: true).absoluteString
                return "<base href=\"\(href)\" />"
        }()

        return """
    <!doctype html>
    <html>
      <head>
        <meta charset=\"utf-8\" />
        <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
                \(baseHref)
                <link rel=\"stylesheet\" href=\"\(highlightCSS)\" />
                <link rel=\"stylesheet\" href=\"\(katexCSS)\" />
        <style>
        \(css)
        </style>
                <script src=\"\(highlightJS)\"></script>
                <script defer src=\"\(katexJS)\"></script>
                <script defer src=\"\(katexAutoRenderJS)\"></script>
      </head>
      <body>
        \(body)
                <script>
                \(bootJS)
                </script>
      </body>
    </html>
    """
}
#endif
