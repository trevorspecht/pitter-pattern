import SwiftUI
import PitterCore

/// Placeholder root view. The real selection/practice UI lands in M3.
/// (App sources are compiled by Xcode only — see TASKS.md environment notes.)
struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note")
                .font(.system(size: 56))
            Text("Pitter Patterns")
                .font(.title.bold())
            Text("Core version: \(PitterCoreInfo.version)")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
