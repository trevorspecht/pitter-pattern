import Foundation

/// A notated duration: a base note value plus augmentation dots.
///
/// Duration units: `divisions = 32` per quarter note, so `Base` raw values
/// are directly the duration-unit counts (whole = 128 … thirty-second = 4).
/// MusicXML output (T2.2) emits `<divisions>32</divisions>` and uses
/// `units` as `<duration>`.
///
/// The dots policy below keeps every constructible duration a multiple of
/// 4 units — the invariant that guarantees barline-splitting and rest-fill
/// decomposition (see `NotatedSequence`) can always complete any remaining
/// measure space.
public struct NoteDuration: Hashable, Codable, Sendable {
    /// Base note values; raw value = duration units (32 per quarter).
    public enum Base: Int, Codable, Sendable, Hashable, CaseIterable {
        case whole = 128
        case half = 64
        case quarter = 32
        case eighth = 16
        case sixteenth = 8
        case thirtySecond = 4
    }

    /// Maximum dots allowed per base (keeps all values multiples of 4
    /// units). Internal: `NotatedSequence`'s exact-duration table uses it.
    static let maxDots: [Base: Int] = [
        .whole: 2, .half: 2, .quarter: 2, .eighth: 2,
        .sixteenth: 1, .thirtySecond: 0,
    ]

    public let base: Base

    /// Augmentation dots: 0–2 for whole…eighth, 0–1 for sixteenth,
    /// 0 for thirty-second.
    public let dots: Int

    public init(base: Base, dots: Int = 0) {
        let limit = Self.maxDots[base]!  // every case is listed above
        precondition(
            (0...limit).contains(dots),
            "NoteDuration: \(dots) dots not allowed on \(base.name) "
                + "(max \(limit)); see the mod-4 units invariant in the docs"
        )
        self.base = base
        self.dots = dots
    }

    /// Integral duration units (32 per quarter): base × (1, 1.5, 1.75).
    public var units: Int {
        let numerator = (1 << (dots + 1)) - 1   // 1, 3, 7
        let denominator = 1 << dots             // 1, 2, 4
        return base.rawValue * numerator / denominator
    }

    /// Length in quarter-note beats (dotted quarter = 1.5).
    public var quarterBeats: Double { Double(units) / 32 }

    public static let whole = NoteDuration(base: .whole)
    public static let half = NoteDuration(base: .half)
    public static let quarter = NoteDuration(base: .quarter)
    public static let eighth = NoteDuration(base: .eighth)
    public static let sixteenth = NoteDuration(base: .sixteenth)
    public static let thirtySecond = NoteDuration(base: .thirtySecond)

    public var description: String {
        let dotText = dots == 0 ? "" : (dots == 1 ? "dotted " : "double-dotted ")
        return dotText + base.name
    }
}

extension NoteDuration.Base {
    /// Plain-language name ("whole" … "32nd").
    public var name: String {
        switch self {
        case .whole: return "whole"
        case .half: return "half"
        case .quarter: return "quarter"
        case .eighth: return "eighth"
        case .sixteenth: return "16th"
        case .thirtySecond: return "32nd"
        }
    }
}
