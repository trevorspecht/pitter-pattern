import Foundation

/// Everything the renderer and MusicXML writer need to know about the
/// score as a whole: display key, meter, and clef.
public struct NotationContext: Hashable, Codable, Sendable {
    /// The key the music is notated in (user-chosen; defaults derive from
    /// the generating scale).
    public var key: Key

    public var timeSignature: TimeSignature

    /// The clef the part is drawn in (normally the instrument's default).
    public var clef: Clef

    public init(key: Key, timeSignature: TimeSignature, clef: Clef) {
        self.key = key
        self.timeSignature = timeSignature
        self.clef = clef
    }
}

/// One notated event in a measure: a note (with its display accidental
/// already resolved) or a rest, plus a duration and tie flag.
///
/// `accidental` is the accidental glyph to *draw* (`nil` = none) — not the
/// pitch's own accidental. It is resolved per measure against the key
/// signature and any earlier accidental in the same measure on the same
/// letter and octave. No courtesy accidentals in v1, and tied continuations
/// across a barline are not special-cased (a deviating tied note in a fresh
/// measure shows its accidental — harmless and unambiguous).
public struct NotatedNote: Hashable, Codable, Sendable {
    public enum Sound: Hashable, Codable, Sendable {
        case note(Pitch)
        case rest
    }

    public let sound: Sound

    public let duration: NoteDuration

    /// Tie into the immediately following note (only ever true between
    /// fragments of one original note, by construction).
    public let tiedToNext: Bool

    /// The display accidental to draw, if any; always `nil` for rests.
    public let accidental: Accidental?

    /// Convenience: the sounding pitch, or `nil` for a rest.
    public var pitch: Pitch? {
        if case .note(let pitch) = sound { return pitch }
        return nil
    }

    public init(sound: Sound, duration: NoteDuration, tiedToNext: Bool, accidental: Accidental? = nil) {
        self.sound = sound
        self.duration = duration
        self.tiedToNext = tiedToNext
        self.accidental = accidental
    }

    public var description: String {
        let what: String
        switch sound {
        case .note(let pitch): what = pitch.debugDescription
        case .rest: what = "rest"
        }
        let tie = tiedToNext ? ", tied" : ""
        let acc = accidental.map { ", shows \($0.symbol)" } ?? ""
        return "\(what) (\(duration)\(tie)\(acc))"
    }
}

/// A fully notated single-voice sequence: concrete spelled pitches with
/// durations, broken into measures, with barline ties and display
/// accidentals resolved. Concert pitch is canonical (D2);
/// `transposed(for:)` yields the written-pitch view for a transposing
/// instrument.
///
/// Construction rules (spec `docs/specs/006-notated-sequence.md`):
/// 1. The first note starts on beat 1 of measure 1.
/// 2. A note crossing a barline splits into tied fragments; each measure's
///    chunk is the greedy largest-fit decomposition of the space (dotted
///    values included, double dots excluded). The mod-4 units invariant of
///    `NoteDuration` guarantees this always completes.
/// 3. Display accidentals resolve per measure, per (letter, octave),
///    starting from the key signature.
/// 4. The final measure is filled with untied rests (empty input → one
///    full rest measure).
public struct NotatedSequence: Hashable, Codable, Sendable {
    public let context: NotationContext

    /// Measures of resolved notes; the last measure is rest-filled to full
    /// length.
    public let measures: [[NotatedNote]]

    /// Uniform-duration construction (defaults to quarters). The final
    /// note may get a different duration (`finalDuration`, e.g. `.whole`
    /// for the classic whole-note pattern ending).
    public init(
        pitches: [Pitch],
        uniformDuration: NoteDuration = .quarter,
        finalDuration: NoteDuration? = nil,
        context: NotationContext
    ) {
        var durations = Array(repeating: uniformDuration, count: pitches.count)
        if let finalDuration, !durations.isEmpty {
            durations[durations.count - 1] = finalDuration
        }
        self.init(pitches: pitches, durations: durations, context: context)
    }

    /// Per-note-duration construction.
    public init(pitches: [Pitch], durations: [NoteDuration], context: NotationContext) {
        precondition(
            pitches.count == durations.count,
            "NotatedSequence: \(pitches.count) pitches but \(durations.count) durations"
        )
        self.context = context
        self.measures = Self.build(pitches: pitches, durations: durations, context: context)
    }

    /// The written-pitch view for a transposing instrument: every pitch is
    /// converted concert → written, the context key becomes the written
    /// key, and display accidentals are re-resolved under the new key
    /// signature. Meter, clef, measure structure, rhythm, and ties are
    /// unchanged.
    ///
    /// - Precondition: every spelled pitch must be transposable within a
    ///   double accidental (see `Pitch.transposed(by:)`).
    public func transposed(for instrument: Instrument) -> NotatedSequence {
        let writtenKey = instrument.writtenKey(fromConcert: context.key)
        let newContext = NotationContext(
            key: writtenKey,
            timeSignature: context.timeSignature,
            clef: context.clef
        )
        let signature = writtenKey.keySignature
        let transposedMeasures = measures.map { measure in
            var rewritten: [NotatedNote] = []
            var inEffect: [NoteSlot: Accidental] = [:]
            for note in measure {
                guard case .note(let concert) = note.sound else {
                    rewritten.append(note)
                    continue
                }
                let written = instrument.writtenPitch(fromConcert: concert)
                let slot = NoteSlot(letter: written.letter, octave: written.octave)
                let effective = inEffect[slot] ?? signature.accidental(for: written.letter)
                let display: Accidental? = written.accidental == effective ? nil : written.accidental
                inEffect[slot] = written.accidental
                rewritten.append(
                    NotatedNote(
                        sound: .note(written),
                        duration: note.duration,
                        tiedToNext: note.tiedToNext,
                        accidental: display
                    )
                )
            }
            return rewritten
        }
        return NotatedSequence(context: newContext, measures: transposedMeasures)
    }

    init(context: NotationContext, measures: [[NotatedNote]]) {
        self.context = context
        self.measures = measures
    }

    public var description: String {
        "\(context.timeSignature.description), \(context.key.description), "
            + "\(measures.count) measure\(measures.count == 1 ? "" : "s")"
    }

    // MARK: - Construction

    /// Identity of an accidental slot within a measure: letter + octave.
    private struct NoteSlot: Hashable {
        let letter: Letter
        let octave: Int
    }

    /// Every policy-allowed duration keyed by its (unique) unit count.
    private static let exactDurations: [Int: NoteDuration] = {
        var map: [Int: NoteDuration] = [:]
        for base in NoteDuration.Base.allCases {
            for dots in 0...NoteDuration.maxDots[base]! {
                let duration = NoteDuration(base: base, dots: dots)
                map[duration.units] = duration
            }
        }
        return map
    }()

    /// Greedy decomposition candidates: single-dotted values only, largest
    /// first (192, 128, 96, 64, 48, 32, 24, 16, 12, 8, 4).
    private static let fragmentCandidates: [NoteDuration] =
        exactDurations.values
            .filter { $0.dots <= 1 }
            .sorted { $0.units > $1.units }

    /// Greedy largest-fit decomposition of a measure-space chunk. Total by
    /// the mod-4 invariant: every legal chunk is a positive multiple of 4
    /// and the smallest candidate is 4 units.
    private static func decompose(_ units: Int) -> [NoteDuration] {
        precondition(units > 0 && units % 4 == 0, "Cannot decompose \(units) duration units")
        var fragments: [NoteDuration] = []
        var remaining = units
        while remaining > 0 {
            guard let candidate = fragmentCandidates.first(where: { $0.units <= remaining }) else {
                preconditionFailure("No fragment duration fits \(remaining) units")
            }
            fragments.append(candidate)
            remaining -= candidate.units
        }
        return fragments
    }

    private static func rest(_ duration: NoteDuration) -> NotatedNote {
        NotatedNote(sound: .rest, duration: duration, tiedToNext: false)
    }

    private static func build(
        pitches: [Pitch],
        durations: [NoteDuration],
        context: NotationContext
    ) -> [[NotatedNote]] {
        let measureUnits = context.timeSignature.measureUnits
        let signature = context.key.keySignature

        var measures: [[NotatedNote]] = []
        var current: [NotatedNote] = []
        var used = 0

        func closeMeasure() {
            measures.append(current)
            current = []
            used = 0
        }

        /// Append fragments of a note into the open measure.
        /// `allTied`: every fragment ties on (the note continues into the
        /// next measure); otherwise all but the last fragment tie on.
        func place(_ fragments: [NoteDuration], pitch: Pitch, allTied: Bool) {
            for (index, fragment) in fragments.enumerated() {
                let tied = allTied || index < fragments.count - 1
                current.append(
                    NotatedNote(sound: .note(pitch), duration: fragment, tiedToNext: tied)
                )
                used += fragment.units
            }
        }

        if pitches.isEmpty {
            current = decompose(measureUnits).map(rest)
            closeMeasure()
            return measures.map { resolveAccidentals(in: $0, keySignature: signature) }
        }

        for (pitch, duration) in zip(pitches, durations) {
            var remaining = duration.units
            while remaining > 0 {
                if used == measureUnits { closeMeasure() }
                let space = measureUnits - used
                if remaining <= space {
                    // The tail of the note fits in this measure: one whole
                    // note when the value is exactly notatable, else a
                    // tied chain filling the tail.
                    let fragments = exactDurations[remaining].map { [$0] }
                        ?? decompose(remaining)
                    place(fragments, pitch: pitch, allTied: false)
                    remaining = 0
                } else {
                    // The note crosses the barline: fill the rest of the
                    // measure with tied fragments and carry the leftover.
                    place(decompose(space), pitch: pitch, allTied: true)
                    remaining -= space
                }
            }
        }

        // Close out: the last measure is either exactly full or rest-filled.
        if used == measureUnits {
            closeMeasure()
        } else {
            current += decompose(measureUnits - used).map(rest)
            closeMeasure()
        }

        return measures.map { resolveAccidentals(in: $0, keySignature: signature) }
    }

    /// Resolve display accidentals for one measure against a key signature:
    /// per (letter, octave), the in-effect accidental starts as the key's;
    /// a deviating note shows its own accidental (naturals included) and
    /// updates the state for the rest of the measure.
    private static func resolveAccidentals(
        in measure: [NotatedNote],
        keySignature: KeySignature
    ) -> [NotatedNote] {
        var inEffect: [NoteSlot: Accidental] = [:]
        return measure.map { note in
            guard case .note(let pitch) = note.sound else { return note }
            let slot = NoteSlot(letter: pitch.letter, octave: pitch.octave)
            let effective = inEffect[slot] ?? keySignature.accidental(for: pitch.letter)
            let display: Accidental? = pitch.accidental == effective ? nil : pitch.accidental
            inEffect[slot] = pitch.accidental
            return NotatedNote(
                sound: note.sound,
                duration: note.duration,
                tiedToNext: note.tiedToNext,
                accidental: display
            )
        }
    }
}
