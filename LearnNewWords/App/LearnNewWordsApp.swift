import SwiftUI
import SwiftData

/// App entry point. UI is managed entirely by AppDelegate via NSStatusItem (menu bar).
/// The Settings scene is required by SwiftUI but has no visible content.
@main
struct LearnNewWordsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main window — this is a menu bar only app (LSUIElement = YES)
        Settings {
            EmptyView()
        }
    }
}
