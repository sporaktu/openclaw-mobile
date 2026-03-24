import SwiftUI

/// Simple markdown text renderer that handles bold, italic, inline code,
/// code blocks, and links without external dependencies.
struct MarkdownText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        let blocks = parseBlocks(text)
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .codeBlock(let code):
                    codeBlockView(code)
                case .text(let line):
                    inlineMarkdownText(line)
                }
            }
        }
    }

    // MARK: - Code Block View

    private func codeBlockView(_ code: String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(code)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)
                .textSelection(.enabled)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "0d1117"))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius))
    }

    // MARK: - Inline Markdown

    private func inlineMarkdownText(_ input: String) -> Text {
        // Try Swift's built-in markdown AttributedString first
        if let attributed = try? AttributedString(markdown: input, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return Text(attributed)
                .font(AppTheme.bodyFont)
        }
        // Fallback: plain text
        return Text(input)
            .font(AppTheme.bodyFont)
    }

    // MARK: - Block Parsing

    private enum Block {
        case text(String)
        case codeBlock(String)
    }

    private func parseBlocks(_ input: String) -> [Block] {
        var blocks: [Block] = []
        var lines = input.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]
            if line.hasPrefix("```") {
                // Start of code block
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                // Skip closing ```
                if i < lines.count { i += 1 }
                blocks.append(.codeBlock(codeLines.joined(separator: "\n")))
            } else {
                // Collect consecutive text lines
                var textLines: [String] = []
                while i < lines.count && !lines[i].hasPrefix("```") {
                    textLines.append(lines[i])
                    i += 1
                }
                let combined = textLines.joined(separator: "\n")
                if !combined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    blocks.append(.text(combined))
                }
            }
        }

        if blocks.isEmpty {
            blocks.append(.text(input))
        }
        return blocks
    }
}

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            MarkdownText("This is **bold** and *italic* text with `inline code`.")

            MarkdownText("Here is a [link](https://example.com) in text.")

            MarkdownText("""
            Some code:

            ```swift
            let greeting = "Hello"
            print(greeting)
            ```

            And more text after.
            """)
        }
        .padding()
    }
    .background(AppTheme.background)
}
