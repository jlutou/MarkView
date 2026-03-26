import SwiftUI

@main
struct MarkViewApp: App {
    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { config in
            ContentView(document: config.document, fileURL: config.fileURL)
        }
        .defaultSize(width: 860, height: 700)
    }
}
