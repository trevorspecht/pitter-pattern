import SwiftUI
import PitterCore

@main
struct PitterPatternApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // New windows open at 8.5 × 11 inches (612 × 792 pt) plus room
        // for the zoom bar and padding — the default practice-page view.
        .defaultSize(width: 680, height: 900)
    }
}
