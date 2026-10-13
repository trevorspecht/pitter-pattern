/// One degree of a scale's spelling template.
public struct ScaleDegree: Hashable, Codable, Sendable {
    /// Letter positions above the tonic letter (0 = the tonic letter). May
    /// repeat across degrees (e.g. whole-half diminished has two "A" degrees).
    public let letterOffset: Int

    /// Semitones above the tonic.
    public let semitones: Int

    public init(letterOffset: Int, semitones: Int) {
        self.letterOffset = letterOffset
        self.semitones = semitones
    }
}

/// How a scale type spells itself from a tonic.
public enum SpellingStrategy: Hashable, Codable, Sendable {
    /// A fixed letter/semitone template that works from any tonic.
    case template([ScaleDegree])
    /// The chromatic scale, whose letter pattern depends on where the E→F /
    /// B→C semitone gaps fall relative to the tonic letter. Ascending runs
    /// spell sharps; descending runs spell flats (mirror rule).
    case chromatic
}

/// Filter buckets used by the catalog and the UI's category filter.
public enum ScaleCategory: String, CaseIterable, Codable, Sendable, Hashable {
    case major
    case minor
    case modal
    case symmetric
    case chromatic
    case pentatonic
    case blues

    public var description: String {
        switch self {
        case .major: return "Major"
        case .minor: return "Minor"
        case .modal: return "Modal"
        case .symmetric: return "Symmetric"
        case .chromatic: return "Chromatic"
        case .pentatonic: return "Pentatonic"
        case .blues: return "Blues"
        }
    }
}

/// A kind of scale (major, dorian, whole tone, …), independent of any tonic.
public struct ScaleType: Hashable, Codable, Sendable, Identifiable {
    /// Stable slug identifier, e.g. `"major"`, `"harmonic-minor"`.
    public let id: String

    /// Display name, e.g. `"Harmonic Minor"`.
    public let name: String

    public let category: ScaleCategory

    public let spelling: SpellingStrategy

    /// Letter steps from the tonic letter to the *parent major key's* tonic
    /// letter, keeping the tonic's accidental (mod 7). Drives key-signature
    /// display; nil = fallback policy (see `Scale.keySignatureRoot`).
    public let parentMajorLetterOffset: Int?

    public init(
        id: String,
        name: String,
        category: ScaleCategory,
        spelling: SpellingStrategy,
        parentMajorLetterOffset: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.spelling = spelling
        self.parentMajorLetterOffset = parentMajorLetterOffset
    }

    /// Convenience for template scales. Degree 0 must be the tonic
    /// `(letterOffset: 0, semitones: 0)`.
    public init(
        id: String,
        name: String,
        category: ScaleCategory,
        degrees: [ScaleDegree],
        parentMajorLetterOffset: Int? = nil
    ) {
        precondition(
            degrees.first == ScaleDegree(letterOffset: 0, semitones: 0),
            "Scale \(id): degree 0 must be the tonic (letterOffset 0, semitones 0)"
        )
        self.init(
            id: id,
            name: name,
            category: category,
            spelling: .template(degrees),
            parentMajorLetterOffset: parentMajorLetterOffset
        )
    }

    /// The template degrees, or nil for non-template strategies.
    public var templateDegrees: [ScaleDegree]? {
        if case .template(let degrees) = spelling { return degrees }
        return nil
    }

    /// The number of distinct pitch classes per octave cycle (12 for chromatic).
    public var degreesPerOctave: Int {
        switch spelling {
        case .template(let degrees): return degrees.count
        case .chromatic: return 12
        }
    }

    // MARK: - Built-in catalog

    /// The built-in scale catalog (spec 003 tables, exact).
    public static let all: [ScaleType] = [
        ScaleType(id: "major", name: "Major", category: .major,
                  degrees: majorDegrees, parentMajorLetterOffset: 0),
        ScaleType(id: "natural-minor", name: "Natural Minor", category: .minor,
                  degrees: naturalMinorDegrees, parentMajorLetterOffset: 2),
        ScaleType(id: "harmonic-minor", name: "Harmonic Minor", category: .minor,
                  degrees: harmonicMinorDegrees, parentMajorLetterOffset: 2),
        ScaleType(id: "melodic-minor", name: "Melodic Minor", category: .minor,
                  degrees: melodicMinorDegrees, parentMajorLetterOffset: 2),
        ScaleType(id: "ionian", name: "Ionian", category: .modal,
                  degrees: majorDegrees, parentMajorLetterOffset: 0),
        ScaleType(id: "dorian", name: "Dorian", category: .modal,
                  degrees: dorianDegrees, parentMajorLetterOffset: -1),
        ScaleType(id: "phrygian", name: "Phrygian", category: .modal,
                  degrees: phrygianDegrees, parentMajorLetterOffset: -2),
        ScaleType(id: "lydian", name: "Lydian", category: .modal,
                  degrees: lydianDegrees, parentMajorLetterOffset: -3),
        ScaleType(id: "mixolydian", name: "Mixolydian", category: .modal,
                  degrees: mixolydianDegrees, parentMajorLetterOffset: -4),
        ScaleType(id: "aeolian", name: "Aeolian (Natural Minor)", category: .modal,
                  degrees: naturalMinorDegrees, parentMajorLetterOffset: 2),
        ScaleType(id: "locrian", name: "Locrian", category: .modal,
                  degrees: locrianDegrees, parentMajorLetterOffset: -6),
        ScaleType(id: "whole-tone", name: "Whole Tone", category: .symmetric,
                  degrees: wholeToneDegrees),
        ScaleType(id: "whole-half-diminished", name: "Whole-Half Diminished",
                  category: .symmetric, degrees: wholeHalfDegrees),
        ScaleType(id: "half-whole-diminished", name: "Half-Whole Diminished",
                  category: .symmetric, degrees: halfWholeDegrees),
        ScaleType(id: "chromatic", name: "Chromatic", category: .chromatic,
                  spelling: .chromatic),
        ScaleType(id: "major-pentatonic", name: "Major Pentatonic",
                  category: .pentatonic, degrees: majorPentatonicDegrees,
                  parentMajorLetterOffset: 0),
        ScaleType(id: "minor-pentatonic", name: "Minor Pentatonic",
                  category: .pentatonic, degrees: minorPentatonicDegrees,
                  parentMajorLetterOffset: 2),
        ScaleType(id: "blues", name: "Blues", category: .blues,
                  degrees: bluesDegrees, parentMajorLetterOffset: 2),
    ]

    // MARK: - Degree tables (spec 003, exact)

    private static let majorDegrees: [ScaleDegree] = [
        ScaleDegree(letterOffset: 0, semitones: 0),
        ScaleDegree(letterOffset: 1, semitones: 2),
        ScaleDegree(letterOffset: 2, semitones: 4),
        ScaleDegree(letterOffset: 3, semitones: 5),
        ScaleDegree(letterOffset: 4, semitones: 7),
        ScaleDegree(letterOffset: 5, semitones: 9),
        ScaleDegree(letterOffset: 6, semitones: 11),
    ]

    private static let naturalMinorDegrees: [ScaleDegree] = [
        ScaleDegree(letterOffset: 0, semitones: 0),
        ScaleDegree(letterOffset: 1, semitones: 2),
        ScaleDegree(letterOffset: 2, semitones: 3),
        ScaleDegree(letterOffset: 3, semitones: 5),
        ScaleDegree(letterOffset: 4, semitones: 7),
        ScaleDegree(letterOffset: 5, semitones: 8),
        ScaleDegree(letterOffset: 6, semitones: 10),
    ]

    private static let harmonicMinorDegrees: [ScaleDegree] = [
        ScaleDegree(letterOffset: 0, semitones: 0),
        ScaleDegree(letterOffset: 1, semitones: 2),
        ScaleDegree(letterOffset: 2, semitones: 3),
        ScaleDegree(letterOffset: 3, semitones: 5),
        ScaleDegree(letterOffset: 4, semitones: 7),
        ScaleDegree(letterOffset: 5, semitones: 8),
        ScaleDegree(letterOffset: 6, semitones: 11),
    ]

    private static let melodicMinorDegrees: [ScaleDegree] = [
        ScaleDegree(letterOffset: 0, semitones: 0),
        ScaleDegree(letterOffset: 1, semitones: 2),
        ScaleDegree(letterOffset: 2, semitones: 3),
        ScaleDegree(letterOffset: 3, semitones: 5),
        ScaleDegree(letterOffset: 4, semitones: 7),
        ScaleDegree(letterOffset: 5, semitones: 9),
        ScaleDegree(letterOffset: 6, semitones: 11),
    ]

    private static let dorianDegrees: [ScaleDegree] = [
        ScaleDegree(letterOffset: 0, semitones: 0),
        ScaleDegree(letterOffset: 1, semitones: 2),
        ScaleDegree(letterOffset: 2, semitones: 3),
        ScaleDegree(letterOffset: 3, semitones: 5),
        ScaleDegree(letterOffset: 4, semitones: 7),
        ScaleDegree(letterOffset: 5, semitones: 9),
        ScaleDegree(letterOffset: 6, semitones: 10),
    ]

    private static let phrygianDegrees: [ScaleDegree] = [
        ScaleDegree(letterOffset: 0, semitones: 0),
        ScaleDegree(letterOffset: 1, semitones: 1),
        ScaleDegree(letterOffset: 2, semitones: 3),
        ScaleDegree(letterOffset: 3, semitones: 5),
        ScaleDegree(letterOffset: 4, semitones: 7),
        ScaleDegree(letterOffset: 5, semitones: 8),
        ScaleDegree(letterOffset: 6, semitones: 10),
    ]

    private static let lydianDegrees: [ScaleDegree] = [
        ScaleDegree(letterOffset: 0, semitones: 0),
        ScaleDegree(letterOffset: 1, semitones: 2),
        ScaleDegree(letterOffset: 2, semitones: 4),
        ScaleDegree(letterOffset: 3, semitones: 6),
        ScaleDegree(letterOffset: 4, semitones: 7),
        ScaleDegree(letterOffset: 5, semitones: 9),
        ScaleDegree(letterOffset: 6, semitones: 11),
    ]

    private static let mixolydianDegrees: [ScaleDegree] = [
        ScaleDegree(letterOffset: 0, semitones: 0),
        ScaleDegree(letterOffset: 1, semitones: 2),
        ScaleDegree(letterOffset: 2, semitones: 4),
        ScaleDegree(letterOffset: 3, semitones: 5),
        ScaleDegree(letterOffset: 4, semitones: 7),
        ScaleDegree(letterOffset: 5, semitones: 9),
        ScaleDegree(letterOffset: 6, semitones: 10),
    ]

    private static let locrianDegrees: [ScaleDegree] = [
        ScaleDegree(letterOffset: 0, semitones: 0),
        ScaleDegree(letterOffset: 1, semitones: 1),
        ScaleDegree(letterOffset: 2, semitones: 3),
        ScaleDegree(letterOffset: 3, semitones: 5),
        ScaleDegree(letterOffset: 4, semitones: 6),
        ScaleDegree(letterOffset: 5, semitones: 8),
        ScaleDegree(letterOffset: 6, semitones: 10),
    ]

    private static let wholeToneDegrees: [ScaleDegree] = [
        ScaleDegree(letterOffset: 0, semitones: 0),
        ScaleDegree(letterOffset: 1, semitones: 2),
        ScaleDegree(letterOffset: 2, semitones: 4),
        ScaleDegree(letterOffset: 3, semitones: 6),
        ScaleDegree(letterOffset: 4, semitones: 8),
        ScaleDegree(letterOffset: 5, semitones: 10),
    ]

    // On C: C D E♭ F G♭ A♭ A♮ B — degrees 6/7 share the letter A.
    private static let wholeHalfDegrees: [ScaleDegree] = [
        ScaleDegree(letterOffset: 0, semitones: 0),
        ScaleDegree(letterOffset: 1, semitones: 2),
        ScaleDegree(letterOffset: 2, semitones: 3),
        ScaleDegree(letterOffset: 3, semitones: 5),
        ScaleDegree(letterOffset: 4, semitones: 6),
        ScaleDegree(letterOffset: 5, semitones: 8),
        ScaleDegree(letterOffset: 5, semitones: 9),
        ScaleDegree(letterOffset: 6, semitones: 11),
    ]

    // On C: C D♭ E♭ E♮ F♯ G A B♭ — degrees 3/4 share the letter E.
    private static let halfWholeDegrees: [ScaleDegree] = [
        ScaleDegree(letterOffset: 0, semitones: 0),
        ScaleDegree(letterOffset: 1, semitones: 1),
        ScaleDegree(letterOffset: 2, semitones: 3),
        ScaleDegree(letterOffset: 2, semitones: 4),
        ScaleDegree(letterOffset: 3, semitones: 6),
        ScaleDegree(letterOffset: 4, semitones: 7),
        ScaleDegree(letterOffset: 5, semitones: 9),
        ScaleDegree(letterOffset: 6, semitones: 10),
    ]

    private static let majorPentatonicDegrees: [ScaleDegree] = [
        ScaleDegree(letterOffset: 0, semitones: 0),
        ScaleDegree(letterOffset: 1, semitones: 2),
        ScaleDegree(letterOffset: 2, semitones: 4),
        ScaleDegree(letterOffset: 4, semitones: 7),
        ScaleDegree(letterOffset: 5, semitones: 9),
    ]

    // On C: C E♭ F G B♭.
    private static let minorPentatonicDegrees: [ScaleDegree] = [
        ScaleDegree(letterOffset: 0, semitones: 0),
        ScaleDegree(letterOffset: 2, semitones: 3),
        ScaleDegree(letterOffset: 3, semitones: 5),
        ScaleDegree(letterOffset: 4, semitones: 7),
        ScaleDegree(letterOffset: 6, semitones: 10),
    ]

    // On C: C E♭ F G♭ G B♭ — degrees 3/4 share the letter F/G respectively.
    private static let bluesDegrees: [ScaleDegree] = [
        ScaleDegree(letterOffset: 0, semitones: 0),
        ScaleDegree(letterOffset: 2, semitones: 3),
        ScaleDegree(letterOffset: 3, semitones: 5),
        ScaleDegree(letterOffset: 3, semitones: 6),
        ScaleDegree(letterOffset: 4, semitones: 7),
        ScaleDegree(letterOffset: 6, semitones: 10),
    ]
}
