# Spec 006 — NotatedSequence: the notation model (T2.1)

Turns a `[Pitch]` (from a scale run or pattern) into fully notated music:
measures, durations, barline ties, and display accidentals resolved in key
context. Everything the M3 renderer and the T2.2 MusicXML writer need;
nothing UI-specific. Concert pitch is canonical (D2); `transposed(for:)`
produces the written-pitch view.

**Amended after app feedback**: the uniform-duration init gained
`finalDuration` (e.g. `.whole` for the classic whole-note pattern ending,
where the final root fills its measure).

Refines `docs/notes/m2-notation-design.md`; deviations from that note are
flagged inline.

## Duration system

**Units**: `divisions = 32` per quarter note. Every duration is an integral
number of units; MusicXML (T2.2) emits `<divisions>32</divisions>` and uses
units directly as `<duration>`.

```swift
public struct NoteDuration: Hashable, Codable, Sendable {
    public enum Base: Int, Codable, Sendable, Hashable, CaseIterable {
        case whole = 128, half = 64, quarter = 32,
             eighth = 16, sixteenth = 8, thirtySecond = 4
    }
    public let base: Base
    public let dots: Int        // 0…2, restricted per base (below)
    public init(base: Base, dots: Int = 0)
    public var units: Int       // integral duration units (see table)
    public var quarterBeats: Double { Double(units) / 32 }
}
```

**Dots policy (the mod-4 invariant)**: dots 0–2 allowed for whole … eighth;
0–1 for sixteenth; 0 for thirtySecond. With this restriction every
constructible `units` value is a multiple of 4 — which is what guarantees
the greedy fragment decomposition below can always finish any remaining
space. Enforced by `init` precondition.

Units table: base ×(1, dotted, double-dotted): whole 128/192/224,
half 64/96/112, quarter 32/48/56, eighth 16/24/28, sixteenth 8/12,
thirtySecond 4.

## TimeSignature

```swift
public struct TimeSignature: Hashable, Codable, Sendable {
    public let numerator: Int     // 1…12
    public let denominator: Int   // ∈ {1, 2, 4, 8, 16, 32}
    public init(numerator: Int, denominator: Int)   // preconditions above
    public var measureBeats: Double { Double(numerator) * 4 / Double(denominator) }
    public var measureUnits: Int { numerator * 128 / denominator }  // integral
    public static let common = TimeSignature(numerator: 4, denominator: 4)
    public var description: String  // "4/4"
}
```

## NotationContext, NotatedNote, NotatedSequence

```swift
public struct NotationContext: Hashable, Codable, Sendable {
    public var key: Key
    public var timeSignature: TimeSignature
    public var clef: Clef
    public init(key: TimeSignature: clef:)   // memberwise
}

public struct NotatedNote: Hashable, Codable, Sendable {
    public enum Sound: Hashable, Codable, Sendable { case note(Pitch); case rest }
    public let sound: Sound
    public let duration: NoteDuration
    public let tiedToNext: Bool       // tie into the immediately following note
    public let accidental: Accidental? // DISPLAY accidental; nil = none; nil for rests
    public var pitch: Pitch?          // convenience; nil for rests
    public init(sound:duration:tiedToNext:accidental:)   // public for M5 custom entry
}

public struct NotatedSequence: Hashable, Codable, Sendable {
    public let context: NotationContext
    public let measures: [[NotatedNote]]
    public init(pitches: [Pitch], uniformDuration: NoteDuration = .quarter, context: NotationContext)
    public init(pitches: [Pitch], durations: [NoteDuration], context: NotationContext)
    public func transposed(for instrument: Instrument) -> NotatedSequence
}
```

Deviation from the design note: `NotatedNote` carries a `Sound` enum rather
than `let pitch: Pitch` — the final-measure rest fill (below) needs rests,
and an enum makes "accidental on a rest" unrepresentable.

## Construction pipeline (both inits)

1. First note starts on beat 1 of measure 1. Events = pitches zipped with
   durations (`durations.count == pitches.count` precondition in the
   per-note init).
2. **Measure filling**: place each event's value `v` in units into the
   current measure:
   - If `v` ≤ remaining space `r`: place the note whole; `tiedToNext` false
     unless it is a non-final fragment of a split note (see next).
   - Else the note splits: this measure gets the **greedy decomposition of
     `r`** (every fragment `tiedToNext = true`), the leftover `v − r`
     carries into the next measure and repeats the rule (a carry that fits
     becomes a single note — the final fragment, `tiedToNext = false` —
     only if it is exactly a notatable value; otherwise it decomposes again
     with all but the last fragment tied).
   - **Greedy decomposition candidates** (single dots only, descending by
     units): 192 (dotted whole), 128 (whole), 96 (dotted half), 64 (half),
     48 (dotted quarter), 32 (quarter), 24 (dotted eighth), 16 (eighth),
     12 (dotted sixteenth), 8 (sixteenth), 4 (thirtySecond). Rule:
     repeatedly append the largest candidate ≤ remaining. The mod-4
     invariant makes this total (smallest candidate 4).
     Exact-fill preference falls out of greedy (e.g. 96 → one dotted half,
     not half+quarter).
3. **Accidentals in context**: per measure, per `(letter, octave)`: the
   accidental in effect starts as the key signature's for that letter.
   A note whose accidental differs from the in-effect value emits its
   display accidental (including naturals, e.g. F♮ in G major) and updates
   the in-effect value for the rest of the measure; a note matching the
   in-effect value emits none. No courtesy accidentals in v1. State resets
   each measure.
4. **Rest fill**: after all notes, remaining space in the final measure is
   filled with untied rests via the same greedy decomposition (so files are
   well-formed full measures). Empty `pitches` → one measure of rests
   (4/4 → whole rest; 3/4 and 6/8 → dotted half rest; 5/4 → whole +
   quarter).

## transposed(for:)

- `key' = instrument.writtenKey(fromConcert: context.key)`; pitches map via
  `instrument.writtenPitch(fromConcert:)` (traps on > double-accidental
  spellings — documented precondition); time signature and clef unchanged
  (the written part is drawn on the same clef).
- Display accidentals are **re-resolved** per measure under the new key
  signature (measure structure, rhythm, and ties are unchanged by
  transposition).

## Files

- `Sources/PitterCore/Notation/NoteDuration.swift`
- `Sources/PitterCore/Notation/TimeSignature.swift`
- `Sources/PitterCore/Notation/NotatedSequence.swift` (context + note + sequence)
- `Tests/PitterCoreTests/NotatedSequenceTests.swift`

## Test plan

1. `NoteDuration.units` across the table (incl. dotted/double-dotted);
   `quarterBeats` (dotted quarter = 1.5); trap paths documented only.
2. `TimeSignature.measureUnits/measureBeats`: 4/4 → 128/4.0, 3/4 → 96,
   6/8 → 96/3.0, 7/8 → 112, 5/4 → 160, 1/32 → 4.
3. C major, 4/4, 8 quarters from C4 → two full measures, no ties, no rests,
   all accidentals nil.
4. Barline split + tie + rest fill: 4/4, [half C4, whole C4] →
   m0 = [C4 half, C4 half tied], m1 = [C4 half, half rest].
5. Multi-measure split: 4/4, [quarter C4, whole C4] →
   m0 = [C4 quarter, C4 dotted-half tied], m1 = [C4 quarter, dotted-half rest].
6. Accidentals: E♭ major (3 flats), one measure of E♭4 E♮4 E♭4 then a new
   measure E♭4 → display [nil, natural, flat], then nil. Same-letter
   different-octave states independent.
7. Transposed for B♭ clarinet: C major concert, C4 E4 G4 → written D major,
   D4 F♯4 A4, F♯ display nil (in key). Also alto sax (E♭): → A major,
   A4 C♯5 E5.
8. Empty pitches → single rest measure (4/4 → [whole rest]).
9. Uniform default duration is quarter.
