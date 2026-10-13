# Spec 003 — Scale catalog and scale generation

**Task:** T1.3 · **Files:**
`Sources/PitterCore/Catalog/ScaleType.swift`, `Sources/PitterCore/Catalog/Scale.swift`,
`Tests/PitterCoreTests/ScaleCatalogTests.swift`

Builds on specs 001/002. Same type conventions (public value types,
`Hashable`, `Codable`, `Sendable`, doc comments).

## Core idea

Most scales are a **spelling template**: for each degree, how many letter
positions above the tonic letter, and how many semitones above the tonic. That
directly yields conventionally correct spellings from any tonic (e.g.
whole-half diminished on C: C D E♭ F G♭ A♭ A♮ B, where two degrees share the
letter A, and degrees 2/4 carry flats).

The **chromatic scale cannot be templated**: its letter pattern depends on
where the E→F / B→C semitone gaps fall relative to the tonic letter (C
chromatic starts C C♯ D…, but F♯ chromatic starts F♯ G G♯…). It therefore gets
its own spelling strategy (a step rule, below).

## `ScaleDegree`

```swift
public struct ScaleDegree: Hashable, Codable, Sendable {
    /// Letter positions above the tonic letter (0 = tonic letter). May repeat
    /// across degrees (e.g. [.., 5, 5, 6] for diminished scales).
    public let letterOffset: Int
    /// Semitones above the tonic.
    public let semitones: Int
    public init(letterOffset: Int, semitones: Int)
}
```

## `SpellingStrategy`

```swift
public enum SpellingStrategy: Hashable, Codable, Sendable {
    /// Fixed letter/semitone template, independent of tonic spelling.
    case template([ScaleDegree])
    /// Chromatic scale, ascending spelled with sharps; descending with the
    /// flat-side mirror rule (see "Chromatic step rule").
    case chromatic
}
```

## `ScaleCategory`

```swift
public enum ScaleCategory: String, CaseIterable, Codable, Sendable {
    case major, minor, modal, symmetric, chromatic, pentatonic, blues
    public var description: String   // capitalized
}
```

(The UI filter buckets; `custom` is added in M5 as another value.)

## `ScaleType`

```swift
public struct ScaleType: Hashable, Codable, Sendable, Identifiable {
    public let id: String            // stable slug: "major", "harmonic-minor", …
    public let name: String          // display name: "Harmonic Minor"
    public let category: ScaleCategory
    public let spelling: SpellingStrategy
    /// Letter steps from the tonic letter to the *parent major key* tonic
    /// letter, keeping the tonic's accidental (mod 7). nil = fallback policy
    /// (see `keySignatureRoot`).
    public let parentMajorLetterOffset: Int?
    public init(id:name:category:spelling:parentMajorLetterOffset: Int? = nil)
    /// Convenience init for template scales (degrees[0] must be (0,0)).
    public init(id:name:category:degrees: [ScaleDegree], parentMajorLetterOffset: Int? = nil)
    public static let all: [ScaleType]   // the built-in catalog below
}
```

Template convenience init: precondition `degrees[0] == (letterOffset: 0, semitones: 0)`.

## Built-in catalog (`ScaleType.all`) — exact tables

letterOffset/semitones pairs; tonic = degree 0.

- **major** — "Major", .major, parent 0:
  (0,0) (1,2) (2,4) (3,5) (4,7) (5,9) (6,11)
- **natural-minor** — "Natural Minor", .minor, parent +2:
  (0,0) (1,2) (2,3) (3,5) (4,7) (5,8) (6,10)
- **harmonic-minor** — "Harmonic Minor", .minor, parent +2:
  (0,0) (1,2) (2,3) (3,5) (4,7) (5,8) (6,11)
- **melodic-minor** — "Melodic Minor", .minor, parent +2:
  (0,0) (1,2) (2,3) (3,5) (4,7) (5,9) (6,11)
- **ionian** — "Ionian", .modal, parent 0: same degrees as major.
- **dorian** — "Dorian", .modal, parent −1:
  (0,0) (1,2) (2,3) (3,5) (4,7) (5,9) (6,10)
- **phrygian** — "Phrygian", .modal, parent −2:
  (0,0) (1,1) (2,3) (3,5) (4,7) (5,8) (6,10)
- **lydian** — "Lydian", .modal, parent −3:
  (0,0) (1,2) (2,4) (3,6) (4,7) (5,9) (6,11)
- **mixolydian** — "Mixolydian", .modal, parent −4:
  (0,0) (1,2) (2,4) (3,5) (4,7) (5,9) (6,10)
- **aeolian** — "Aeolian (Natural Minor)", .modal, parent +2: same degrees as
  natural minor.
- **locrian** — "Locrian", .modal, parent −6:
  (0,0) (1,1) (2,3) (3,5) (4,6) (5,8) (6,10)
- **whole-tone** — "Whole Tone", .symmetric, parent nil:
  (0,0) (1,2) (2,4) (3,6) (4,8) (5,10)
- **whole-half-diminished** — "Whole-Half Diminished", .symmetric, parent nil:
  (0,0) (1,2) (2,3) (3,5) (4,6) (5,8) (5,9) (6,11)
- **half-whole-diminished** — "Half-Whole Diminished", .symmetric, parent nil:
  (0,0) (1,1) (2,3) (2,4) (3,6) (4,7) (5,9) (6,10)
  (on C: C D♭ E♭ E♮ F♯ G A B♭ — degrees 3/4 share the letter E)
- **chromatic** — "Chromatic", .chromatic, `.chromatic` strategy, parent nil.
- **major-pentatonic** — "Major Pentatonic", .pentatonic, parent 0:
  (0,0) (1,2) (2,4) (4,7) (5,9)
- **minor-pentatonic** — "Minor Pentatonic", .pentatonic, parent +2:
  (0,0) (2,3) (3,5) (4,7) (6,10)
- **blues** — "Blues", .blues, parent +2:
  (0,0) (2,3) (3,5) (3,6) (4,7) (6,10)

## Chromatic step rule

Given the previous spelled pitch, the next chromatic degree (one semitone in
the walk direction):

**Ascending (sharp side):** from `(letter L, accidental a)`:
- `a == .flat` (or `.doubleFlat`): next = `(L, a raised by 1)` — e.g. E♭ → E♮.
- `a == .natural`: if the natural gap `L → nextLetter` is 2 semitones
  (true for every letter except E and B): next = `(L, .sharp)`;
  else (L is E or B): next = `(nextLetter, .natural)`.
- `a == .sharp`: next = `(nextLetter, .natural)`.

**Descending (flat side, mirror):** from `(letter L, accidental a)`:
- `a == .sharp` (or `.doubleSharp`): next = `(L, a lowered by 1)` — e.g. F♯ → F♮.
- `a == .natural`: if the natural gap `prevLetter → L` is 2 semitones
  (every letter except F and C): next = `(L, .flat)`;
  else (L is F or C): next = `(prevLetter, .natural)`.
- `a == .flat`: next = `(prevLetter, .natural)`.

Worked examples: ascending from C: C C♯ D D♯ E F F♯ G G♯ A A♯ B C.
Ascending from F♯: F♯ G G♯ A A♯ B C C♯ D D♯ E F F♯.
Ascending from E♭: E♭ E F F♯ G G♯ A A♯ B C C♯ D E♭.
Descending from C: C B B♭ A A♭ G G♭ F E E♭ D D♭ C.

## `Scale`

```swift
public struct Scale: Hashable, Codable, Sendable, Identifiable {
    public let type: ScaleType
    public let tonic: Pitch     // spelled tonic; accidental ∈ {.natural, .sharp, .flat}
    public init(type: ScaleType, tonic: Pitch)   // precondition on tonic accidental
    public var name: String     // "E♭ Major", "D Dorian", "C Whole Tone"
    public var id: String       // slug, e.g. "eb-major", "d-dorian"
}
```

Generation (all monotonic, spelling-continuous, exact octave handling):

- `func degreePitches(ascendingFrom start: Pitch, count: Int) -> [Pitch]` —
  walk `count` pitches upward from `start` (which must be in the scale,
  enharmonically — see `isInScale`), continuing into higher octaves. `start`
  anchors which cycle/degree you begin at. If the start spelling is enharmonic
  but not identical to the scale's spelling at that degree, anchor to the
  scale's own spelling (e.g. walking A major from D♭4 anchors at C♯4).
- `func degreePitches(descendingFrom start: Pitch, count: Int) -> [Pitch]`
- `func nextUp(after pitch: Pitch) -> Pitch` /
  `func nextDown(before pitch: Pitch) -> Pitch` — single steps; direction
  determines which spelling chromatic uses (as built, simpler than the
  originally drafted `ascendingFrom:`-parameterized forms).
- `func oneOctaveAscending(from tonic: Pitch) -> [Pitch]` — tonic … tonic+8ve,
  inclusive (degrees+1 entries; 13 for chromatic).
- `func oneOctaveDescending(from tonic: Pitch) -> [Pitch]` — top tonic down to
  tonic, inclusive.
- `func isInScale(_ pitch: Pitch) -> Bool` — semitone class (mod 12 relative
  to the tonic) matches some degree, regardless of octave. Chromatic: always
  true.
- `func spelledInScale(_ pitch: Pitch) -> Bool` — the pitch's spelling exactly
  equals the scale's spelling for its degree class (chromatic: matches the
  ascending **or** descending spelling).
- `var keySignatureRoot: Key` — parent key for key-signature display:
  `Key(tonicLetter: tonic.letter shifted by parentMajorLetterOffset
  (keeping the tonic's accidental), mode: .major)` — e.g. D dorian → C major;
  B♭ mixolydian → E♭ major; A harmonic minor → C major. If `parentMajorLetterOffset`
  is nil, or the derived tonic is not a valid key tonic, fall back to `C major`.
- `func transpose(by interval: Interval) -> Scale` — new tonic
  `tonic.transposed(by:)`; traps if the result's accidental is outside
  {.natural, .sharp, .flat} (UI will restrict transpose choices so it can't).

Spelling rules during template generation:

- Letter = tonic letter shifted by `letterOffset`; the octave follows absolute
  letter-index arithmetic exactly (tonic B3 + offset 1 → C4; tonic A4 +
  offset 2 → C5; across cycles add `7 * cycle` to the letter index).
- Semitone target = tonic.midiNumber + 12 * cycle + degree.semitones.
  Accidental = target − the shifted spelling's natural MIDI. Needs more than
  a double accidental → `preconditionFailure`.
- Descending walks the template backwards from the anchor cycle.

Chromatic generation uses the step rule above, per direction, anchored at
`start`'s (scale-spelled) degree. Octave endpoints keep the tonic's own
spelling: walking a chromatic scale from E♭4 ascends … D5 **E♭5** (not D♯5),
and descending from E♭5 ends on E♭4 (the mirror rule reaches it naturally).

## Required tests (Swift Testing)

- Catalog integrity: `ScaleType.all` — no duplicate ids; template scales have
  `degrees[0] == (0, 0)`; every degree list strictly increasing in semitones;
  spot-check tables match this spec exactly (harmonic minor
  [0,2,3,5,7,8,11]; whole-half letters [0,1,2,3,4,5,5,6] semis
  [0,2,3,5,6,8,9,11]; half-whole semis [0,1,3,4,6,7,9,10]; blues
  [0,3,5,6,7,10]).
- One octave, C major: [C4 D4 E4 F4 G4 A4 B4 C5] — exact spellings.
- One octave, E♭ major: [E♭4 F4 G4 A♭4 B♭4 C5 D5 E♭5].
- One octave, D harmonic minor: [D4 E4 F4 G4 A4 B♭4 C♯5 D5] — raised 7th
  spelled C♯, not D♭.
- One octave, B♭ mixolydian: [B♭4 C5 D5 E♭5 F5 G5 A♭5 B♭5].
- One octave, A♭ melodic minor: [A♭4 B♭4 C♭5 D♭5 E♭5 F5 G5 A♭5] — C♭, not B♮.
- One octave, C whole tone: [C4 D4 E4 F♯4 G♯4 A♯4 C5].
- One octave, C whole-half diminished: [C4 D4 E♭4 F4 G♭4 A♭4 A♮4 B4 C5].
- One octave, C half-whole diminished: [C4 D♭4 E♭4 E♮4 F♯4 G4 A4 B♭4 C5].
- One octave, E minor pentatonic: [E4 G4 A4 B4 D5 E5].
- One octave, C blues: [C4 E♭4 F4 F♯4 G4 B♭4 C5] — the added 4th is the
  augmented 4th (F♯ on C), not G♭.
- One octave, C chromatic ascending: [C4 C♯4 D4 D♯4 E4 F4 F♯4 G4 G♯4 A4 A♯4
  B4 C5]; F♯ chromatic ascending: [F♯4 G4 G♯4 A4 A♯4 B4 C5 C♯5 D5 D♯5 E5 F5
  F♯5]; E♭ chromatic ascending: [E♭4 E4 F4 F♯4 G4 G♯4 A4 A♯4 B4 C5 C♯5 D5 E♭5].
- C chromatic descending from C5: [C5 B4 B♭4 A4 A♭4 G4 G♭4 F4 E4 E♭4 D4 D♭4 C4].
- Multi-octave: major `degreePitches(ascendingFrom: C4, count: 15)` ends at
  C6 (15 notes); starting mid-scale from G4 walks G4 A4 B4 C5 …; from B4
  (major) the next is C5 (octave wrap). One-octave round trips: descending
  from the top of every one-octave-ascending result reproduces it reversed —
  exactly (identical spellings) for template scales; enharmonically (same
  MIDI sequence) for chromatic, since descending uses the flat-side mirror
  (test over every `ScaleType.all` on tonics C4, E♭4, F♯4, A4).
- `isInScale`: C♯4 in A major ✓ (enharmonic); D♭4 in A major: `isInScale` ✓,
  `spelledInScale` ✗. B♮ in C harmonic minor ✓.
- Enharmonic anchoring: walking A major from D♭4 starts at C♯4.
- Transpose: C major + M6 → A major. E♭ major + m3 → G♭ major. A♭ melodic
  minor + M2 → B♭ melodic minor (spot-check the one-octave spellings).
- Key signature roots: D dorian → C major; B♭ mixolydian → E♭ major;
  A harmonic minor → C major; E minor → G major; G♭ major → G♭ major;
  B locrian → C major (B − 6 letters = C); G♭ locrian → A♭ major
  (G♭ − 6 letters = A♭, and A♭ major's 7th degree is G♭); D♭ lydian →
  A♭ major (A♭ major's 4th degree is D♭).

## Non-goals

Pattern generation (T2.3), range clamping/reflection (T1.5), notation/MusicXML
(M2), melodic-minor-descends-as-natural-minor behavior (that's a
NotatedSequence-level policy in T2.1 — this type generates exactly what its
template says).

## Acceptance

`swift build` and `swift test` green from the repo root, real output pasted
into the delegatee's report.
