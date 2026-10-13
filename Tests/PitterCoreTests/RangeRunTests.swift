import Testing
@testable import PitterCore

// Trap paths (start outside bounds, start not in walk, low > high,
// non-terminating stepper) are documented but not trap-tested — neither
// framework can catch preconditionFailure; the happy paths below pin the
// semantics from every direction.

@Suite("RangeRun")
struct RangeRunTests {
    private func scale(_ typeID: String, _ letter: Letter, _ accidental: Accidental = .natural) -> Scale {
        let type = ScaleType.all.first { $0.id == typeID }!
        return Scale(type: type, tonic: Pitch(letter, accidental, octave: 4))
    }

    private let c4 = Pitch(.c, octave: 4)
    private let d4 = Pitch(.d, octave: 4)
    private let e4 = Pitch(.e, octave: 4)
    private let f4 = Pitch(.f, octave: 4)
    private let g4 = Pitch(.g, octave: 4)

    @Test func usersExample() {
        // Upper bound F♯, C major from C4: ascend to F, reflect back down.
        let run = scale("major", .c).boundedRun(from: c4, low: c4, high: Pitch(.f, .sharp, octave: 4))
        #expect(run == [c4, d4, e4, f4, e4, d4, c4])
    }

    @Test func classicFullOctave() {
        let run = scale("major", .c).boundedRun(from: c4, low: c4, high: Pitch(.c, octave: 5))
        #expect(run == [
            c4, d4, e4, f4, g4, Pitch(.a, octave: 4), Pitch(.b, octave: 4),
            Pitch(.c, octave: 5), Pitch(.b, octave: 4), Pitch(.a, octave: 4),
            g4, f4, e4, d4, c4,
        ])
        #expect(run.count == 15)
    }

    @Test func startMidRange() {
        let run = scale("major", .c).boundedRun(
            from: g4, low: c4, high: Pitch(.c, octave: 5))
        #expect(run == [
            g4, Pitch(.a, octave: 4), Pitch(.b, octave: 4), Pitch(.c, octave: 5),
            Pitch(.b, octave: 4), Pitch(.a, octave: 4), g4, f4, e4, d4, c4,
            d4, e4, f4, g4,
        ])
    }

    @Test func boundsNotInScale() {
        // Upper A♭4 → turn at G4; lower C♯4 → tie C/D resolves inside to D4.
        let run = scale("major", .c).boundedRun(
            from: d4, low: Pitch(.c, .sharp, octave: 4), high: Pitch(.a, .flat, octave: 4))
        #expect(run == [d4, e4, f4, g4, f4, e4, d4])
    }

    @Test func inScaleLowerBound() {
        // B3 is in C major and at/above the low bound: the descent goes to it.
        let run = scale("major", .c).boundedRun(
            from: c4, low: Pitch(.b, octave: 3), high: Pitch(.a, .flat, octave: 4))
        #expect(run == [
            c4, d4, e4, f4, g4, f4, e4, d4, c4, Pitch(.b, octave: 3), c4,
        ])
    }

    @Test func tightBounds() {
        let run = scale("major", .c).boundedRun(from: c4, low: c4, high: e4)
        #expect(run == [c4, d4, e4, d4, c4])
    }

    @Test func degenerateSingleNote() {
        let run = scale("major", .c).boundedRun(from: c4, low: c4, high: Pitch(.c, .sharp, octave: 4))
        #expect(run == [c4])
    }

    @Test func chromaticSharpUpFlatDown() {
        let run = scale("chromatic", .c).boundedRun(from: c4, low: c4, high: e4)
        #expect(run == [
            c4, Pitch(.c, .sharp, octave: 4), d4, Pitch(.d, .sharp, octave: 4), e4,
            Pitch(.e, .flat, octave: 4), d4, Pitch(.d, .flat, octave: 4), c4,
        ])
    }

    @Test func bluesAcrossTheGap() {
        let run = scale("blues", .c).boundedRun(from: c4, low: c4, high: g4)
        #expect(run == [
            c4, Pitch(.e, .flat, octave: 4), f4, Pitch(.f, .sharp, octave: 4), g4,
            Pitch(.f, .sharp, octave: 4), f4, Pitch(.e, .flat, octave: 4), c4,
        ])
    }

    @Test func enharmonicStartReanchoring() {
        // D♭4 in A major: the run is anchored to C♯4 and finishes on it.
        let run = scale("major", .a).boundedRun(
            from: Pitch(.d, .flat, octave: 4),
            low: Pitch(.a, octave: 3),
            high: Pitch(.c, .sharp, octave: 5))
        #expect(run.first == Pitch(.c, .sharp, octave: 4))
        #expect(run.last == Pitch(.c, .sharp, octave: 4))
        #expect(run.map(\.midiNumber) == [
            61, 62, 64, 66, 68, 69, 71, 73, 71, 69, 68, 66, 64, 62, 61, 59, 57, 59, 61,
        ])
        // Chromatic starts re-anchor to the ascending spelling and finish on it
        // (the down-phase in between uses flat-side spellings).
        let chromatic = scale("chromatic", .c).boundedRun(
            from: Pitch(.d, .flat, octave: 4),
            low: Pitch(.c, octave: 3),
            high: Pitch(.c, octave: 5))
        #expect(chromatic.first == Pitch(.c, .sharp, octave: 4))
        #expect(chromatic.last == Pitch(.c, .sharp, octave: 4))
    }

    @Test func genericEngineWithMockStepper() {
        // RangeRun.generate directly, with a semitone stepper (up = sharp
        // side, down = flat side) reproduces the chromatic scale run.
        let run = RangeRun.generate(
            from: Pitch(.c, octave: 4),
            bounds: RangeBounds(low: Pitch(.c, octave: 4), high: Pitch(.e, octave: 4)),
            next: { pitch, direction in
                let delta = direction == .up ? 1 : -1
                return Pitch(midiNumber: pitch.midiNumber + delta, preferringSharps: direction == .up)!
            },
            startInWalk: { _ in true }
        )
        #expect(run == [
            Pitch(.c, octave: 4), Pitch(.c, .sharp, octave: 4), Pitch(.d, octave: 4),
            Pitch(.d, .sharp, octave: 4), Pitch(.e, octave: 4), Pitch(.e, .flat, octave: 4),
            Pitch(.d, octave: 4), Pitch(.d, .flat, octave: 4), Pitch(.c, octave: 4),
        ])
    }

    @Test func structuralProperties() {
        let tonics: [(Letter, Accidental)] = [(.c, .natural), (.e, .flat), (.f, .sharp), (.a, .natural)]
        for type in ScaleType.all {
            for (letter, accidental) in tonics {
                let s = Scale(type: type, tonic: Pitch(letter, accidental, octave: 4))
                let low = Pitch(letter, accidental, octave: 3)
                let high = Pitch(letter, accidental, octave: 5)
                let start = s.nextUp(after: s.tonic)  // second degree as start
                let run = s.boundedRun(from: start, low: low, high: high)
                let bounds = RangeBounds(low: low, high: high)

                #expect(run.first == run.last, "\(s.name): run must finish on its start")
                #expect(run.allSatisfy { bounds.contains($0) }, "\(s.name): run stays in bounds")
                #expect(!run.isEmpty)
                // Strictly ascending (by MIDI) until the peak; the tail then
                // descends and climbs back to the start (not monotone — a
                // mid-range start is passed three times, so no count check).
                let midis = run.map(\.midiNumber)
                let peak = midis.firstIndex(of: midis.max()!)!
                let ascent = Array(midis[0...peak])
                #expect(ascent == ascent.sorted(), "\(s.name): up phase ascends")
                // The bottom turn is the minimum after the peak.
                let bottom = midis[peak...].min()!
                #expect(bottom >= low.midiNumber, "\(s.name): bottom turn respects low bound")
            }
        }
    }
}
