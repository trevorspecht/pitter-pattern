import SwiftUI
import PitterCore

/// Placeholder root view: the T3.1 demo page (thirds in C major) with
/// zoom controls, so the renderer and page layout are visible in the app.
/// Replaced by the real selection/practice UI in T3.2.
struct ContentView: View {
    @State private var zoom: CGFloat = 1.0

    private let demo: NotatedSequence = {
        // G major (one sharp) so the key signature renders; thirds from
        // G4 up to the octave.
        let major = ScaleType.all.first { $0.id == "major" }!
        let scale = Scale(type: major, tonic: Pitch(.g, octave: 4))
        let thirds = Pattern.builtIns.first { $0.id == "thirds" }!
        let run = thirds.generate(
            in: scale,
            from: Pitch(.g, octave: 4),
            low: Pitch(.g, octave: 4),
            high: Pitch(.g, octave: 5)
        )
        return NotatedSequence(
            pitches: run,
            uniformDuration: .quarter,
            finalDuration: .whole,
            context: NotationContext(key: .major(.g), timeSignature: .common, clef: .treble)
        )
    }()

    /// Base staff size: printed-page size (4 measures per line on an
    /// 8.5 × 11 / 612 pt page) × 1.6 screen-comfort factor — the printed
    /// size (≈7.5 mm staff) reads small on screens; 1.6× gives ≈12 mm,
    /// the size the user calibrated as the right 100%. The slider zooms
    /// on top of it; window resizing changes only how many bars fit per
    /// line, never the music size.
    private var baseScale: CGFloat {
        CGFloat(StaffLayout(demo).defaultScale() * 1.6)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Zoom")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Slider(
                    value: $zoom,
                    in: 0.6...2.0,
                    minimumValueLabel: Image(systemName: "minus.magnifyingglass"),
                    maximumValueLabel: Image(systemName: "plus.magnifyingglass")
                ) { Text("Zoom") }
                    .frame(width: 260)
                Text("\(Int(zoom * 100))%")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
            .padding(12)

            GeometryReader { geo in
                ScrollView([.vertical]) {
                    StaffPageView(demo, scale: baseScale * zoom, pageWidth: geo.size.width - 32)
                        .padding(16)
                }
            }
        }
        .frame(minWidth: 640, minHeight: 560)
    }
}

#Preview {
    ContentView()
}
