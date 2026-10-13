/// Spelled pitches: letter + accidental + octave, in scientific pitch notation
/// (middle C = C4 = MIDI 60).
///
/// Correct *spelling* is the point of this module — everything downstream
/// (key signatures, scale generation, staff rendering, MusicXML) depends on
/// letters and accidentals being right, not just MIDI numbers.
public enum Letter: Int, CaseIterable, Codable, Sendable, Hashable, Comparable {
    case c = 0
    case d = 1
    case e = 2
    case f = 3
    case g = 4
    case a = 5
    case b = 6

    /// Semitones above C for the natural spelling of this letter (C=0 … B=11).
    public var naturalSemitonesFromC: Int {
        switch self {
        case .c: return 0
        case .d: return 2
        case .e: return 4
        case .f: return 5
        case .g: return 7
        case .a: return 9
        case .b: return 11
        }
    }

    /// The next letter up, wrapping B → C.
    public var next: Letter { Letter(rawValue: (rawValue + 1) % 7)! }

    /// The previous letter down, wrapping C → B.
    public var previous: Letter { Letter(rawValue: (rawValue + 6) % 7)! }

    public static func < (lhs: Letter, rhs: Letter) -> Bool { lhs.rawValue < rhs.rawValue }

    public var description: String {
        switch self {
        case .c: return "C"
        case .d: return "D"
        case .e: return "E"
        case .f: return "F"
        case .g: return "G"
        case .a: return "A"
        case .b: return "B"
        }
    }
}

/// An accidental applied to a letter. The raw value is the semitone offset,
/// which keeps double accidentals two steps away from naturals.
public enum Accidental: Int, Codable, Sendable, Hashable, Comparable {
    case doubleFlat = -2
    case flat = -1
    case natural = 0
    case sharp = 1
    case doubleSharp = 2

    /// Semitones of adjustment to the letter's natural pitch.
    public var semitoneOffset: Int { rawValue }

    /// Unicode symbol for display (naturals included).
    public var symbol: String {
        switch self {
        case .doubleFlat: return "♭♭"
        case .flat: return "♭"
        case .natural: return "♮"
        case .sharp: return "♯"
        case .doubleSharp: return "♯♯"
        }
    }

    public static func < (lhs: Accidental, rhs: Accidental) -> Bool { lhs.rawValue < rhs.rawValue }

    /// ASCII form for debugging (`"bb"`, `"b"`, `""`, `"#"`, `"##"`).
    public var description: String {
        switch self {
        case .doubleFlat: return "bb"
        case .flat: return "b"
        case .natural: return ""
        case .sharp: return "#"
        case .doubleSharp: return "##"
        }
    }
}

/// A spelled pitch: a letter with an accidental in a specific octave.
public struct Pitch: Hashable, Codable, Sendable, Comparable {
    public let letter: Letter
    public let accidental: Accidental
    public let octave: Int

    /// - Parameters:
    ///   - letter: the letter name (A–G).
    ///   - accidental: the accidental on the letter (defaults to natural).
    ///   - octave: scientific-pitch octave (middle C is octave 4).
    public init(_ letter: Letter, _ accidental: Accidental = .natural, octave: Int) {
        self.letter = letter
        self.accidental = accidental
        self.octave = octave
    }

    /// Convenience: `Pitch(.c, octave: 4)` etc. read naturally.
    public init(_ letter: Letter, octave: Int) {
        self.init(letter, .natural, octave: octave)
    }

    /// MIDI note number: `12 * (octave + 1) + letterStep + accidentalOffset`.
    /// Middle C (C4) is 60; C♭4 is 59; B♯3 is 60.
    public var midiNumber: Int {
        12 * (octave + 1) + letter.naturalSemitonesFromC + accidental.semitoneOffset
    }

    /// Unicode display form, e.g. `"C♯4"`, `"B♭3"`; naturals show no symbol
    /// (`"C4"`).
    public var description: String {
        let accidentalPart = accidental == .natural ? "" : accidental.symbol
        return letter.description + accidentalPart + String(octave)
    }

    /// ASCII debug form, e.g. `"C#4"`, `"Bb3"`, `"C4"`.
    public var debugDescription: String {
        letter.description + accidental.description + String(octave)
    }

    /// Ordering by sounding pitch (MIDI number); enharmonic ties break by
    /// accidental (flats first, then naturals, then sharps), then by letter.
    public static func < (lhs: Pitch, rhs: Pitch) -> Bool {
        let (l, r) = (lhs.midiNumber, rhs.midiNumber)
        if l != r { return l < r }
        if lhs.accidental != rhs.accidental {
            return lhs.accidental.rawValue < rhs.accidental.rawValue
        }
        return lhs.letter.rawValue < rhs.letter.rawValue
    }

    /// True when both pitches sound the same pitch class in the same octave
    /// (equal MIDI numbers), regardless of spelling.
    public func isEnharmonic(with other: Pitch) -> Bool {
        midiNumber == other.midiNumber
    }

    /// The same spelling, `octaves` higher (or lower for negative values).
    public func shifted(octaves: Int) -> Pitch {
        Pitch(letter, accidental, octave: octave + octaves)
    }

    /// The same accidental, the letter moved `letters` letter positions
    /// (A4 + 2 letters → C5; B3 + 1 letter → C4; D5 − 3 letters → A4).
    /// Octave changes exactly when crossing B→C (in either direction).
    public func shifted(letters: Int) -> Pitch {
        let newIndex = absoluteLetterIndex + letters
        let octave = Self.floorDiv(newIndex, 7)
        let letterRaw = newIndex - octave * 7
        return Pitch(Letter(rawValue: letterRaw)!, accidental, octave: octave)
    }

    /// Transpose by an interval, spelling the result from letter arithmetic
    /// (never from chromatic guessing).
    ///
    /// - Precondition: the transposed spelling must need at most a double
    ///   accidental; otherwise this traps.
    public func transposed(by interval: Interval) -> Pitch {
        let shiftedPitch = shifted(letters: interval.letterSteps)
        let targetMIDI = midiNumber + interval.semitones
        let naturalMIDI = 12 * (shiftedPitch.octave + 1)
            + shiftedPitch.letter.naturalSemitonesFromC
        let offset = targetMIDI - naturalMIDI
        guard let accidental = Accidental(rawValue: offset) else {
            preconditionFailure(
                "Cannot spell \(debugDescription) transposed by \(interval.description): "
                    + "would need \(offset) semitones of accidental."
            )
        }
        return Pitch(shiftedPitch.letter, accidental, octave: shiftedPitch.octave)
    }

    /// Chromatic spelling of any MIDI number 0–127.
    /// - Parameter preferringSharps: sharp side (`C♯ D♯ F♯ G♯ A♯`) when true
    ///   (default), flat side (`D♭ E♭ G♭ A♭ B♭`) when false.
    public init?(midiNumber: Int, preferringSharps: Bool = true) {
        guard (0...127).contains(midiNumber) else { return nil }
        let octave = midiNumber / 12 - 1
        let classWithinOctave = midiNumber % 12
        let sharpSpellings: [(Letter, Accidental)] = [
            (.c, .natural), (.c, .sharp), (.d, .natural), (.d, .sharp), (.e, .natural),
            (.f, .natural), (.f, .sharp), (.g, .natural), (.g, .sharp), (.a, .natural),
            (.a, .sharp), (.b, .natural),
        ]
        let flatSpellings: [(Letter, Accidental)] = [
            (.c, .natural), (.d, .flat), (.d, .natural), (.e, .flat), (.e, .natural),
            (.f, .natural), (.g, .flat), (.g, .natural), (.a, .flat), (.a, .natural),
            (.b, .flat), (.b, .natural),
        ]
        let spelling = (preferringSharps ? sharpSpellings : flatSpellings)[classWithinOctave]
        self.init(spelling.0, spelling.1, octave: octave)
    }

    // MARK: - Letter-index arithmetic

    /// Absolute letter index counting from C0: `octave * 7 + letter position`.
    /// Octave −1 letters have negative indices; floor/mod handled exactly.
    var absoluteLetterIndex: Int { octave * 7 + letter.rawValue }

    /// Floor division (Swift's `/` truncates toward zero, which is wrong for
    /// negative dividends).
    static func floorDiv(_ a: Int, _ b: Int) -> Int {
        let q = a / b
        let r = a % b
        return (r != 0 && (r < 0) != (b < 0)) ? q - 1 : q
    }
}
