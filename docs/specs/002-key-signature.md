# Spec 002 — Key signatures and keys

**Task:** T1.2 · **Files:**
`Sources/PitterCore/MusicTheory/KeySignature.swift`, `Sources/PitterCore/MusicTheory/Key.swift`,
`Tests/PitterCoreTests/KeySignatureTests.swift`

Builds on spec 001 (`Pitch`, `Letter`, `Accidental`, `Interval`). Same type
conventions (public, value types, `Hashable`, `Codable`, `Sendable`, doc
comments).

## `KeySignature`

```swift
public struct KeySignature: Hashable, Codable, Sendable {
    /// Sharps if positive, flats if negative, 0 = none. Range: -7...7.
    public let sharpsOrFlats: Int
    public init(sharpsOrFlats: Int)   // preconditionFailure outside -7...7
}
```

- `var sharps: Int`, `var flats: Int` (whichever side is nonzero, else 0).
- `var isEmpty: Bool`.
- `var accidentalsInOrder: [Letter]` — order the accidentals appear in a key
  signature on the staff:
  - sharps: F, C, G, D, A, E, B (first `sharps` of that array)
  - flats: B, E, A, D, G, C, F (first `flats` of that array)
- `func accidental(for letter: Letter) -> Accidental` — `.sharp`/`.flat` if the
  letter is one of this signature's accidentals, else `.natural`.
- `var description: String` — `"no accidentals"`, `"1 sharp (F♯)"`,
  `"2 sharps (F♯ C♯)"`, `"3 flats (B♭ E♭ A♭)"`. Pluralize correctly.

## `KeyMode`

```swift
public enum KeyMode: String, CaseIterable, Codable, Sendable {
    case major, minor
}
```

## `Key`

A tonal key: a tonic spelled as letter + accidental (no octave — a key is not a
pitch) plus major/minor mode.

```swift
public struct Key: Hashable, Codable, Sendable {
    public let tonicLetter: Letter
    public let tonicAccidental: Accidental   // only .natural, .sharp, .flat are valid
    public let mode: KeyMode
    public init(tonicLetter: Letter, tonicAccidental: Accidental = .natural, mode: KeyMode)
    public static func major(_ letter: Letter, _ accidental: Accidental = .natural) -> Key
    public static func minor(_ letter: Letter, _ accidental: Accidental = .natural) -> Key
}
```

- **Validation:** only the 15 conventional tonics per mode are valid (circle of
  fifths). `preconditionFailure` with a clear message for anything else
  (e.g. `Key(tonicLetter: .d, tonicAccidental: .sharp, mode: .major)` → 9
  sharps is invalid; F♭ major invalid — C♭ is the flat-side spelling).
  Valid major tonics: C, G, D, A, E, B, F♯, C♯ (sharp side); F, B♭, E♭, A♭,
  D♭, G♭, C♭ (flat side). Valid minor tonics: A, E, B, F♯, C♯, G♯, D♯, A♯;
  D, G, C, F, B♭, E♭, A♭.
- `var tonicDescription: String` — `"E♭"`, `"F♯"`, `"C"`.
- `var description: String` — `"E♭ major"`, `"F♯ minor"`, `"C major"`.
- `var keySignature: KeySignature` — from the circle of fifths. Implement via
  exact lookup tables (sharps/flat counts per tonic), NOT arithmetic
  guesswork:
  - major sharps: G=1, D=2, A=3, E=4, B=5, F♯=6, C♯=7
  - major flats: F=1, B♭=2, E♭=3, A♭=4, D♭=5, G♭=6, C♭=7
  - minor: signature of the **relative major** = minor tonic transposed up a
    minor third (`Letter` shifted +2 letter positions with the matching
    accidental). E.g. E minor → G major (1 sharp); C minor → E♭ major (3
    flats); D♯ minor → F♯ major (3 sharps).
- `var relativeMajor: Key`, `var relativeMinor: Key` — only meaningful for the
  opposite mode; return the relative key of the other mode (relativeMajor of a
  major key is not meaningful → preconditionFailure).
- `func spell(_ letter: Letter) -> Accidental` — same as
  `keySignature.accidental(for:)`.

## Required tests (Swift Testing)

- All 15 major keys: correct `sharpsOrFlats`, correct `accidentalsInOrder`,
  correct `accidental(for:)` for every letter (e.g. E♭ major: B♭ E♭ A♭, and
  `spell(.a) == .flat`, `spell(.c) == .natural`).
- All 15 minor keys: correct signature (e.g. B minor → 2 sharps; E♭ minor →
  6 flats; G♯ minor → 5 sharps; D♯ minor → 3 sharps? — D♯ minor relative major
  is F♯ major = 3 sharps ✓).
- Key of C major / A minor: 0 accidentals, `isEmpty` true.
- 7-sharp / 7-flat edges: C♯ major spells B♯; C♭ major spells F♭
  (`spell(.f) == .flat`, `spell(.b) == .flat`).
- Descriptions: `"2 sharps (F♯ C♯)"`, `"no accidentals"`, `"1 flat (B♭)"`.
- Invalid keys trap: D♯ major, F♭ major, G♭ minor, A♯ major... wait A♯ minor
  is VALID (7 sharps) — use A♯ MAJOR as the invalid example; also B♭♯? not a
  thing. Trap tests for: A♯ major, D♯ major, F♭ major, G♭ minor, D♭ minor,
  E♯ minor? (E♯ minor would be 9 sharps — invalid ✓).
- Relative keys: E minor.relativeMajor == G major; B♭ major.relativeMinor ==
  G minor (tonic spelling equality, not key-signature equality alone).

## Non-goals

Modes other than major/minor (spec 003 derives those from the parent major
key), instrument transposition (T1.4), notation/MusicXML (M2).

## Acceptance

`swift build` and `swift test` green from the repo root, run and verified by
the delegatee with real output pasted into the report.
