# Spec 009 — Staff geometry + Bravura glyph renderer (T3.1)

Own renderer per D1: SwiftUI `Canvas` + the Bravura SMuFL font (OFL, bundled).
Single voice, one staff per system — our whole notation domain (spec 006).

**Amended after second app feedback** (v1.2): header gap 1.5 staff spaces;
musical note advances (quarter 6.5, half 8, whole 11, eighth 5.5,
sixteenth 5, thirty-second 4.5 spaces); measures have symmetric barline
padding (1.25) and the last note of a measure is pinned by its head width
instead of its advance (advances carry trailing space that piled up on the
right — the real cause of "first note too far left"); a lone note is
centered as an accidental + head group. Systems are **justified**: every
system except the last stretches its measures (slack shared equally by
every within-measure gap, so notes fill the measure and sit centered) to
exactly span the content width; the last system stays ragged (standard).
Continuation systems leave extra room after the key signature (0.7
spaces) for a note accidental. **Scale semantics** (user-clarified): the
zoom slider scales the music; window resizing never changes the music
size, only how many bars fit per line. The base (100%) size is the
printed-page size (four measures per line on a 612 pt / 8.5 × 11 page,
≈7.5 mm staff) times a **1.6 screen-comfort factor** (≈12 mm staff) —
calibrated by the user as the right on-screen 100%. One staff space = the vertical
distance between two adjacent staff lines (a quarter of the staff
height); every metric here is a multiple of it, scaled to points by the
view's `scale`.

## Coordinate system

All layout math is in **staff spaces**, y = spaces above the **bottom** staff
line (lines at integer y 0…4, spaces at half-integers; one diatonic step =
0.5). `StaffView` converts to points (`scale` pt per space; Bravura em
size = 4 × scale). SMuFL glyphs anchor on the **baseline**, so glyphs are
drawn with their baseline at the target y (via CoreText in the Canvas).

- Pitch → y: diatonic index `octave × 7 + letter`; treble bottom line E4
  (index 30), bass bottom line G2 (index 18); `y = (index − refIndex) / 2`.
- Ledger lines: above the staff, integers in `5 … floor(y)` (note at y=6 →
  {5, 6}); below, integers in `ceil(y) … −1`. Segments span ±0.75 around
  the notehead center. No ledger for notes inside the staff or in the
  first space beyond the lines (e.g. D4 in treble).
- Key-signature accidental y (amended): sequential fourths with octave
  wraps — first accidental at the highest in-staff position of its letter
  (F on the top line in treble, B on the middle line); each following one
  a fourth away (sharps down, flats up), jumping an octave at the wrap
  threshold (sharps: the 2nd line, flats: the top line). Reproduces all
  standard treble placements.
- Rest baseline y (from the Bravura bounding boxes): whole 3, half 2,
  quarter 2, eighth 2.15, sixteenth 2.64, thirty-second 2.15
  (smaller rests center on the middle line).
- Time-signature digits (amended): Bravura digits are symmetric ±1 around
  the baseline, so the numerator baseline is y=3 and the denominator y=1 —
  tops and bottoms align with the staff. Always digits (no common/cut
  glyph in v1).

## X layout (`StaffLayout`, pure and headless-testable; amended)

Header spacing uses the real Bravura glyph advances (clef 2.68/2.74,
sharp 1.0, flat 0.9, time digit 1.88) with one **equal gap** (1.0 space)
between header elements — clef | key signature | time signature | first
measure — and **no space reserved for an absent key signature**.
Measures lay out internally with note advances (whole 14, half 11, quarter
9, eighth 8, sixteenth 7.5, thirty-second 7; +1.5 per dot; +1.8 when the
note shows an accidental) and 1.25 of padding around each barline.

**System wrapping** (amended): `lines(contentWidth:)` packs whole
measures left to right. The **first system is filled as full as it fits;
following systems match the first system's count; the last system takes
the remainder** (7 measures fitting 3 per line → 3 + 3 + 1, not 3 + 2 + 2).
The first system carries clef + key
signature + time signature; continuation systems carry clef + key
signature (standard practice). The last measure of the last system ends
with a final (thin + thick) barline. Ties are drawn within a system only
in v1.

`StaffLayout` (per `NotatedSequence`) exposes:
- `measures: [MeasureLayout]` — origin x, width, barline x, and per-note
  layouts: x (notehead center), y, glyph kind (notehead black/half/whole,
  rest type), stem (up/down, length 3.5; up when y < 2, down when y > 2,
  default up on the middle line), flags (eighth 1 … thirtySecond 3, on the
  stem side), dots (count, x offset), accidental glyph + x (left of the
  notehead), ledger line segments, tie segments (notehead right edge →
  next notehead left edge, offset 0.9 to the side opposite the stem,
  quadratic curve bulging ±1).
- `width` (total), and the header positions (clef/key/time x).

## Files

- `Sources/PitterCore/Notation/Bravura.swift` — SMuFL codepoints (verified
  against w3c/smufl glyphnames.json) + font registration/loading
  (CoreText, `Bundle.module`, `.process` scope, cached).
- `Sources/PitterCore/Notation/StaffLayout.swift` — pure layout math.
- `Sources/PitterCore/Notation/StaffView.swift` — SwiftUI `Canvas`:
  staff lines / glyphs (CoreText `CTLineDraw` inside `withCGContext` for
  baseline-exact drawing) / stems, flags, dots, accidentals, ledger lines,
  barlines, ties (stroked paths). Horizontal scrolling is the caller's job.
- `Resources/Bravura.otf` + `Resources/OFL.txt` (bundled; Package.swift
  `.copy` resources).
- `Tests/PitterCoreTests/StaffLayoutTests.swift`, `BravuraTests.swift`
  — pitch→y mapping, ledger sets, monotonic x, measure widths, tie
  segments; font registers and all needed codepoints map to real glyphs.
- `App/ContentView.swift` — temporary demo (a pattern run on a staff in a
  horizontal `ScrollView`); replaced by the real UI in T3.2.

## Non-goals (v1)

Beaming (flags only), courtesy accidentals, multi-voice, system wrapping /
justification, articulations. All later enhancements; MusicXML (spec 008)
remains the canonical portable form.
