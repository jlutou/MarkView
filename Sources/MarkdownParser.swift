import Foundation

/// Pure Swift markdown-to-HTML converter (no JS dependencies).
/// Handles GFM: headers, bold, italic, strikethrough, code, links, images,
/// lists, blockquotes, tables, task lists, horizontal rules.
enum MarkdownParser {

    static func toHTML(_ input: String) -> String {
        let lines = input.components(separatedBy: "\n")
        return parseBlocks(lines, from: 0, to: lines.count).html
    }

    // MARK: - Block parsing

    private struct ParseResult {
        let html: String
        let consumed: Int
    }

    private static func parseBlocks(_ lines: [String], from start: Int, to end: Int) -> ParseResult {
        var parts: [String] = []
        var i = start

        while i < end {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Empty line
            if trimmed.isEmpty { i += 1; continue }

            // Fenced code block
            if trimmed.hasPrefix("```") {
                let r = parseFencedCode(lines, from: i, to: end)
                parts.append(r.html); i += r.consumed; continue
            }

            // Heading
            if let r = parseHeading(trimmed) {
                parts.append(r); i += 1; continue
            }

            // HR
            if isHR(trimmed) {
                parts.append("<hr>"); i += 1; continue
            }

            // Table
            if i + 1 < end && isTableSep(lines[i + 1].trimmingCharacters(in: .whitespaces)) {
                let r = parseTable(lines, from: i, to: end)
                parts.append(r.html); i += r.consumed; continue
            }

            // Blockquote
            if trimmed.hasPrefix(">") {
                let r = parseBlockquote(lines, from: i, to: end)
                parts.append(r.html); i += r.consumed; continue
            }

            // Unordered list
            if isUL(trimmed) {
                let r = parseList(lines, from: i, to: end, ordered: false)
                parts.append(r.html); i += r.consumed; continue
            }

            // Ordered list
            if isOL(trimmed) {
                let r = parseList(lines, from: i, to: end, ordered: true)
                parts.append(r.html); i += r.consumed; continue
            }

            // Paragraph
            let r = parseParagraph(lines, from: i, to: end)
            parts.append(r.html); i += r.consumed
        }

        return ParseResult(html: parts.joined(separator: "\n"), consumed: end - start)
    }

    // MARK: Fenced code

    private static func parseFencedCode(_ lines: [String], from start: Int, to end: Int) -> ParseResult {
        let first = lines[start].trimmingCharacters(in: .whitespaces)
        let lang = String(first.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        let cls = lang.isEmpty ? "" : " class=\"language-\(esc(lang))\""
        var code: [String] = []
        var i = start + 1
        while i < end {
            if lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") { i += 1; break }
            code.append(esc(lines[i]))
            i += 1
        }
        return ParseResult(html: "<pre><code\(cls)>\(code.joined(separator: "\n"))</code></pre>", consumed: i - start)
    }

    // MARK: Heading

    private static func parseHeading(_ line: String) -> String? {
        guard line.hasPrefix("#") else { return nil }
        var level = 0
        for c in line { if c == "#" { level += 1 } else { break } }
        guard level >= 1 && level <= 6 && line.count > level && line[line.index(line.startIndex, offsetBy: level)] == " " else { return nil }
        let text = String(line.dropFirst(level + 1))
        return "<h\(level)>\(inline(text))</h\(level)>"
    }

    // MARK: HR

    private static func isHR(_ line: String) -> Bool {
        let s = line.replacingOccurrences(of: " ", with: "")
        return s.count >= 3 && (s.allSatisfy { $0 == "-" } || s.allSatisfy { $0 == "*" } || s.allSatisfy { $0 == "_" })
    }

    // MARK: Table

    private static func isTableSep(_ line: String) -> Bool {
        guard line.contains("|") && line.contains("-") else { return false }
        let cells = splitTableRow(line)
        return cells.allSatisfy { $0.trimmingCharacters(in: .whitespaces).range(of: "^:?-{1,}:?$", options: .regularExpression) != nil }
    }

    private static func splitTableRow(_ line: String) -> [String] {
        var s = line.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("|") { s = String(s.dropFirst()) }
        if s.hasSuffix("|") { s = String(s.dropLast()) }
        return s.components(separatedBy: "|")
    }

    private static func parseTable(_ lines: [String], from start: Int, to end: Int) -> ParseResult {
        let headers = splitTableRow(lines[start])
        // skip separator line
        var rows: [[String]] = []
        var i = start + 2
        while i < end {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            guard trimmed.contains("|") && !trimmed.isEmpty else { break }
            rows.append(splitTableRow(lines[i]))
            i += 1
        }

        var html = "<table>\n<thead><tr>"
        for h in headers { html += "<th>\(inline(h.trimmingCharacters(in: .whitespaces)))</th>" }
        html += "</tr></thead>\n<tbody>\n"
        for row in rows {
            html += "<tr>"
            for cell in row { html += "<td>\(inline(cell.trimmingCharacters(in: .whitespaces)))</td>" }
            html += "</tr>\n"
        }
        html += "</tbody>\n</table>"
        return ParseResult(html: html, consumed: i - start)
    }

    // MARK: Blockquote

    private static func parseBlockquote(_ lines: [String], from start: Int, to end: Int) -> ParseResult {
        var inner: [String] = []
        var i = start
        while i < end {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("> ") {
                inner.append(String(trimmed.dropFirst(2)))
            } else if trimmed.hasPrefix(">") {
                inner.append(String(trimmed.dropFirst(1)))
            } else if trimmed.isEmpty && !inner.isEmpty {
                // Check if next line continues the blockquote
                if i + 1 < end && lines[i + 1].trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                    inner.append("")
                } else { break }
            } else { break }
            i += 1
        }
        let content = parseBlocks(inner, from: 0, to: inner.count).html
        return ParseResult(html: "<blockquote>\n\(content)\n</blockquote>", consumed: i - start)
    }

    // MARK: Lists

    private static func isUL(_ line: String) -> Bool {
        line.range(of: "^\\s*[-*+] ", options: .regularExpression) != nil
    }

    private static func isOL(_ line: String) -> Bool {
        line.range(of: "^\\s*\\d+[.)] ", options: .regularExpression) != nil
    }

    private static func listItemText(_ line: String, ordered: Bool) -> String {
        if ordered {
            if let r = line.range(of: "^\\s*\\d+[.)] ", options: .regularExpression) {
                return String(line[r.upperBound...])
            }
        } else {
            if let r = line.range(of: "^\\s*[-*+] ", options: .regularExpression) {
                return String(line[r.upperBound...])
            }
        }
        return line
    }

    private static func parseList(_ lines: [String], from start: Int, to end: Int, ordered: Bool) -> ParseResult {
        let tag = ordered ? "ol" : "ul"
        var items: [String] = []
        var i = start

        while i < end {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { i += 1; continue }
            let matches = ordered ? isOL(trimmed) : isUL(trimmed)
            guard matches else { break }

            var text = listItemText(trimmed, ordered: ordered)

            // Task list
            var checkbox = ""
            if text.hasPrefix("[ ] ") {
                checkbox = "<input type=\"checkbox\" disabled> "
                text = String(text.dropFirst(4))
            } else if text.hasPrefix("[x] ") || text.hasPrefix("[X] ") {
                checkbox = "<input type=\"checkbox\" checked disabled> "
                text = String(text.dropFirst(4))
            }

            items.append("<li>\(checkbox)\(inline(text))</li>")
            i += 1
        }

        return ParseResult(html: "<\(tag)>\n\(items.joined(separator: "\n"))\n</\(tag)>", consumed: i - start)
    }

    // MARK: Paragraph

    private static func parseParagraph(_ lines: [String], from start: Int, to end: Int) -> ParseResult {
        var text: [String] = []
        var i = start
        while i < end {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { i += 1; break }
            if trimmed.hasPrefix("#") || trimmed.hasPrefix("```") || trimmed.hasPrefix(">") || isHR(trimmed) { break }
            if isUL(trimmed) || isOL(trimmed) { break }
            if i + 1 < end && isTableSep(lines[i + 1].trimmingCharacters(in: .whitespaces)) { break }
            text.append(trimmed)
            i += 1
        }
        if text.isEmpty { return ParseResult(html: "", consumed: 1) }
        return ParseResult(html: "<p>\(inline(text.joined(separator: " ")))</p>", consumed: i - start)
    }

    // MARK: - Inline parsing

    static func inline(_ text: String) -> String {
        var s = text

        // Protect code spans
        var codes: [String] = []
        while let range = s.range(of: "`[^`]+`", options: .regularExpression) {
            let match = String(s[range])
            let code = esc(String(match.dropFirst().dropLast()))
            let placeholder = "\u{0000}CODE\(codes.count)\u{0000}"
            codes.append("<code>\(code)</code>")
            s.replaceSubrange(range, with: placeholder)
        }

        // Escape HTML in remaining text
        s = esc(s)

        // Images (before links)
        s = regReplace(s, "!\\[([^\\]]*)\\]\\(([^)]+)\\)") { m in
            "<img src=\"\(m[2])\" alt=\"\(m[1])\">"
        }

        // Links
        s = regReplace(s, "\\[([^\\]]*)\\]\\(([^)]+)\\)") { m in
            "<a href=\"\(m[2])\">\(m[1])</a>"
        }

        // Bold
        s = regReplace(s, "\\*\\*(.+?)\\*\\*") { "<strong>\($0[1])</strong>" }
        s = regReplace(s, "__(.+?)__") { "<strong>\($0[1])</strong>" }

        // Italic
        s = regReplace(s, "\\*(.+?)\\*") { "<em>\($0[1])</em>" }
        s = regReplace(s, "(?<![\\w])_(.+?)_(?![\\w])") { "<em>\($0[1])</em>" }

        // Strikethrough
        s = regReplace(s, "~~(.+?)~~") { "<del>\($0[1])</del>" }

        // Restore code spans
        for (i, code) in codes.enumerated() {
            s = s.replacingOccurrences(of: "\u{0000}CODE\(i)\u{0000}", with: code)
        }

        return s
    }

    // MARK: - Helpers

    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func regReplace(_ input: String, _ pattern: String, _ replacement: ([String]) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return input }
        var result = input
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed()
        for match in matches {
            var groups: [String] = []
            for g in 0..<match.numberOfRanges {
                if let r = Range(match.range(at: g), in: result) {
                    groups.append(String(result[r]))
                } else {
                    groups.append("")
                }
            }
            if let r = Range(match.range, in: result) {
                result.replaceSubrange(r, with: replacement(groups))
            }
        }
        return result
    }
}
