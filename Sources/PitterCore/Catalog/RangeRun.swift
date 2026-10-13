/// Walk direction for bounded runs (and later, pattern walks).
public enum WalkDirection: Hashable, Codable, Sendable {
    case up
    case down
}

/// Absolute pitch bounds for a run, in concert pitch (DECISIONS D2/D3).
public struct RangeBounds: Hashable, Codable, Sendable {
    /// The lowest allowed pitch (inclusive).
    public let low: Pitch

    /// The highest allowed pitch (inclusive).
    public let high: Pitch

    /// - Precondition: `low <= high` by sounding pitch (MIDI).
    public init(low: Pitch, high: Pitch) {
        precondition(
            low.midiNumber <= high.midiNumber,
            "RangeBounds: low (\(low.debugDescription)) must not exceed high "
                + "(\(high.debugDescription))"
        )
        self.low = low
        self.high = high
    }

    /// Inclusive membership by sounding pitch.
    public func contains(_ pitch: Pitch) -> Bool {
        pitch.midiNumber >= low.midiNumber && pitch.midiNumber <= high.midiNumber
    }
}

/// Bounded out-and-back runs (DECISIONS D3):
/// ascend from the start to the walk note closest to the high bound, reflect
/// down to the closest note at/above the low bound, then finish back on the
/// starting pitch. Tie cases resolve toward the run's interior; walk gaps
/// never exceed 2 semitones, so "closest, ties inside" is exactly "highest
/// walk note ≤ high bound" / "lowest walk note ≥ low bound".
public enum RangeRun {

    /// Generate a bounded out-and-back sequence over any walkable note source.
    ///
    /// - Parameters:
    ///   - start: the starting pitch (must be in the walk, enharmonic
    ///     matching allowed — the sequence is built entirely from the walk's
    ///     own spellings, so an enharmonic start is re-anchored).
    ///   - bounds: absolute (concert-pitch) bounds; must contain `start`.
    ///   - next: the adjacent-note stepper for the walk source. Must be
    ///     monotonic per direction.
    ///   - startInWalk: membership check for the walk source (enharmonic
    ///     matching allowed).
    public static func generate(
        from start: Pitch,
        bounds: RangeBounds,
        next: (Pitch, WalkDirection) -> Pitch,
        startInWalk: (Pitch) -> Bool
    ) -> [Pitch] {
        precondition(
            startInWalk(start),
            "RangeRun: start \(start.debugDescription) is not in the walk"
        )
        precondition(
            bounds.contains(start),
            "RangeRun: start \(start.debugDescription) is outside the bounds "
                + "\(bounds.low.debugDescription)…\(bounds.high.debugDescription)"
        )

        // Re-anchor the start to the walk's own spelling — via a down/up
        // round trip, so the anchor uses the *ascending* spelling (the run
        // begins ascending). For direction-spelled walks like chromatic,
        // up-then-down would land on the descending (flat-side) spelling and
        // the run would not finish on its starting spelling.
        let anchored = next(next(start, .down), .up)

        // Safety guard against non-terminating steppers.
        let maxSteps = 4 * (bounds.high.midiNumber - bounds.low.midiNumber) + 32
        var steps = 0
        func step(_ pitch: Pitch, _ direction: WalkDirection) -> Pitch {
            steps += 1
            precondition(steps <= maxSteps, "RangeRun: walk did not terminate")
            return next(pitch, direction)
        }

        var sequence: [Pitch] = [anchored]
        var current = anchored

        // Phase 1: ascend to the highest walk note within the high bound.
        while true {
            let up = step(current, .up)
            guard up.midiNumber <= bounds.high.midiNumber else { break }
            sequence.append(up)
            current = up
        }

        // Phase 2: descend to the lowest walk note at/above the low bound.
        if current.midiNumber > bounds.low.midiNumber {
            while true {
                let down = step(current, .down)
                guard down.midiNumber >= bounds.low.midiNumber else { break }
                sequence.append(down)
                current = down
                if down.midiNumber == bounds.low.midiNumber { break }
            }
        }

        // Phase 3: climb back up to finish on the starting pitch.
        while current.midiNumber < anchored.midiNumber {
            let up = step(current, .up)
            sequence.append(up)
            current = up
        }

        return sequence
    }
}
