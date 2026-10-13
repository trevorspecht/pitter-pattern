/// A musical interval: a signed letter distance plus a signed semitone
/// distance. Positive = ascending, negative = descending.
///
/// Carrying both distances is what makes spelled transposition correct:
/// `Interval(letterSteps: 2, semitones: 4)` (a major third) always lands on
/// the right *letter*, with the right accidental derived from the target.
public struct Interval: Hashable, Codable, Sendable {
    /// Signed letter positions (e.g. +2 for an ascending third, −3 for a
    /// descending fourth).
    public let letterSteps: Int

    /// Signed semitones.
    public let semitones: Int

    public init(letterSteps: Int, semitones: Int) {
        self.letterSteps = letterSteps
        self.semitones = semitones
    }

    // MARK: - Standard intervals

    /// Perfect unison (P1).
    public static let unison = Interval(letterSteps: 0, semitones: 0)
    /// Major 2nd (M2).
    public static let M2 = Interval(letterSteps: 1, semitones: 2)
    /// Minor 2nd (m2).
    public static let m2 = Interval(letterSteps: 1, semitones: 1)
    /// Major 3rd (M3).
    public static let M3 = Interval(letterSteps: 2, semitones: 4)
    /// Minor 3rd (m3).
    public static let m3 = Interval(letterSteps: 2, semitones: 3)
    /// Perfect 4th (P4).
    public static let P4 = Interval(letterSteps: 3, semitones: 5)
    /// Perfect 5th (P5).
    public static let P5 = Interval(letterSteps: 4, semitones: 7)
    /// Minor 6th (m6).
    public static let m6 = Interval(letterSteps: 5, semitones: 8)
    /// Major 6th (M6).
    public static let M6 = Interval(letterSteps: 5, semitones: 9)
    /// Minor 7th (m7).
    public static let m7 = Interval(letterSteps: 6, semitones: 10)
    /// Major 7th (M7).
    public static let M7 = Interval(letterSteps: 6, semitones: 11)
    /// Perfect octave (P8).
    public static let P8 = Interval(letterSteps: 7, semitones: 12)
    /// Augmented 4th / diminished 5th (A4 = d5 = 6 semitones over 3 letters).
    public static let tritone = Interval(letterSteps: 3, semitones: 6)

    private static let perfectSemitones: [Int: Int] = [1: 0, 4: 5, 5: 7, 8: 12]
    private static let majorSemitones: [Int: Int] = [2: 2, 3: 4, 6: 9, 7: 11]

    /// Perfect interval of the given signed degree (±1, ±4, ±5, ±8).
    public static func perfect(_ degree: Int) -> Interval {
        let magnitude = abs(degree)
        guard let semis = perfectSemitones[magnitude] else {
            preconditionFailure("Perfect \(magnitude) is not a valid perfect degree (1, 4, 5, 8).")
        }
        return oriented(degree: degree, unsignedSemitones: semis)
    }

    /// Major interval of the given signed degree (±2, ±3, ±6, ±7).
    public static func major(_ degree: Int) -> Interval {
        let magnitude = abs(degree)
        guard let semis = majorSemitones[magnitude] else {
            preconditionFailure("Major \(magnitude) is not a valid major degree (2, 3, 6, 7).")
        }
        return oriented(degree: degree, unsignedSemitones: semis)
    }

    /// Minor interval of the given signed degree (±2, ±3, ±6, ±7).
    public static func minor(_ degree: Int) -> Interval {
        major(degree).narrowed(by: 1)
    }

    /// Augmented interval: a perfect or major interval widened by one semitone
    /// (valid degrees 1–8).
    public static func augmented(_ degree: Int) -> Interval {
        let magnitude = abs(degree)
        guard perfectSemitones[magnitude] != nil || majorSemitones[magnitude] != nil else {
            preconditionFailure("Augmented \(magnitude) is not a valid degree (1–8).")
        }
        return perfectOrMajor(magnitude, degree: degree).widened(by: 1)
    }

    /// Diminished interval: a perfect interval (±1, ±4, ±5, ±8) or minor
    /// interval (±2, ±3, ±6, ±7) narrowed by one semitone.
    public static func diminished(_ degree: Int) -> Interval {
        let magnitude = abs(degree)
        guard perfectSemitones[magnitude] != nil || majorSemitones[magnitude] != nil else {
            preconditionFailure("Diminished \(magnitude) is not a valid degree (1–8).")
        }
        let base = perfectOrMajor(magnitude, degree: degree)
        return perfectSemitones[magnitude] != nil ? base.narrowed(by: 1) : base.narrowed(by: 2)
    }

    private static func perfectOrMajor(_ magnitude: Int, degree: Int) -> Interval {
        if let semis = perfectSemitones[magnitude] {
            return oriented(degree: degree, unsignedSemitones: semis)
        }
        return oriented(degree: degree, unsignedSemitones: majorSemitones[magnitude]!)
    }

    private static func oriented(degree: Int, unsignedSemitones: Int) -> Interval {
        degree < 0
            ? Interval(letterSteps: degree + 1, semitones: -unsignedSemitones)
            : Interval(letterSteps: degree - 1, semitones: unsignedSemitones)
    }

    /// Widen by semitones in the interval's own direction (a descending
    /// interval gets more negative).
    private func widened(by semitones: Int) -> Interval {
        let delta = self.semitones >= 0 ? semitones : -semitones
        return Interval(letterSteps: letterSteps, semitones: self.semitones + delta)
    }

    /// Narrow by semitones in the interval's own direction (a descending
    /// interval gets less negative).
    private func narrowed(by semitones: Int) -> Interval {
        let delta = self.semitones >= 0 ? semitones : -semitones
        return Interval(letterSteps: letterSteps, semitones: self.semitones - delta)
    }

    // MARK: - Properties

    /// The exact inverse interval (negated letter distance and semitone
    /// distance): `M3.inverted` is a descending M3; transposing by an interval
    /// and then by its inverse returns the original spelling.
    public var inverted: Interval {
        Interval(letterSteps: -letterSteps, semitones: -semitones)
    }

    /// True when the interval goes downward.
    public var isDescending: Bool { semitones < 0 || letterSteps < 0 }

    /// Quality + degree without direction, e.g. `"M3"`, `"m2"`, `"P5"`,
    /// `"d5"`, `"A4"`, `"d7"`. Non-standard letter/semitone combinations (not
    /// expressible with degrees 1–8) get a parenthesized description.
    public var qualityDescription: String {
        let degree = abs(letterSteps) + 1
        let magnitudeSemitones = abs(semitones)
        let quality: String
        if let perfectBase = Self.perfectSemitones[degree] {
            switch magnitudeSemitones - perfectBase {
            case 0: quality = "P"
            case 1: quality = "A"
            case -1: quality = "d"
            default: return "(\(semitones) semitones over \(letterSteps) letters)"
            }
        } else if let majorBase = Self.majorSemitones[degree] {
            switch magnitudeSemitones - majorBase {
            case 0: quality = "M"
            case -1: quality = "m"
            case 1: quality = "A"
            case -2: quality = "d"
            default: return "(\(semitones) semitones over \(letterSteps) letters)"
            }
        } else {
            return "(\(semitones) semitones over \(letterSteps) letters)"
        }
        return "\(quality)\(degree)"
    }

    public var description: String {
        isDescending ? "\(qualityDescription) (descending)" : qualityDescription
    }
}
