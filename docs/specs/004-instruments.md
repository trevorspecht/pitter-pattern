# Spec 004 — Instruments and transposition

**Task:** T1.4 · **Files:**
`Sources/PitterCore/MusicTheory/Clef.swift`, `Sources/PitterCore/MusicTheory/Instrument.swift`,
`Tests/PitterCoreTests/InstrumentTests.swift`

Builds on specs 001/002. Same type conventions.

## `Clef`

```swift
public enum Clef: String, CaseIterable, Codable, Sendable, Hashable {
    case treble, bass    // alto/tenor/percussion can be added when the renderer needs them
    public var description: String   // "Treble", "Bass"
}
```

## `Instrument`

```swift
public enum Instrument: String, CaseIterable, Codable, Sendable, Identifiable, Hashable {
    case concertPitch   // generic non-transposing (piano, voice, C instruments)
    case flute
    case bbClarinet
    case sopranoSax
    case altoSax
    case tenorSax
    case bariSax
    public var id: String { rawValue }
}
```

Members (all computed):

- `displayName: String` — "Flute", "B♭ Clarinet", "Alto Sax", "Tenor Sax",
  "Concert Pitch (C)".
- `isTransposing: Bool`.
- `writtenTransposition: Interval` — how to get from a concert pitch to the
  pitch written for this instrument's player:
  - concertPitch, flute: `.unison`
  - bbClarinet, sopranoSax, tenorSax: `.M2` (up a major 2nd)
  - altoSax, bariSax: `.M6` (up a major 6th — written treble convention)
- `defaultClef: Clef` — `.treble` for every instrument above.
- `suggestedLow: Pitch`, `suggestedHigh: Pitch` — editable-by-app defaults
  (NOT authoritative; hints for initial range settings):
  - concertPitch: C2…C6 (piano-ish reading range)
  - flute: C4…C7
  - bbClarinet: concert D3…B♭6 (written E3…C7)
  - sopranoSax: concert A♭3…E♭6 (written B♭3…F6)
  - altoSax: concert D♭3…A♭5 (written B♭3…F♯6)
  - tenorSax: concert A♭2…E5 (written B♭3…F♯6)
  - bariSax: concert D♭2…A♭4 (written B♭3…F♯6)
- `func writtenPitch(fromConcert pitch: Pitch) -> Pitch` —
  `pitch.transposed(by: writtenTransposition)`.
- `func concertPitch(fromWritten pitch: Pitch) -> Pitch` — inverse interval.
- `func writtenKey(fromConcert key: Key) -> Key` — transpose the key tonic the
  same way: take `key.tonicLetter`/`tonicAccidental` at octave 4, transpose,
  and rebuild the `Key` with the same mode. If the transposed tonic is not a
  valid key tonic (the genuinely invalid cases, e.g. concert C♯ major on an
  E♭ instrument → G♯ major), fall back by respelling enharmonically to the
  nearest valid tonic (G♯ → A♭); if that fails too, return the concert key
  unchanged.
- Do NOT add a `default`/`fallback` static member — call sites use
  `.concertPitch` directly.

## Required tests (Swift Testing)

- Every instrument: `writtenPitch(fromConcert:).concertPitch(fromWritten:)`
  round-trips to the original spelled pitch (all instruments).
- B♭ instruments: concert C4 → written D4; concert F♯4 → written G♯4;
  E♭ instruments: concert C4 → written A4; concert E♭4 → written C5.
- Flute/concertPitch: identity (C4 → C4, spelled key unchanged).
- `writtenKey(fromConcert:)`: concert C major → D major on B♭ instruments and
  A major on E♭ instruments; concert E♭ major → F major on B♭; concert B♭
  major → G major on E♭; concert F♯ minor → G♯ minor on B♭ (valid — 5 sharps);
  respelling fallback: concert C♯ major on an E♭ instrument → transposed tonic
  G♯ major (invalid) → respelled A♭ major.
- `suggestedLow < suggestedHigh` and both within MIDI 0…127 for every
  instrument; suggested range sanity per instrument (e.g. flute suggestedLow
  == C4, bariSax suggestedLow is a D♭2).
- Catalog: no duplicate rawValues (guaranteed by enum), `all.count == 7`,
  every instrument has `.treble` defaultClef in this set.

## Non-goals

Range clamping/reflection (T1.5 uses these hints), rendered notation of
transposed parts (M2/M3), custom instruments.

## Acceptance

`swift build` and `swift test` green from the repo root, real output pasted
into the delegatee's report.
