import Foundation

/// A time signature (meter). `measureUnits` works in the same duration
/// units as `NoteDuration` (32 per quarter), so measure capacity and note
/// values share one integer scale.
public struct TimeSignature: Hashable, Codable, Sendable {
    /// Beats per measure: 1–12.
    public let numerator: Int

    /// Note value per beat: one of 1, 2, 4, 8, 16, 32.
    public let denominator: Int

    private static let allowedDenominators: Set<Int> = [1, 2, 4, 8, 16, 32]

    public init(numerator: Int, denominator: Int) {
        precondition(
            (1...12).contains(numerator),
            "TimeSignature: numerator must be 1–12, got \(numerator)"
        )
        precondition(
            Self.allowedDenominators.contains(denominator),
            "TimeSignature: denominator must be a power of two ≤ 32, got \(denominator)"
        )
        self.numerator = numerator
        self.denominator = denominator
    }

    public static let common = TimeSignature(numerator: 4, denominator: 4)

    /// Measure length in quarter-note beats (6/8 → 3.0).
    public var measureBeats: Double {
        Double(numerator) * 4 / Double(denominator)
    }

    /// Measure length in duration units (32 per quarter; always a multiple
    /// of 4 given the allowed denominators). 4/4 → 128, 3/4 → 96, 6/8 → 96.
    public var measureUnits: Int {
        numerator * 128 / denominator
    }

    public var description: String { "\(numerator)/\(denominator)" }
}
