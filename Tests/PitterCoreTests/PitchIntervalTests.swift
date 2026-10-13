import Testing
@testable import PitterCore

// swift-testing is pulled as a package dependency because the Command Line
// Tools toolchain (no Xcode.app on this machine) does not ship the `Testing`
// module — see Package.swift.
//
// Trap tests for unspellable transpositions (e.g. C♮ + A5) are not covered —
// swift-testing offers no fatal-error expectation for preconditionFailure —
// but the guard paths are exercised indirectly via the round-trip tests.

@Suite("Letter")
struct LetterTests {
    @Test func naturalSemitonesFromC() {
        #expect(Letter.c.naturalSemitonesFromC == 0)
        #expect(Letter.d.naturalSemitonesFromC == 2)
        #expect(Letter.e.naturalSemitonesFromC == 4)
        #expect(Letter.f.naturalSemitonesFromC == 5)
        #expect(Letter.g.naturalSemitonesFromC == 7)
        #expect(Letter.a.naturalSemitonesFromC == 9)
        #expect(Letter.b.naturalSemitonesFromC == 11)
    }

    @Test func nextAndPreviousWrap() {
        #expect(Letter.b.next == .c)
        #expect(Letter.c.previous == .b)
        #expect(Letter.g.next == .a)
        #expect(Letter.f.previous == .e)
    }

    @Test func descriptions() {
        #expect(Letter.c.description == "C")
        #expect(Letter.b.description == "B")
    }
}

@Suite("Accidental")
struct AccidentalTests {
    @Test func semitoneOffsets() {
        #expect(Accidental.doubleFlat.semitoneOffset == -2)
        #expect(Accidental.flat.semitoneOffset == -1)
        #expect(Accidental.natural.semitoneOffset == 0)
        #expect(Accidental.sharp.semitoneOffset == 1)
        #expect(Accidental.doubleSharp.semitoneOffset == 2)
    }

    @Test func symbolsAndDebugForms() {
        #expect(Accidental.doubleFlat.symbol == "♭♭")
        #expect(Accidental.flat.symbol == "♭")
        #expect(Accidental.natural.symbol == "♮")
        #expect(Accidental.sharp.symbol == "♯")
        #expect(Accidental.doubleSharp.symbol == "♯♯")
        #expect(Accidental.doubleFlat.description == "bb")
        #expect(Accidental.flat.description == "b")
        #expect(Accidental.natural.description == "")
        #expect(Accidental.sharp.description == "#")
        #expect(Accidental.doubleSharp.description == "##")
    }
}

@Suite("Pitch")
struct PitchTests {
    @Test func midiNumbers() {
        #expect(Pitch(.c, octave: 4).midiNumber == 60)
        #expect(Pitch(.a, octave: 4).midiNumber == 69)
        #expect(Pitch(.c, .flat, octave: 4).midiNumber == 59)
        #expect(Pitch(.b, .sharp, octave: 3).midiNumber == 60)
        #expect(Pitch(.a, octave: 0).midiNumber == 21)
        #expect(Pitch(.c, octave: 8).midiNumber == 108)
        #expect(Pitch(.c, .sharp, octave: 4).midiNumber == 61)
        #expect(Pitch(.c, octave: -1).midiNumber == 0)
    }

    @Test func descriptions() {
        #expect(Pitch(.c, .sharp, octave: 4).description == "C♯4")
        #expect(Pitch(.b, .flat, octave: 3).description == "B♭3")
        #expect(Pitch(.c, octave: 4).description == "C4")
        #expect(Pitch(.e, .doubleFlat, octave: 5).description == "E♭♭5")
        #expect(Pitch(.c, .sharp, octave: 4).debugDescription == "C#4")
        #expect(Pitch(.b, .flat, octave: 3).debugDescription == "Bb3")
    }

    @Test func midiInit() {
        #expect(Pitch(midiNumber: 60) == Pitch(.c, octave: 4))
        #expect(Pitch(midiNumber: 61) == Pitch(.c, .sharp, octave: 4))
        #expect(Pitch(midiNumber: 61, preferringSharps: false) == Pitch(.d, .flat, octave: 4))
        #expect(Pitch(midiNumber: 66) == Pitch(.f, .sharp, octave: 4))
        #expect(Pitch(midiNumber: 66, preferringSharps: false) == Pitch(.g, .flat, octave: 4))
        #expect(Pitch(midiNumber: 0) == Pitch(.c, octave: -1))
        #expect(Pitch(midiNumber: 127) == Pitch(.g, octave: 9))
        #expect(Pitch(midiNumber: -1) == nil)
        #expect(Pitch(midiNumber: 128) == nil)
    }

    @Test func shiftedOctaves() {
        #expect(Pitch(.c, octave: 4).shifted(octaves: 1) == Pitch(.c, octave: 5))
        #expect(Pitch(.e, .flat, octave: 4).shifted(octaves: -2) == Pitch(.e, .flat, octave: 2))
    }

    @Test func shiftedLetters() {
        #expect(Pitch(.a, octave: 4).shifted(letters: 2) == Pitch(.c, octave: 5))
        #expect(Pitch(.b, octave: 3).shifted(letters: 1) == Pitch(.c, octave: 4))
        #expect(Pitch(.d, octave: 5).shifted(letters: -3) == Pitch(.a, octave: 4))
        #expect(Pitch(.c, octave: 4).shifted(letters: 7) == Pitch(.c, octave: 5))
        #expect(Pitch(.c, octave: 4).shifted(letters: -1) == Pitch(.b, octave: 3))
        #expect(Pitch(.b, .flat, octave: 2).shifted(letters: 3) == Pitch(.e, .flat, octave: 3))
        #expect(Pitch(.c, octave: 0).shifted(letters: -1) == Pitch(.b, octave: -1))
    }

    @Test func transposedAscending() {
        #expect(Pitch(.c, octave: 4).transposed(by: .M3) == Pitch(.e, octave: 4))
        #expect(Pitch(.f, octave: 4).transposed(by: .M3) == Pitch(.a, octave: 4))
        #expect(Pitch(.c, octave: 4).transposed(by: .P5) == Pitch(.g, octave: 4))
        #expect(Pitch(.b, octave: 4).transposed(by: .P5) == Pitch(.f, .sharp, octave: 5))
        #expect(Pitch(.c, octave: 4).transposed(by: .m6) == Pitch(.a, .flat, octave: 4))
        #expect(Pitch(.d, octave: 4).transposed(by: .augmented(2)) == Pitch(.e, .sharp, octave: 4))
        #expect(Pitch(.c, octave: 4).transposed(by: .diminished(5)) == Pitch(.g, .flat, octave: 4))
        // Strict letter arithmetic: a minor 2nd above E♭ is F♭ (E♮ would
        // be an augmented unison above E♭).
        #expect(Pitch(.e, .flat, octave: 4).transposed(by: .m2) == Pitch(.f, .flat, octave: 4))
        #expect(Pitch(.g, octave: 4).transposed(by: .M7) == Pitch(.f, .sharp, octave: 5))
        #expect(Pitch(.c, octave: 4).transposed(by: .P8) == Pitch(.c, octave: 5))
        #expect(Pitch(.c, octave: 4).transposed(by: .tritone) == Pitch(.f, .sharp, octave: 4))
        #expect(Pitch(.c, octave: 4).transposed(by: .unison) == Pitch(.c, octave: 4))
    }

    @Test func transposedDescending() {
        #expect(Pitch(.e, octave: 4).transposed(by: .major(-3)) == Pitch(.c, octave: 4))
        #expect(Pitch(.c, octave: 4).transposed(by: .minor(-2)) == Pitch(.b, octave: 3))
        #expect(Pitch(.c, octave: 4).transposed(by: .perfect(-5)) == Pitch(.f, octave: 3))
        #expect(Pitch(.b, octave: 4).transposed(by: .major(-3)) == Pitch(.g, octave: 4))
        #expect(Pitch(.a, octave: 4).transposed(by: .minor(-6)) == Pitch(.c, .sharp, octave: 4))
        #expect(
            Pitch(.c, octave: 5).transposed(by: Interval(letterSteps: -7, semitones: -12))
                == Pitch(.c, octave: 4))
    }

    @Test func transpositionRoundTrips() {
        // Up by M3 then down by M3 returns the exact original spelling.
        #expect(
            Pitch(.c, octave: 4)
                .transposed(by: .M3)
                .transposed(by: Interval(letterSteps: -2, semitones: -4))
                == Pitch(.c, octave: 4))
        #expect(
            Pitch(.e, .flat, octave: 4)
                .transposed(by: .m3)
                .transposed(by: Interval(letterSteps: -2, semitones: -3))
                == Pitch(.e, .flat, octave: 4))
        #expect(
            Pitch(.b, .flat, octave: 4)
                .transposed(by: .P8)
                .transposed(by: Interval(letterSteps: -7, semitones: -12))
                == Pitch(.b, .flat, octave: 4))
        // A few more spot round-trips over different starting spellings.
        let starts: [Pitch] = [
            Pitch(.f, .sharp, octave: 3), Pitch(.g, .flat, octave: 5),
            Pitch(.c, .sharp, octave: 2), Pitch(.d, .flat, octave: 6),
        ]
        for start in starts {
            #expect(
                start.transposed(by: .P5).transposed(by: Interval(letterSteps: -4, semitones: -7))
                    == start)
            #expect(
                start.transposed(by: .m2).transposed(by: Interval(letterSteps: -1, semitones: -1))
                    == start)
        }
    }

    @Test func enharmonics() {
        #expect(Pitch(.c, .sharp, octave: 4).isEnharmonic(with: Pitch(.d, .flat, octave: 4)))
        #expect(Pitch(.c, .sharp, octave: 4) != Pitch(.d, .flat, octave: 4))
        #expect(Pitch(.b, .sharp, octave: 3).isEnharmonic(with: Pitch(.c, octave: 4)))
        #expect(!Pitch(.c, .sharp, octave: 4).isEnharmonic(with: Pitch(.d, octave: 4)))
    }

    @Test func ordering() {
        #expect(Pitch(.c, .sharp, octave: 4) < Pitch(.d, octave: 4))
        #expect(Pitch(.d, .flat, octave: 4) < Pitch(.d, octave: 4))
        // Enharmonic ties break by accidental: flats before naturals before sharps.
        #expect(Pitch(.d, .flat, octave: 4) < Pitch(.c, .sharp, octave: 4))
        #expect(Pitch(.b, octave: 3) < Pitch(.c, octave: 4))
        // C♭4 and B3 are both MIDI 59: flat sorts before natural.
        #expect(Pitch(.c, .flat, octave: 4) < Pitch(.b, octave: 3))
    }
}

@Suite("Interval")
struct IntervalTests {
    @Test func standardConstructors() {
        #expect(Interval.perfect(1) == .unison)
        #expect(Interval.major(3) == .M3)
        #expect(Interval.minor(3) == .m3)
        #expect(Interval.perfect(5) == .P5)
        // d5 spans 4 letter steps (C→G♭); 3 letter steps + 6 semitones is A4.
        #expect(Interval.diminished(5) == Interval(letterSteps: 4, semitones: 6))
        #expect(Interval.augmented(4) == Interval(letterSteps: 3, semitones: 6))
        #expect(Interval.diminished(7) == Interval(letterSteps: 6, semitones: 9))
        #expect(Interval.major(7) == .M7)
        #expect(Interval.minor(7) == .m7)
        #expect(Interval.perfect(8) == .P8)
        #expect(Interval.augmented(1) == Interval(letterSteps: 0, semitones: 1))
        #expect(Interval.diminished(1) == Interval(letterSteps: 0, semitones: -1))
    }

    @Test func descendingConstructors() {
        #expect(Interval.major(-3) == Interval(letterSteps: -2, semitones: -4))
        #expect(Interval.minor(-2) == Interval(letterSteps: -1, semitones: -1))
        #expect(Interval.perfect(-5) == Interval(letterSteps: -4, semitones: -7))
        #expect(Interval.diminished(-5) == Interval(letterSteps: -4, semitones: -6))
        #expect(Interval.augmented(-4) == Interval(letterSteps: -3, semitones: -6))
        #expect(Interval.diminished(-7) == Interval(letterSteps: -6, semitones: -9))
        #expect(Interval.major(-3).isDescending)
        #expect(!Interval.M3.isDescending)
        #expect(!Interval.unison.isDescending)
    }

    @Test func qualityDescriptions() {
        #expect(Interval.M3.qualityDescription == "M3")
        #expect(Interval.m2.qualityDescription == "m2")
        #expect(Interval.P5.qualityDescription == "P5")
        #expect(Interval.augmented(4).qualityDescription == "A4")
        #expect(Interval.diminished(7).qualityDescription == "d7")
        #expect(Interval(letterSteps: -5, semitones: -8).qualityDescription == "m6")
        #expect(Interval(letterSteps: -5, semitones: -8).description == "m6 (descending)")
        #expect(Interval.M6.qualityDescription == "M6")
        #expect(Interval.tritone.qualityDescription == "A4")
        #expect(
            Interval(letterSteps: 10, semitones: 17).qualityDescription
                == "(17 semitones over 10 letters)")
    }

    @Test func descriptions() {
        #expect(Interval.M3.description == "M3")
        #expect(Interval.minor(3).description == "m3")
        #expect(Interval.major(-2).description == "M2 (descending)")
    }

    @Test func inverted() {
        // Both components negate — inverting M2 gives a *descending* M2.
        #expect(Interval.M2.inverted == Interval(letterSteps: -1, semitones: -2))
        #expect(Interval.M6.inverted == Interval(letterSteps: -5, semitones: -9))
        #expect(Interval.unison.inverted == .unison)
        #expect(Interval.major(-3).inverted == .M3)
        // Double inversion is the identity, for any interval.
        let samples: [Interval] = [.m3, .P5, .tritone, .major(-7), .augmented(4), .diminished(1)]
        for interval in samples {
            #expect(interval.inverted.inverted == interval)
        }
        // Transposing by an interval and its inverse returns the original spelling.
        let pitch = Pitch(.b, .flat, octave: 4)
        for interval in samples {
            #expect(pitch.transposed(by: interval).transposed(by: interval.inverted) == pitch)
        }
    }
}
