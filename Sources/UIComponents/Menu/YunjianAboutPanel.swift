#if os(macOS)

import AppKit

public enum YunjianAboutPanel {
    public static func show() {
        let intro = """
倬彼云汉，为章于天；执简而书，万舞其韵。

云简，一款凝萃东方书写意韵的 Markdown 编辑器。
化繁为简，以明文心；落键成章，自在从容。
"""

        let author = "He Chenyu, Zhejiang University"
        let credits = NSAttributedString(string: "\(intro)\n\n\(author)\n")

        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .credits: credits
        ])

        NSApp.activate(ignoringOtherApps: true)
    }
}

#endif
