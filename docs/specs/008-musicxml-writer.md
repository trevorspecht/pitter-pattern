# Spec 008 — MusicXML `score-partwise` writer (T2.2)

Serializes a `NotatedSequence` (spec 006) to MusicXML partwise 4.0, one
part. Deterministic output (fixed 2-space indentation, no timestamps) so
tests can pin it. The writer is a pure formatter: all musical decisions
(measures, ties, display accidentals, transposition) are already made by
`NotatedSequence`.

## API

```swift
public enum MusicXML {
    /// Full document string for one part.
    /// - Parameters:
    ///   - sequence: concert-pitch sequence (canonical, D2).
    ///   - partName: `<part-name>` text (e.g. instrument display name).
    ///   - instrument: when transposing, the sequence is emitted in written
    ///     pitch (via `NotatedSequence.transposed(for:)`) and a
    ///     `<transpose>` element describes written → sounding.
    public static func scorePartwise(
        _ sequence: NotatedSequence,
        partName: String,
        instrument: Instrument = .concertPitch
    ) -> String
}
```

## Document shape (normative example)

Concert C major, 4/4, quarters `C4 D4 E4 F4 | G4 A4 B4 C5`, part name
"Concert Pitch (C)", treble:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 4.0 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">
<score-partwise version="4.0">
  <part-list>
    <score-part id="P1">
      <part-name>Concert Pitch (C)</part-name>
    </score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>32</divisions>
        <key>
          <fifths>0</fifths>
        </key>
        <time>
          <beats>4</beats>
          <beat-type>4</beat-type>
        </time>
        <clef>
          <sign>G</sign>
          <line>2</line>
        </clef>
      </attributes>
      <note>
        <pitch>
          <step>C</step>
          <octave>4</octave>
        </pitch>
        <duration>32</duration>
        <voice>1</voice>
        <type>quarter</type>
      </note>
      <!-- … D4 E4 F4 identically … -->
    </measure>
    <measure number="2">
      <!-- G4 A4 B4 C5 -->
    </measure>
  </part>
</score-partwise>
```

Trailing newline after `</score-partwise>`. Empty elements (`<key>`, `<clef>`
bodies) are always split across lines as shown; leaf elements are on one
line.

## Element rules

- **divisions**: always 32 (spec 006 units); `<duration>` = `units`.
- **key**: `<fifths>` = `context.key.keySignature.sharpsOrFlats`.
- **time**: `<beats>` = numerator, `<beat-type>` = denominator.
- **clef**: treble → `G`/2, bass → `F`/4 (`<sign>`, `<line>`).
- **attributes**: only in measure 1.
- **transpose** (transposing instruments only), inside `<attributes>` after
  `<clef>`: MusicXML describes written → sounding, i.e. the *negation* of
  `Instrument.writtenTransposition`: `<diatonic>` =
  `-writtenTransposition.letterSteps`, `<chromatic>` =
  `-writtenTransposition.semitones` (B♭ clarinet: −1 / −2).
- **notes**: `<pitch>` with `<step>` (letter), `<alter>` only when the
  accidental is not natural (= `accidental.semitoneOffset`), `<octave>`.
  Then `<duration>`, `<voice>1</voice>`, `<type>` =
  `duration.base.name` ("whole"…"32nd"), one `<dot/>` per dot.
- **display accidental**: `<accidental>sharp|flat|natural|double-sharp|
  flat-flat|sharp-sharp</accidental>` after `<type>`/`<dot/>` when
  `note.accidental != nil` (MusicXML accidental names: `sharp`, `flat`,
  `natural`, `double-sharp`, `flat-flat`, `sharp-sharp` — map
  double-sharp and double-flat accordingly).
- **ties**: a note whose *predecessor* had `tiedToNext` emits
  `<tie type="stop"/>`; a note with `tiedToNext` emits
  `<tie type="start"/>` (both when it is a middle fragment). Ties come
  before `<voice>`… per the MusicXML DTD order for a note:
  `pitch|rest`, duration, tie*, voice, type, dot*, accidental, …
  Each tied note also carries
  `<notations><tied type="…"/></notations>` after `<accidental>` (or
  where `<accidental>` would be).
- **rests**: `<rest/>` in place of `<pitch>`; duration/voice/type/dot as
  notes; never ties or accidentals.
- XML-escape `partName` (`&`, `<`, `>`, `"`).

## Files

- `Sources/PitterCore/Notation/MusicXML.swift`
- `Tests/PitterCoreTests/MusicXMLTests.swift`

## Test plan

1. **Golden string**: the normative example above, exact (two full
   measures, all eight notes written out).
2. **Tie round-shape**: the spec-006 case `[half C4, whole C4]` in 4/4 →
   measure 1 note 2 has `<tie type="start"/>` + `<notations><tied
   type="start"/></notations>`; measure 2 note 1 has `type="stop"` pair;
   measure 2 ends with a `<rest/>` note.
3. **Accidentals**: E♭ major sequence from spec 006's test 6 → `<fifths>`
   -3; E♮ shows `<accidental>natural</accidental>`; the following E♭ shows
   `<accidental>flat</accidental>`; both carry `<alter>` (-1 for E♭, absent
   for E♮).
4. **Transposing**: B♭ clarinet, C major C4 E4 G4 → `<fifths>2</fifths>`,
   `<transpose><diatonic>-1</diatonic><chromatic>-2</chromatic></transpose>`,
   F♯4 has `<alter>1</alter>` and NO `<accidental>`; pitches are D4 F♯4 A4.
5. **Well-formedness**: every document from tests 1–4 plus a matrix
   (all instruments × a couple of keys/meters, incl. 6/8 and dotted
   durations) parses with Foundation `XMLParser` with no errors.
6. **Structural spot checks via XMLParser**: measure count, note count,
   `divisions` = 32, `fifths` value, dotted note has `<dot/>` — assert by
   walking the parse tree (delegate-based or `XMLParser` +
   accumulated nodes), not by string matching, for the matrix cases.
