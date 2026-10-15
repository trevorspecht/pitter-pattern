import SwiftUI
import Testing
@testable import PitterCore

// End-to-end smoke test for the T3.1 renderer: StaffView → ImageRenderer →
// pixels. Catches font-registration and drawing-path regressions that the
// pure StaffLayout tests can't see. Also drops /tmp/staff-demo.png for
// eyeballing during development (harmless if the write fails).

@Suite("StaffView rendering")
struct StaffViewRenderingTests {
    private func demoContext() -> NotationContext {
        NotationContext(key: .major(.c), timeSignature: .common, clef: .treble)
    }

    private func demoSequence() -> NotatedSequence {
        let run: [Pitch] = [
            Pitch(.c, octave: 4), Pitch(.e, octave: 4), Pitch(.d, octave: 4), Pitch(.f, octave: 4),
            Pitch(.e, octave: 4), Pitch(.g, octave: 4), Pitch(.f, octave: 4), Pitch(.d, octave: 4),
        ]
        return NotatedSequence(pitches: run, context: demoContext())
    }

    private func darkPixelCount(_ image: NSImage) -> Int? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        var dark = 0
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                if let color = rep.colorAt(x: x, y: y), color.brightnessComponent < 0.5 {
                    dark += 1
                }
            }
        }
        return dark
    }

    @Test @MainActor func rendersInk() throws {
        // pageWidth 1000 at scale 10 keeps the 8-quarter demo on one line.
        let image = try #require(
            ImageRenderer(
                content: StaffPageView(demoSequence(), scale: 10, pageWidth: 1000)
            ).nsImage
        )
        #expect(image.size.width > 200)
        #expect(image.size.height > 60)
        // Staff lines + clef + 8 noteheads/stems ⇒ thousands of dark pixels.
        #expect(try #require(darkPixelCount(image)) > 2000)

        // Orientation probe in the clef's column band (columns 25…55;
        // top staff line at row 60, G line 90, bottom line 100, from the
        // StaffPageView metrics): the curl inks ABOVE the top line, the
        // dense loop INSIDE the staff around the G line, and the tail
        // BELOW the bottom line. A wrong CoreText y-flip would put the
        // loop below the staff instead. (Bands stay away from the page
        // edges so the drop shadow cannot pollute the counts.)
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            Issue.record("no bitmap")
            return
        }
        func ink(xRange: Range<Int>, yRange: Range<Int>) -> Int {
            var count = 0
            for y in yRange {
                for x in xRange where x < rep.pixelsWide && y < rep.pixelsHigh {
                    if let color = rep.colorAt(x: x, y: y), color.brightnessComponent < 0.5 {
                        count += 1
                    }
                }
            }
            return count
        }
        let columns = 25..<56
        let curl = ink(xRange: columns, yRange: 40..<58)      // above the top line
        let loop = ink(xRange: columns, yRange: 60..<99)      // inside the staff
        let tail = ink(xRange: columns, yRange: 102..<118)     // below the bottom line
        #expect(curl > 40, "clef curl should ink above the staff")
        #expect(loop > 300, "clef loop should center in the staff")
        #expect(tail > 40, "clef tail should ink below the staff")
        #expect(loop > curl && loop > tail, "the dense part belongs inside the staff")
    }

    /// Renders the full practice demo (thirds in G major — key signature,
    /// F♯s in the walk, barline tie, ledger lines, final barline) at the
    /// default 100% size — and writes /tmp/staff-demo.png for eyeballing.
    @Test @MainActor func writesDemoPNG() throws {
        let major = ScaleType.all.first { $0.id == "major" }!
        let scale = Scale(type: major, tonic: Pitch(.g, octave: 4))
        let thirds = Pattern.builtIns.first { $0.id == "thirds" }!
        let run = thirds.generate(
            in: scale, from: Pitch(.g, octave: 4),
            low: Pitch(.g, octave: 4), high: Pitch(.g, octave: 5))
        let seq = NotatedSequence(
            pitches: run,
            uniformDuration: .quarter,
            finalDuration: .whole,
            context: NotationContext(key: .major(.g), timeSignature: .common, clef: .treble)
        )
        // The 100% app size: printed-page base × 1.6 screen comfort.
        let pageScale = StaffLayout(seq).defaultScale() * 1.6
        let image = try #require(
            ImageRenderer(content: StaffPageView(seq, scale: pageScale, pageWidth: 620)).nsImage
        )
        #expect(try #require(darkPixelCount(image)) > 1500)
        // Multiple systems: the demo wraps (7 bars do not fit one line
        // at this size — assert more ink bands than one staff can hold
        // via the total staff-line ink: 5 lines × 2+ systems).
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            Issue.record("could not read bitmap")
            return
        }
        var staffLineRows: Set<Int> = []
        for y in 0..<rep.pixelsHigh {
            var dark = 0
            for x in 0..<rep.pixelsWide {
                if let c = rep.colorAt(x: x, y: y), c.brightnessComponent < 0.5 { dark += 1 }
            }
            if dark > rep.pixelsWide / 2 { staffLineRows.insert(y) }
        }
        // Each system has 5 staff lines; 7+ full-width dark rows means at
        // least two systems.
        #expect(staffLineRows.count >= 10, "expected the demo to wrap onto multiple systems")

        guard let png = rep.representation(using: .png, properties: [:]) else {
            Issue.record("could not encode PNG")
            return
        }
        #expect(png.count > 5000)
        try? png.write(to: URL(fileURLWithPath: "/tmp/staff-demo.png"))
    }
}
