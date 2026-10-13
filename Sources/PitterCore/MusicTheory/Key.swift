/// The mode of a key: major or minor. (Modes beyond these — dorian, etc. —
/// are scale types, not key-signature modes; see the Scale catalog.)
public enum KeyMode: String, CaseIterable, Codable, Sendable, Hashable {
    case major
    case minor
}

/// A tonal key: a tonic spelled as letter + accidental (a key is not a
/// pitch — no octave) plus a major/minor mode.
public struct Key: Hashable, Codable, Sendable {
    public let tonicLetter: Letter
    public let tonicAccidental: Accidental
    public let mode: KeyMode

    /// - Important: only the 15 conventional tonics per mode (circle of
    ///   fifths) are valid; anything else traps. Check with
    ///   `Key.isValid(tonicLetter:tonicAccidental:mode:)` first when the
    ///   tonic comes from user input.
    public init(tonicLetter: Letter, tonicAccidental: Accidental = .natural, mode: KeyMode) {
        precondition(
            Key.isValid(tonicLetter: tonicLetter, tonicAccidental: tonicAccidental, mode: mode),
            "Invalid tonic for \(mode.rawValue) key: "
                + tonicLetter.description + tonicAccidental.description
        )
        self.tonicLetter = tonicLetter
        self.tonicAccidental = tonicAccidental
        self.mode = mode
    }

    /// Convenience: `Key.major(.e, .flat)` → E♭ major.
    public static func major(_ letter: Letter, _ accidental: Accidental = .natural) -> Key {
        Key(tonicLetter: letter, tonicAccidental: accidental, mode: .major)
    }

    /// Convenience: `Key.minor(.f, .sharp)` → F♯ minor.
    public static func minor(_ letter: Letter, _ accidental: Accidental = .natural) -> Key {
        Key(tonicLetter: letter, tonicAccidental: accidental, mode: .minor)
    }

    // MARK: - Validation

    /// True when (letter, accidental, mode) is one of the 15 conventional
    /// tonics on the circle of fifths. Public so callers can validate user
    /// input before constructing (the initializer traps on invalid tonics).
    public static func isValid(
        tonicLetter: Letter, tonicAccidental: Accidental, mode: KeyMode
    ) -> Bool {
        switch mode {
        case .major:
            return majorCircleOfFifths(tonicLetter, tonicAccidental) != nil
        case .minor:
            guard baseAccidentals.contains(tonicAccidental),
                let (relLetter, relAccidental) = relativeMajorTonic(
                    tonicLetter, tonicAccidental)
            else { return false }
            return majorCircleOfFifths(relLetter, relAccidental) != nil
        }
    }

    /// Accidentals a valid key tonic can carry (double accidentals never
    /// appear on the circle of fifths).
    private static let baseAccidentals: Set<Accidental> = [.natural, .sharp, .flat]

    /// Major-key circle of fifths: (tonic, sharpsOrFlats); nil = not a valid
    /// major tonic.
    private static func majorCircleOfFifths(
        _ letter: Letter, _ accidental: Accidental
    ) -> Int? {
        switch (letter, accidental) {
        // Sharp side of the circle.
        case (.c, .natural): return 0
        case (.g, .natural): return 1
        case (.d, .natural): return 2
        case (.a, .natural): return 3
        case (.e, .natural): return 4
        case (.b, .natural): return 5
        case (.f, .sharp): return 6
        case (.c, .sharp): return 7
        // Flat side of the circle.
        case (.f, .natural): return -1
        case (.b, .flat): return -2
        case (.e, .flat): return -3
        case (.a, .flat): return -4
        case (.d, .flat): return -5
        case (.g, .flat): return -6
        case (.c, .flat): return -7
        default: return nil
        }
    }

    /// The relative major tonic of a minor tonic: a minor third above the
    /// minor tonic (letter +2 positions, +3 semitones — exact interval
    /// arithmetic, the accidental is *derived*, not carried along).
    private static func relativeMajorTonic(
        _ letter: Letter, _ accidental: Accidental
    ) -> (Letter, Accidental)? {
        guard baseAccidentals.contains(accidental) else { return nil }
        let shifted = Pitch(letter, accidental, octave: 4).transposed(by: .m3)
        return (shifted.letter, shifted.accidental)
    }

    // MARK: - Descriptions

    /// Tonic without mode, e.g. `"E♭"`, `"F♯"`, `"C"`.
    public var tonicDescription: String {
        let accidentalPart = tonicAccidental == .natural ? "" : tonicAccidental.symbol
        return tonicLetter.description + accidentalPart
    }

    /// Full key name, e.g. `"E♭ major"`, `"F♯ minor"`, `"C major"`.
    public var description: String {
        "\(tonicDescription) \(mode.rawValue)"
    }

    // MARK: - Key signature

    /// The key signature, from the circle of fifths. Minor keys use the
    /// signature of their relative major.
    public var keySignature: KeySignature {
        switch mode {
        case .major:
            return KeySignature(sharpsOrFlats: Key.majorCircleOfFifths(tonicLetter, tonicAccidental)!)
        case .minor:
            let (letter, accidental) = Key.relativeMajorTonic(tonicLetter, tonicAccidental)!
            return KeySignature(sharpsOrFlats: Key.majorCircleOfFifths(letter, accidental)!)
        }
    }

    /// The relative major of a minor key (preconditionFailure on major keys).
    public var relativeMajor: Key {
        precondition(mode == .minor, "Only minor keys have a relative major")
        let (letter, accidental) = Key.relativeMajorTonic(tonicLetter, tonicAccidental)!
        return Key(tonicLetter: letter, tonicAccidental: accidental, mode: .major)
    }

    /// The relative minor of a major key (preconditionFailure on minor keys).
    public var relativeMinor: Key {
        precondition(mode == .major, "Only major keys have a relative minor")
        // A minor third below the tonic (letter −2 positions, −3 semitones).
        let lowered = Pitch(tonicLetter, tonicAccidental, octave: 4)
            .transposed(by: Interval(letterSteps: -2, semitones: -3))
        return Key(tonicLetter: lowered.letter, tonicAccidental: lowered.accidental, mode: .minor)
    }

    /// The accidental this key's signature puts on a letter
    /// (same as `keySignature.accidental(for:)`).
    public func spell(_ letter: Letter) -> Accidental {
        keySignature.accidental(for: letter)
    }
}
