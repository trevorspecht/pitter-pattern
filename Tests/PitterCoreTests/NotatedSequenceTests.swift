import Testing
@testable import PitterCore

// Trap paths (dots policy violations, bad time signatures, duration-count
// mismatch, untransposable spellings) are documented but not trap-tested —
// same policy as the other suites. The happy paths below pin the
// construction pipeline: measure filling, barline ties, greedy fragment
// decomposition, rest fill, accidental resolution, and transposition.

@Suite("NotatedSequence")
struct NotatedSequenceTests {
    // MARK: - Helpers

    private func note(
        _ letter: Letter,
        _ accidental: Accidental = .natural,
        octave: Int,
        _ base: NoteDuration.Base,
        dots: Int = 0,
        tied: Bool = false,
        shows: Accidental? = nil
    ) -> NotatedNote {
        NotatedNote(
            sound: .note(Pitch(letter, accidental, octave: octave)),
            duration: NoteDuration(base: base, dots: dots),
            tiedToNext: tied,
            accidental: shows
        )
    }

    private func rest(_ base: NoteDuration.Base, dots: Int = 0) -> NotatedNote {
        NotatedNote(sound: .rest, duration: NoteDuration(base: base, dots: dots), tiedToNext: false)
    }

    private var cMajor44: NotationContext {
        NotationContext(key: .major(.c), timeSignature: .common, clef: .treble)
    }

    // MARK: - NoteDuration

    @Test func durationUnits() {
        #expect(NoteDuration(base: .whole).units == 128)
        #expect(NoteDuration(base: .whole, dots: 1).units == 192)
        #expect(NoteDuration(base: .whole, dots: 2).units == 224)
        #expect(NoteDuration(base: .half).units == 64)
        #expect(NoteDuration(base: .half, dots: 1).units == 96)
        #expect(NoteDuration(base: .half, dots: 2).units == 112)
        #expect(NoteDuration(base: .quarter).units == 32)
        #expect(NoteDuration(base: .quarter, dots: 1).units == 48)
        #expect(NoteDuration(base: .quarter, dots: 2).units == 56)
        #expect(NoteDuration(base: .eighth).units == 16)
        #expect(NoteDuration(base: .eighth, dots: 1).units == 24)
        #expect(NoteDuration(base: .eighth, dots: 2).units == 28)
        #expect(NoteDuration(base: .sixteenth).units == 8)
        #expect(NoteDuration(base: .sixteenth, dots: 1).units == 12)
        #expect(NoteDuration(base: .thirtySecond).units == 4)
    }

    @Test func durationQuarterBeats() {
        #expect(NoteDuration.quarter.quarterBeats == 1.0)
        #expect(NoteDuration(base: .quarter, dots: 1).quarterBeats == 1.5)
        #expect(NoteDuration(base: .eighth, dots: 2).quarterBeats == 0.875)
        #expect(NoteDuration.whole.quarterBeats == 4.0)
    }

    // MARK: - TimeSignature

    @Test func timeSignatureMeasures() {
        #expect(TimeSignature.common.measureUnits == 128)
        #expect(TimeSignature.common.measureBeats == 4.0)
        #expect(TimeSignature(numerator: 3, denominator: 4).measureUnits == 96)
        #expect(TimeSignature(numerator: 6, denominator: 8).measureUnits == 96)
        #expect(TimeSignature(numerator: 6, denominator: 8).measureBeats == 3.0)
        #expect(TimeSignature(numerator: 7, denominator: 8).measureUnits == 112)
        #expect(TimeSignature(numerator: 5, denominator: 4).measureUnits == 160)
        #expect(TimeSignature(numerator: 1, denominator: 32).measureUnits == 4)
        #expect(TimeSignature(numerator: 6, denominator: 8).description == "6/8")
    }

    // MARK: - Measure filling

    @Test func twoFullMeasuresNoFringe() {
        let run: [Pitch] = [
            .init(.c, octave: 4), .init(.d, octave: 4), .init(.e, octave: 4), .init(.f, octave: 4),
            .init(.g, octave: 4), .init(.a, octave: 4), .init(.b, octave: 4), .init(.c, octave: 5),
        ]
        let seq = NotatedSequence(pitches: run, context: cMajor44)
        #expect(seq.measures.count == 2)
        #expect(seq.measures[0] == [
            note(.c, octave: 4, .quarter),
            note(.d, octave: 4, .quarter),
            note(.e, octave: 4, .quarter),
            note(.f, octave: 4, .quarter),
        ])
        #expect(seq.measures[1] == [
            note(.g, octave: 4, .quarter),
            note(.a, octave: 4, .quarter),
            note(.b, octave: 4, .quarter),
            note(.c, octave: 5, .quarter),
        ])
    }

    @Test func defaultDurationIsQuarter() {
        let seq = NotatedSequence(
            pitches: [.init(.c, octave: 4), .init(.d, octave: 4)],
            context: cMajor44
        )
        #expect(seq.measures[0].map(\.duration) == [.quarter, .quarter, .half])
        #expect(seq.measures[0].last == rest(.half)) // fill + default both checked
    }

    @Test func barlineSplitTieAndRestFill() {
        // half C4 then whole C4 in 4/4: the whole splits at the barline.
        let seq = NotatedSequence(
            pitches: [.init(.c, octave: 4), .init(.c, octave: 4)],
            durations: [.half, .whole],
            context: cMajor44
        )
        #expect(seq.measures.count == 2)
        #expect(seq.measures[0] == [
            note(.c, octave: 4, .half),
            note(.c, octave: 4, .half, tied: true),
        ])
        #expect(seq.measures[1] == [
            note(.c, octave: 4, .half),
            rest(.half),
        ])
    }

    @Test func multiMeasureSplitUsesDottedFragments() {
        // quarter then whole in 4/4: the whole leaves a dotted half in
        // measure 1 (greedy exact fill) and a quarter in measure 2.
        let seq = NotatedSequence(
            pitches: [.init(.c, octave: 4), .init(.d, octave: 4)],
            durations: [.quarter, .whole],
            context: cMajor44
        )
        #expect(seq.measures.count == 2)
        #expect(seq.measures[0] == [
            note(.c, octave: 4, .quarter),
            note(.d, octave: 4, .half, dots: 1, tied: true),
        ])
        #expect(seq.measures[1] == [
            note(.d, octave: 4, .quarter),
            rest(.half, dots: 1),
        ])
    }

    @Test func exactFitNeedsNoSplit() {
        // A half note starting on beat 2 of 3/4 fits whole: no tie.
        let seq = NotatedSequence(
            pitches: [.init(.c, octave: 4), .init(.d, octave: 4)],
            durations: [.quarter, .half],
            context: NotationContext(
                key: .major(.c),
                timeSignature: TimeSignature(numerator: 3, denominator: 4),
                clef: .treble
            )
        )
        #expect(seq.measures.count == 1)
        #expect(seq.measures[0] == [
            note(.c, octave: 4, .quarter),
            note(.d, octave: 4, .half),
        ])
    }

    // MARK: - Accidentals in context

    @Test func accidentalsResolvePerMeasureAndSlot() {
        let ebMajor = NotationContext(
            key: .major(.e, .flat),
            timeSignature: .common,
            clef: .treble
        )
        let run: [Pitch] = [
            .init(.e, .flat, octave: 4), .init(.e, .natural, octave: 4),
            .init(.e, .flat, octave: 4), .init(.e, .flat, octave: 4),
            .init(.e, .flat, octave: 4), .init(.e, .flat, octave: 5),
            .init(.a, .natural, octave: 4), .init(.e, .flat, octave: 4),
        ]
        let seq = NotatedSequence(pitches: run, context: ebMajor)
        #expect(seq.measures.count == 2)
        // Measure 1: in key (none) → natural shown → flat shown (deviates
        // from the just-established natural) → matches, none.
        #expect(seq.measures[0].map(\.accidental) == [nil, .natural, .flat, nil])
        // Measure 2: fresh state; E♭5 is a different slot; A♮ deviates
        // from the key's A♭.
        #expect(seq.measures[1].map(\.accidental) == [nil, nil, .natural, nil])
    }

    // MARK: - Transposition

    @Test func transposedForClarinet() {
        let run: [Pitch] = [.init(.c, octave: 4), .init(.e, octave: 4), .init(.g, octave: 4)]
        let seq = NotatedSequence(pitches: run, context: cMajor44)
        let written = seq.transposed(for: .bbClarinet)
        #expect(written.context.key == .major(.d))
        #expect(written.context.timeSignature == .common)
        #expect(written.measures[0] == [
            note(.d, octave: 4, .quarter),
            note(.f, .sharp, octave: 4, .quarter),   // F♯ in key: no glyph
            note(.a, octave: 4, .quarter),
            rest(.quarter),
        ])
        #expect(written.measures[0].map(\.accidental) == [nil, nil, nil, nil])
    }

    @Test func transposedForAltoSax() {
        let run: [Pitch] = [.init(.c, octave: 4), .init(.e, octave: 4), .init(.g, octave: 4)]
        let seq = NotatedSequence(pitches: run, context: cMajor44)
        let written = seq.transposed(for: .altoSax)
        #expect(written.context.key == .major(.a))
        #expect(written.measures[0] == [
            note(.a, octave: 4, .quarter),
            note(.c, .sharp, octave: 5, .quarter),
            note(.e, octave: 5, .quarter),
            rest(.quarter),
        ])
    }

    @Test func transposedAccidentalReResolves() {
        // F♯4 shows a sharp in C major; up a major 6th it becomes D♯5 in
        // A major (D♮ in key) → still shows a sharp.
        let seq = NotatedSequence(pitches: [.init(.f, .sharp, octave: 4)], context: cMajor44)
        #expect(seq.measures[0].first?.accidental == .sharp)
        let written = seq.transposed(for: .altoSax)
        #expect(written.measures[0].first?.accidental == .sharp)
        #expect(written.measures[0].first?.pitch == Pitch(.d, .sharp, octave: 5))
    }

    // MARK: - Rests

    @Test func emptyInputGivesOneRestMeasure() {
        let seq = NotatedSequence(pitches: [], context: cMajor44)
        #expect(seq.measures.count == 1)
        #expect(seq.measures[0] == [rest(.whole)])

        let seq34 = NotatedSequence(
            pitches: [],
            context: NotationContext(
                key: .major(.c),
                timeSignature: TimeSignature(numerator: 3, denominator: 4),
                clef: .treble
            )
        )
        #expect(seq34.measures[0] == [rest(.half, dots: 1)])

        let seq68 = NotatedSequence(
            pitches: [],
            context: NotationContext(
                key: .major(.c),
                timeSignature: TimeSignature(numerator: 6, denominator: 8),
                clef: .treble
            )
        )
        #expect(seq68.measures[0] == [rest(.half, dots: 1)])
    }
}
