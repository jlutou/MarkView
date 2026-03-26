import Foundation

enum MarkdownRenderer {

    private static let markedJS: String = {
        guard let url = Bundle.main.url(forResource: "marked.min", withExtension: "js"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return content
    }()

    static func render(_ markdown: String) -> String {
        let json = String(data: (try? JSONEncoder().encode(markdown)) ?? Data("\"\"".utf8), encoding: .utf8) ?? "\"\""

        if markedJS.isEmpty {
            return "<html><body><pre>\(markdown)</pre></body></html>"
        }

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <script>\(markedJS)</script>
        <style>
        \(css)
        </style>
        </head>
        <body>
        <article id="content" class="markdown-body"></article>
        <script>
        marked.setOptions({ gfm: true, breaks: false });
        document.getElementById('content').innerHTML = marked.parse(\(json));
        </script>
        </body>
        </html>
        """
    }

    private static let css = """
    :root {
        --fg: #1f2328;
        --bg: #ffffff;
        --border: #d0d7de;
        --code-bg: #f6f8fa;
        --muted: #59636e;
        --link: #0969da;
    }
    @media (prefers-color-scheme: dark) {
        :root {
            --fg: #e6edf3;
            --bg: #0d1117;
            --border: #30363d;
            --code-bg: #161b22;
            --muted: #8b949e;
            --link: #58a6ff;
        }
    }
    * { box-sizing: border-box; }
    body {
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
        font-size: 16px;
        line-height: 1.6;
        color: var(--fg);
        background: var(--bg);
        max-width: 900px;
        margin: 0 auto;
        padding: 32px;
        word-wrap: break-word;
    }
    h1, h2, h3, h4, h5, h6 {
        margin-top: 24px;
        margin-bottom: 16px;
        font-weight: 600;
        line-height: 1.25;
    }
    h1 { font-size: 2em; border-bottom: 1px solid var(--border); padding-bottom: .3em; }
    h2 { font-size: 1.5em; border-bottom: 1px solid var(--border); padding-bottom: .3em; }
    h3 { font-size: 1.25em; }
    h4 { font-size: 1em; }
    a { color: var(--link); text-decoration: none; }
    a:hover { text-decoration: underline; }
    p { margin: 0 0 16px; }
    code {
        font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
        font-size: 85%;
        background: var(--code-bg);
        padding: .2em .4em;
        border-radius: 6px;
    }
    pre {
        background: var(--code-bg);
        padding: 16px;
        border-radius: 6px;
        overflow: auto;
        line-height: 1.45;
        margin: 0 0 16px;
    }
    pre code { background: none; padding: 0; font-size: 85%; }
    blockquote {
        margin: 0 0 16px;
        padding: 0 1em;
        color: var(--muted);
        border-left: .25em solid var(--border);
    }
    table { border-collapse: collapse; width: 100%; margin: 16px 0; }
    th, td { padding: 6px 13px; border: 1px solid var(--border); }
    th { font-weight: 600; background: var(--code-bg); }
    img { max-width: 100%; height: auto; }
    hr { height: .25em; background: var(--border); border: 0; margin: 24px 0; }
    ul, ol { padding-left: 2em; margin: 0 0 16px; }
    li + li { margin-top: .25em; }
    input[type="checkbox"] { margin-right: .5em; }
    del { color: var(--muted); }
    """
}
