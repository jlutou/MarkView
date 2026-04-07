import SwiftUI
import WebKit

struct ContentView: View {
    let document: MarkdownDocument
    let fileURL: URL?

    var body: some View {
        MarkdownWebView(
            markdown: document.text,
            baseURL: fileURL?.deletingLastPathComponent()
        )
    }
}

struct MarkdownWebView: NSViewRepresentable {
    let markdown: String
    let baseURL: URL?
    @Environment(\.colorScheme) private var colorScheme

    class Coordinator {
        var lastMarkdown: String?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        WKWebView()
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)

        guard markdown != context.coordinator.lastMarkdown else { return }
        context.coordinator.lastMarkdown = markdown
        let html = MarkdownRenderer.render(markdown)
        webView.loadHTMLString(html, baseURL: baseURL)
    }
}
