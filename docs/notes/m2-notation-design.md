# M2 design notes — NotatedSequence & MusicXML

Working notes for T2.1/T2.2; becomes a spec once the M1 API has landed and
the RangeEngine (T1.5) walk semantics are settled. Planner-owned.

## Layers

1. **`Pitch` sequences** (M1): spelled pitches, exact spelling guaranteed.
2. **`NotatedSequence`** (T2.1): concrete pitches + durations + a notation
   context, with measures and in-measure accidentals resolved. Everything
   the renderer (M3) and MusicXML writer (T2.2) need; nothing UI-specific.
3. **Instrument view** (T2.1): `NotatedSequence.transposed(for: Instrument)`
   converts the whole sequence to written pitch in one place; MusicXML then
   emits `<transpose>` so the file stays correct for the transposing part.

## Duration model

```swift
struct NoteDuration: Hashable, Codable, Sendable {
    enum Base: Int { case whole = 32, half = 16, quarter = 8, eighth = 4, sixteenth = 2, thirtySecond = 1 }
    let base: Base
    let dots: Int   // 0...2
}
```

- Raw value = quarter-note divisions (whole = 32 sixteenth-divisions…
  quarter = 8) — directly reusable as MusicXML `<duration>` with
  `<divisions>8</divisions>`? Decide: divisions = quarter note; then
  duration = base.rawValue/8 * (2 − 2^-dots). Store as
  `quarterBeats: Double` computed (dotted = ×1.5 / ×1.75) and
  `isPowerOfTwoDotted` shapes for `<type>`/`<dot/>`.

## Notation context

```swift
struct NotationContext: Hashable, Codable, Sendable {
    var key: Key                // user-chosen key for display (defaults: derived from the scale)
    var timeSignature: TimeSignature
    var clef: Clef              // derived from instrument
}
```

`TimeSignature`: numerator 1–12, denominator ∈ {1,2,4,8,16,32};
`measureBeats` in quarter-beats; MusicXML `<beats>/<beat-type>`.

## NotatedNote / NotatedSequence

```swift
struct NotatedNote: Hashable, Codable, Sendable {
    let pitch: Pitch
    let duration: NoteDuration
    let tiedToNext: Bool        // split across a barline
    let accidental: Accidental? // display accidental to draw, if any (nil = none)
}

struct NotatedSequence: Hashable, Codable, Sendable {
    let context: NotationContext
    let measures: [[NotatedNote]]   // accidental/tie state already resolved
    // constructed from [Pitch] + uniform duration or per-note durations
}
```

Construction pipeline (the subtle part — keep pure and heavily tested):

1. First note starts on beat 1 of measure 1.
2. Fill measures; a note crossing a barline splits into tied fragments
   (each fragment ≥ a 32nd; durations of fragments: largest ≤ remaining
   space, simplified: e.g. 3 eighths remaining = quarter + eighth tied).
3. Accidentals: per measure, per (letter, octave): the accidental in effect
   starts as the key signature's; a note deviating emits its accidental and
   updates the in-effect state for the rest of the measure. No courtesy
   accidentals in v1 (renderer may add later).
4. Empty trailing space at the end of the last measure: allowed (rest fill
   is a renderer/policy question — MusicXML needs explicit rests if we want
   full measures; decide: emit rests to fill the final measure so files are
   well-formed for other apps).

## MusicXML writer (T2.2)

- `score-partwise` 4.0-ish, one part (`P1`), `<part-name>` = instrument
  display name.
- Measure 1 `<attributes>`: `<divisions>` (quarter = 8 or computed), `<key>`
  (`fifths` = `keySignature.sharpsOrFlats`), `<time>`, `<clef>`; plus
  `<transpose>` with chromatic diatonic from the instrument when transposing.
- Notes: `<pitch><step><alter><octave>`, `<duration>`, `<voice>1`,
  `<type>`, `<dot/>`, `<accidental>` when displayed, `<tie>` + `<notations>`
  ties. Alter = accidental.semitoneOffset.
- Tests: golden-file strings for small known sequences (C major one octave
  4/4 quarters; a barline-crossing tie case; E♭ major accidentals; a
  transposing-instrument case) + Foundation `XMLParser` well-formedness over
  every generated file. Round-trip via a full third-party parser is overkill
  for v1; golden + XMLParser + spot attribute checks suffice.

## Pattern model (T2.3) — early thoughts

`PatternType` = a list of **degree deltas** (scale steps), applied repeatedly
from a start note: thirds = `[+2, −1]`, fourths = `[+3, −2]`, up-step-down-3rd
etc. Generation walks a `Scale` via its step API; the range engine bounds the
walk (same reflect semantics as scales, applied per pattern walk). Durations
default uniform; the user picks time signature/key. Custom patterns (M5)
store concrete notes instead (DECISIONS D7).
