# Spec 001 — Pitch, spelling, and intervals

**Task:** T1.1 · **Files:**
`Sources/PitterCore/MusicTheory/Pitch.swift`, `Sources/PitterCore/MusicTheory/Interval.swift`,
`Tests/PitterCoreTests/PitchIntervalTests.swift`

All types: public API, `struct`/`enum` (value semantics), `Hashable`, `Codable`,
`Sendable`, and `Equatable` (some also `Comparable`, noted below). No external
dependencies. Swift 6 language mode (strict concurrency is satisfied by pure
value types). Aim for doc comments on every public declaration.

## Conventions

- Scientific pitch notation: middle C = **C4** = MIDI 60; octave wraps B → C.
- MIDI number: `12 * (octave + 1) + letterStep + accidentalOffset`.
- Everything is spelled (letter + accidental), not just MIDI numbers — correct
  spelling is the entire point of this module (needed later for key signatures,
  MusicXML, and correct staff rendering).

## `Letter`

```swift
public enum Letter: Int, CaseIterable, Codable, Sendable, Hashable, Comparable {
    case c = 0, d = 1, e = 2, f = 3, g = 4, a = 5, b = 6
}
```

- `naturalSemitonesFromC: Int` — c=0, d=2, e=4, f=5, g=7, a=9, b=11.
- `var next: Letter`, `var previous: Letter` — wrap around (b.next == c, c.previous == b).
- `static func < ` by rawValue; `description` returns `"C"`…`"B"`.

## `Accidental`

```swift
public enum Accidental: Int, Codable, Sendable, Hashable, Comparable {
    case doubleFlat = -2, flat = -1, natural = 0, sharp = 1, doubleSharp = 2
}
```

- `semitoneOffset: Int` (raw value).
- `static func < ` by rawValue; `description` returns `"bb"`, `"b"`, `""`, `"#"`, `"##"`
  (ASCII, used for debugging); a separate `symbol: String` returns
  `"♭♭"`, `"♭"`, `"♮"`, `"♯"`, `"♯♯"` (Unicode, used for display).

## `Pitch`

```swift
public struct Pitch: Hashable, Codable, Sendable, Comparable {
    public let letter: Letter
    public let accidental: Accidental
    public let octave: Int
    public init(_ letter: Letter, _ accidental: Accidental = .natural, octave: Int)
}
```

Required members:

- `midiNumber: Int` per the convention above. (C4 → 60, A4 → 69, C♭4 → 59,
  B♯3 → 60.)
- `description: String` — letter + accidental symbol + octave, e.g.
  `"C♯4"`, `"B♭3"`, `"C4"` (naturals show no symbol).
- `debugDescription: String` — ASCII form, e.g. `"C#4"`, `"Bb3"`.
- `static func < (lhs: Pitch, rhs: Pitch) -> Bool` — primarily by `midiNumber`;
  tie-break by `accidental.rawValue` (so C♯4 < D♭4 < D♮4? No: C♯4 and D♭4 are
  enharmonic — order C♯4 **before** D♭4), then by letter.
- `func isEnharmonic(with other: Pitch) -> Bool` — equal MIDI numbers.
- `func shifted(octaves: Int) -> Pitch` — same spelling, octave + n.
- `func shifted(letters: Int) -> Pitch` — same accidental, letter moved n letter
  positions (A4 +2 letters → C5; B3 +1 letter → C4; D5 −3 letters → A4).
  Implement with absolute letter-index arithmetic so octave wrap is exact.
- `func transposed(by interval: Interval) -> Pitch` — see semantics below.
- Convenience: `init?(midiNumber: Int, preferringSharps: Bool = true)` —
  chromatic spelling (sharp side: C, C♯, D, D♯, E, F…; flat side with
  `preferringSharps: false`). Any MIDI number 0…127.

## `Interval`

An interval = a signed letter distance + a signed semitone distance.

```swift
public struct Interval: Hashable, Codable, Sendable {
    public let letterSteps: Int   // signed letter positions (e.g. +2 = an ascending third)
    public let semitones: Int     // signed
    public init(letterSteps: Int, semitones: Int)
}
```

- A degree is 1–8; the sign of the degree argument gives direction
  (positive = ascending, negative = descending). For degree d
  (ascending), `letterSteps = d - 1`; descending negates both `letterSteps`
  and `semitones`.
- Static constructors — all accept a signed degree:
  - `perfect(_ d:)` — d ∈ {±1, ±4, ±5, ±8}: semitones 0, 5, 7, 12.
  - `major(_ d:)` — d ∈ {±2, ±3, ±6, ±7}: semitones 2, 4, 9, 11.
  - `minor(_ d:)` — d ∈ {±2, ±3, ±6, ±7}: major minus 1.
  - `augmented(_ d:)` — perfect/major plus 1 (d ∈ {±1..±8} valid for base degrees).
  - `diminished(_ d:)` — perfect minus 1 for d ∈ {±1, ±4, ±5, ±8};
    minor minus 1 for d ∈ {±2, ±3, ±6, ±7}.
  - Invalid degree/quality combinations: `preconditionFailure` with a clear message.
- Convenience constants: `.unison`, `.M2`, `.m2`, `.M3`, `.m3`, `.P4`, `.P5`,
  `.m6`, `.M6`, `.m7`, `.M7`, `.P8`, `.tritone` (= augmented 4th).
- `var isDescending: Bool`.
- `var qualityDescription: String` — `"P1"`, `"m2"`, `"M3"`, `"P5"`, `"d5"`, `"A4"`,
  `"d7"`, `"M6"`; e.g. `Interval(letterSteps: -3, semitones: -9)` → `"m6"` (descending).
- `var description: String` — e.g. `"M3"`, `"m6 (descending)"`.

### `transposed(by:)` semantics

1. Shift the letter by `interval.letterSteps` (using `shifted(letters:)`).
2. Target MIDI = `self.midiNumber + interval.semitones`.
3. New accidental = target − natural MIDI of the shifted spelling. It must land
   in `-2...2`; otherwise `preconditionFailure` (the interval is not spellable
   from this pitch — e.g. C♮ + augmented 5th).
4. Return the spelled result.

## Required tests (Swift Testing, `import Testing`; use `@testable import PitterCore`)

These exact cases, at minimum (more welcome, e.g. randomized
transposed-then-untransposed round trips):

- `midiNumber`: C4=60, A4=69, C♭4=59, B♯3=60, A0=21, C8=108, C♯4=61.
- `description`/`debugDescription`: `"C♯4"`, `"B♭3"`, `"C4"` / `"C#4"`, `"Bb3"`.
- `init(midiNumber:)`: 60→C4; 61 sharp→C♯4, flat→D♭4; 66 sharp→F♯4, flat→G♭4.
- `shifted(letters:)`: A4+2→C5, B3+1→C4, D5−3→A4, C4+7→C5, C4−1→B3.
- `transposed(by:)` ascending: C4+M3→E4, F4+M3→A4, C4+P5→G4, B4+P5→F♯5,
  C4+m6→A♭4, D4+A2→E♯4, C4+d5→G♭4, E♭4+m2→F♭4 (strict letter arithmetic —
  E♮ would be an augmented unison above E♭), G4+M7→F♯5, C4+P8→C5,
  C4+tritone→F♯4.
- `transposed(by:)` descending: E4−M3→C4, C4−m2→B3, C4−P5→F3, B4−M3→G4,
  A4−m6→C♯4.
- Round trip: `p.transposed(by: i).transposed(by: i.inverted())` — wait, no
  `inverted()` in this spec; test instead: transposing up M3 then down M3
  returns the original pitch (assert equality of the full spelling).
- Unspellable: `C4.transposed(by: .augmented(5))` traps — test that it
  `expectFatalError`-style or simply document + assert precondition is hit via
  a helper (if a clean trap test is awkward in Swift Testing, use
  `XCTExpectFailure`-equivalent or omit the trap test and note why in a comment).
- `Interval.qualityDescription`: `.M3`→"M3", `.m2`→"m2", `.P5`→"P5",
  `.augmented(4)`→"A4", `.diminished(7)`→"d7", `Interval(letterSteps: -5,
  semitones: -8)`→"m6" with `isDescending` true.
- Enharmonics: `C♯4.isEnharmonic(with: D♭4)` true, equality false;
  `B♯3.isEnharmonic(with: C4)` true.
- Ordering: C♯4 < D4; D♭4 < D4; C♯4 < D♭4 (enharmonic tie-break);
  B3 < C4; C♭4 < B3 (59 < 59? — C♭4 is MIDI 59 and B3 is MIDI 59: equal MIDI,
  tie-break by accidental rawValue: flat(−1) < natural(0), so C♭4 < B3).

## Non-goals (do not implement here)

No key signatures, no scales, no instruments, no formatting/UI. Spec 002+
builds on this API.

## Acceptance

`swift build` and `swift test` pass from the repo root, with zero warnings
preferred. The delegatee must actually run both and paste real output — do not
report success from imagination.
