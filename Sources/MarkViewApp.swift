import SwiftUI
import WebKit
import UniformTypeIdentifiers

@main
struct MarkViewApp: App {
    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { config in
            ContentView(document: config.document, fileURL: config.fileURL)
        }
        .defaultSize(width: 860, height: 700)
        .commands {
            PDFCommands()
        }
    }
}

struct PDFCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Divider()

            Button("Export as PDF…") {
                guard let (webView, title) = activeWebView() else { return }
                exportPDF(from: webView, name: title)
            }
            .keyboardShortcut("e", modifiers: [.command])

            Button("Print…") {
                guard let (webView, _) = activeWebView() else { return }
                printDocument(from: webView)
            }
            .keyboardShortcut("p", modifiers: [.command])
        }
    }

    private func activeWebView() -> (WKWebView, String)? {
        guard let window = NSApplication.shared.keyWindow else { return nil }
        guard let webView = findWebView(in: window.contentView) else { return nil }
        let title = window.title.isEmpty ? "document" : window.title
            .replacingOccurrences(of: ".md", with: "")
            .replacingOccurrences(of: ".markdown", with: "")
        return (webView, title)
    }

    private func findWebView(in view: NSView?) -> WKWebView? {
        guard let view else { return nil }
        if let wk = view as? WKWebView { return wk }
        for sub in view.subviews {
            if let found = findWebView(in: sub) { return found }
        }
        return nil
    }

    private func exportPDF(from webView: WKWebView, name: String) {
        webView.createPDF(configuration: .init()) { result in
            DispatchQueue.main.async {
                guard case .success(let data) = result else { return }
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.pdf]
                panel.nameFieldStringValue = name + ".pdf"
                guard panel.runModal() == .OK, let url = panel.url else { return }
                try? data.write(to: url)
            }
        }
    }

    private func printDocument(from webView: WKWebView) {
        let printInfo = NSPrintInfo.shared
        printInfo.topMargin = 36
        printInfo.bottomMargin = 36
        printInfo.leftMargin = 36
        printInfo.rightMargin = 36
        let op = webView.printOperation(with: printInfo)
        op.showsPrintPanel = true
        op.showsProgressPanel = true
        op.run()
    }
}
