import Foundation
import Markdown
import YunjianCore

public struct MarkdownEngine: Sendable {
    public init() {}

    public func parse(_ source: String) -> Markdown.Document {
        Markdown.Document(parsing: source)
    }

    /// MVP 阶段先保留“渲染占位”能力：
    /// 后续你可以替换为真正的富文本（TextKit 2）管线。
    public func plainTextPreview(_ source: String) -> String {
        // 简化：先返回原文。未来可在此做标题提取、摘要等。
        source
    }
}
