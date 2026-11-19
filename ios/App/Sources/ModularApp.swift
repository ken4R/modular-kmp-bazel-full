import SharedKit
import SwiftUI

@main
struct ModularApp: App {

    /// Composition root of the shared code: one instance for the whole application.
    private let graph = SharedGraph()

    var body: some Scene {
        WindowGroup {
            RootView(graph: graph)
        }
    }
}
