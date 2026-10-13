# Design decisions

Running record of significant decisions, with rationale and reversibility notes.

## D1 — Own staff renderer; MusicXML as canonical portable format

**Decision:** Render notation ourselves (SwiftUI `Canvas` + the Bravura SMuFL
font). Keep a `score-partwise` MusicXML generator as the canonical, renderer-
agnostic interchange from M2 onward.

**Rationale:** Our notation domain is narrow (single voice, one staff, simple
durations, accidentals, barlines) — maybe 5% of a full engraver's job. A custom
renderer keeps the app dependency-free, small, and fully portable.

**Reversibility (important):** We reserve the option to adopt **Verovio** later
for advanced notation (repeats, articulations, harmonies, arbitrary MusicXML
import). Verovio has an official, maintained Swift binding (v6.3.0, Aug 2025).
Because we always carry a MusicXML representation, swapping in Verovio is a
renderer-side change; the theory/notation core would not need rework. The
internal notation model should therefore always be serializable to MusicXML.

## D2 — Concert pitch is canonical; transposition is a display/playback layer

**Decision:** All internal pitch representation (catalog, patterns, custom
entries, MusicXML) is in **concert pitch**. Each `Instrument` carries a
transposition interval; written pitches (and written key) are computed at the
display layer for transposing instruments.

**Rationale:** The user plays flute, B♭ clarinet, B♭ saxes, and E♭ saxes. With
concert-pitch internals, one generated exercise serves every instrument; only
the display changes. This also matches how MusicXML handles transposing parts
(`<transpose>`), keeping export correct.

**Defaults:** concert key C, 4/4. Instrument presets set clef (all these
instruments read treble clef), written transposition (flute: none; B♭: up a
major 2nd; E♭: up a major 6th), and a suggested practice range.

## D3 — Range behavior: absolute bounds, stop at closest scale note, reflect

**Decision:** Ranges are absolute pitch bounds (low/high `Pitch`). When
generating an ascending run, continue while the next note is within bounds; if
the bound itself is not in the scale, stop at the scale note **closest to the
bound** and reflect back in the other direction.

**Example:** upper bound F♯, C major scale from C: ascend … D E F, then back
down E D C … (F♯ is not in the scale; F is the closest in-scale note below it).

**Details / policy:**
- "Closest to the bound": the in-scale note with minimum semitone distance to
  the bound; ties broken toward the interior of the run.
- Runs are "out and back": ascend from the start note to the upper turning
  note, then descend to the lower turning note (the closest in-scale note to
  the lower bound), then finish on the starting pitch. (The exact finish is
  a tuning knob; see `RangeEngine` when spec'd.)
- Bounds may fall outside the instrument's suggested range; the instrument
  range is a default hint, not a clamp.

## D4 — Swift + SwiftUI multiplatform; core as a Swift Package

**Decision:** One SwiftUI app source set for macOS/iOS/iPadOS; all non-UI
logic in the `PitterCore` Swift Package so it is unit-testable headlessly
(`swift test`, no Xcode.app required) and shared by all targets.

**Platforms:** iOS 17 / iPadOS 17 / macOS 14 (SwiftData requires this floor).
**Toolchain note (2026-10-12):** the dev machine has Command Line Tools only;
`swift test` works, but app targets need full Xcode installed.

## D5 — Project generation via XcodeGen

**Decision:** App targets are defined in `project.yml` (XcodeGen), not a
hand-managed `.xcodeproj`. The generated project is gitignored.

**Rationale:** Diffable, reviewable project definition; no merge pain; the
package + project.yml fully describe the repo.

## D6 — Audio: one AVAudioEngine clock for playback and metronome

**Decision:** Playback and metronome both use `AVAudioEngine` with
sample-scheduled `AVAudioPlayerNode` buffers (the approach in Apple's
HelloMetronome sample). No timers/NSTimer anywhere.

**Rationale:** Sample-frame scheduling is drift-free and keeps the click and
the notes locked to the same clock by construction.

## D7 — Custom entries are concrete note sequences; built-ins are generated

**Decision:** Built-in scales are interval/step patterns generated from a
tonic; built-in patterns are scale-relative move sequences. Custom (user-
entered) scales/patterns are stored as concrete spelled pitches + durations
(SwiftData), entered via click-on-staff editing (note type, key, time
signature chosen at entry). MIDI note entry is a planned future input path —
the custom-entry model deliberately stores concrete pitches so MIDI capture
needs no new representation.

**Sequela:** the catalog treats `custom` as just another category, so
filtering and random selection see user entries uniformly.
