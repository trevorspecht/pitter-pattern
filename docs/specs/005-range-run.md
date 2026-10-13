# Spec 005 — Bounded out-and-back runs (range engine)

**Task:** T1.5 · **Files:**
`Sources/PitterCore/Catalog/RangeRun.swift`, `Tests/PitterCoreTests/RangeRunTests.swift`

Implements DECISIONS D3. Planner-implemented (subtle semantics).

## Semantics

A **bounded run** is an out-and-back pitch sequence within absolute low/high
`Pitch` bounds, over any "walkable" note source (a `Scale` today, a pattern
walk in T2.3):

1. Ascend from the start note while the next note (in the walk) is within the
   upper bound. Since walk gaps never exceed 2 semitones, the turn point is
   automatically the walk note *closest* to the bound, ties resolved to the
   interior (user's example: upper bound F♯, C major → ascends … F, then
   reflects).
2. Descend from the turn point to the closest walk note at/above the lower
   bound (same tie rule).
3. Ascend from the lower turn note back up to (and finishing on) the
   **starting pitch**.

If the start *is* the top (or bottom), phases collapse naturally; degenerate
case (no room either way) yields the single start note.

Preconditions (the UI prevents all of these): lower ≤ start ≤ upper, start is
in the walk, bounds valid (low ≤ high). All traps.

## API

```swift
public enum WalkDirection: Hashable, Codable, Sendable {
    case up, down
}

public struct RangeBounds: Hashable, Codable, Sendable {
    public let low: Pitch
    public let high: Pitch
    public init(low: Pitch, high: Pitch)   // precondition low ≤ high (by MIDI)
    public func contains(_ pitch: Pitch) -> Bool   // inclusive, by MIDI
}

public enum RangeRun {
    /// Generic out-and-back generator (used by Scale today, patterns in T2.3).
    /// - `next`: adjacent-note stepper for the walk source (assumes monotonic).
    /// - `startInWalk`: membership check (enharmonic matching allowed).
    public static func generate(
        from start: Pitch,
        bounds: RangeBounds,
        next: (Pitch, WalkDirection) -> Pitch,
        startInWalk: (Pitch) -> Bool
    ) -> [Pitch]

    /// Scale convenience: bounds in concert pitch (canonical, DECISIONS D2);
    /// an enharmonic start is re-anchored to the scale's own spelling.
    /// Defined in Scale.swift as `Scale.boundedRun(from:low:high:)`.
}
```

A step-safety guard (maximum iterations ≈ 4 × bound span + 32) traps on
non-terminating `next` closures.

## Required tests

- **User's example**: C major, C4, bounds C4…F♯4 → `[C4 D4 E4 F4 E4 D4 C4]`.
- Classic full octave: C major, C4…C5 → out and back, ending C4, 15 notes.
- Start mid-range (G4, C4…C5): `G4 A4 B4 C5 B4 A4 G4 F4 E4 D4 C4 D4 E4 F4 G4`.
- Bounds not in scale: low C♯4, high A♭4, C major from D4 → upper turn G4
  (A♭4 not in scale; G is closest in-bounds below), lower turn D4 (C♯4 is
  the bound; C and D tie, tie resolves inside → D). Note: a bound that IS
  in scale (e.g. low B3) is descended through — B3 is a valid lower turn.
  - Exact: `[D4 E4 F4 G4 F4 E4 D4]`.
- In-scale lower bound: C major, low B3, high A♭4, from C4 →
  `[C4 D4 E4 F4 G4 F4 E4 D4 C4 B3 C4]` (bottom turn at B3).
- Tight bounds: C4…E4 from C4 → `[C4 D4 E4 D4 C4]`.
- Degenerate: C4…C♯4 from C4 → `[C4]`.
- Chromatic: C4…E4 from C4 → sharp-side up, flat-side back down
  (`[C4 C♯4 D4 D♯4 E4 D♯4 D4 C♯4 C4]`).
- Blues across the gap: C blues, C4…G4 → `[C4 E♭4 F4 F♯4 G4 F♯4 F4 E♭4 C4]`.
- Enharmonic start: A major from D♭4 → sequence starts and ends on C♯4.
- Generic engine (no Scale): a mock stepper (semitone steps) reproduces the
  chromatic case via `RangeRun.generate` directly.
- Bound-span sanity: every generated sequence starts and ends on the start
  pitch (respelled), stays within bounds, and (except the degenerate single)
  contains the start pitch exactly twice.

## Non-goals

Durations/measures (T2.1), pattern step sources (T2.3, will reuse
`RangeRun.generate`), UI bound pickers (M3).
