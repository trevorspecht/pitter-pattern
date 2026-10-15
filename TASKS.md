# TASKS.md

Task board for PitterPattern. Tags: `effort: easy|hard`, `scope: local|light|online`.
Delegated work is always planner-reviewed (tests re-run locally) before it counts
as done.

## Environment notes

- Xcode.app and XcodeGen are now installed (2026-10-13). `xcodegen generate`
  then `xcodebuild -scheme PitterPatternMac` (and the iOS-simulator scheme)
  both BUILD SUCCEEDED with the placeholder `App/` shell — verified before M3.
  `PitterCore` still builds/tests headlessly (`swift test`) for fast iteration;
  use Xcode for app/UI work.
- CLT ships NEITHER swift-testing nor XCTest: swift-testing is pulled as a
  pinned package dependency (see `Package.swift`); test targets MUST also list
  `.target(name: "PitterCore")` explicitly (SPM does not auto-link `@testable`
  imports). Local-model delegations: write each file ONCE, then only fix
  compile/test errors in place — never delete and rewrite files.
- Delegation calibration so far (category `code`): fail / fail / pass-after-fixes
  / fail / fail (T2.3 and T2.2 both stalled mid-task the same way: one
  plausible source file written, then hung for 10–16 min before writing any
  tests; sources were ~90% right with 2–3 real bugs each, planner finished
  both) — the local model produces decent single-module structure but
  reliably stalls before test iteration. Until this is fixed (context length?
  turn budget?), delegate single source files WITHOUT expecting tests, or
  keep code on the planner. Core implementation stays with the planner; the
  local model gets self-contained, single-file, table-heavy work only.

## Milestone 1 — Music theory core (headless, `swift test`)

- [x] T1.1 Pitch / spelling / Interval API + unit tests — `effort: easy`, `scope: local`
      Spec: `docs/specs/001-pitch-interval.md` — DONE (planner-implemented after
      local-model failure; 19 tests green; includes XCTest→swift-testing CLT
      workaround). Reviewer note: strict letter arithmetic means e.g. E♭+m2 = F♭.
- [x] T1.2 Key signatures + Key/tonic model + unit tests — `effort: easy`, `scope: local`
      Spec: `docs/specs/002-key-signature.md` — DONE (planner-implemented after local-model
      failure #2: letter-only major-key table, accidental-carrying relative-major,
      full-order accidental check; 30 tests green). Added `Key.isValid(...)` public
      validation API (replaces impossible trap tests).
- [x] T1.3 ScaleType catalog (major; 3 minors; 7 modes; whole tone; dim & dom-dim;
      chromatic; 3 pentatonics) + Scale generation (concert pitch) + unit tests —
      `effort: hard`, `scope: online` — DONE (planner-implemented; 54 tests green).
      Reviewer notes: C blues spells F♯ (aug 4th), not G♭; fixed letter templates
      can yield unconventional-but-enharmonic spellings for gapped scales on
      sharp/flat tonics (documented limitation, spelling-preference pass is a
      future enhancement).
- [x] T1.4 Instrument model (transposition, clef, suggested range) + written-pitch
      helpers + unit tests — `effort: easy`, `scope: local`
      Spec: `docs/specs/004-instruments.md` — DONE (local-model pass-after-fixes:
      planner fixed its broken `Interval.inverted` (only negated semitones —
      `concertPitch(fromWritten:)` would have trapped), alto concert-range,
      `Instrument.all`→`allCases`, and its test's soprano-as-E♭ mixup).
      Bonus: public `Interval.inverted` (both components) with tests.
- [x] T1.5 Range engine (bounds + reflect-at-closest-note) + unit tests —
      `effort: hard`, `scope: online` — DONE (planner-implemented; spec 005).
      Generic `RangeRun.generate` over any walk stepper + `Scale.boundedRun`
      convenience; out-and-back to the start, bounds in concert pitch. Bug
      found via debug run: chromatic starts must re-anchor via down-then-up
      (up-then-down lands on the flat-side spelling, so runs wouldn't finish
      on their starting spelling).

## Milestone 2 — Notation model + MusicXML

- [x] T2.1 NotatedSequence model (concrete spelled pitches + durations + measure
      breaking + accidentals-in-context) — `effort: hard`, `scope: online`
      Spec: `docs/specs/006-notated-sequence.md` — DONE (planner-implemented;
      12 tests green). Key decisions: divisions=32 duration units with a
      mod-4 dots policy (the invariant that makes greedy barline-split
      decomposition total); `NotatedNote.Sound` enum (note/rest) instead of
      the design note's bare `pitch` so rests can fill the final measure;
      `transposed(for:)` re-resolves display accidentals under the written key.
- [ ] T2.2 MusicXML `score-partwise` writer + round-trip tests — `effort: easy`,
      `scope: local` — spec `docs/specs/008-musicxml-writer.md` — DONE
      (local model stalled again after writing the source; planner finished:
      fixed its alter-from-display-accidental bug (alter must come from the
      pitch's own spelling — an in-key F♯ shows no glyph but still needs
      alter=1), never-emitted tie stops, and missing same-measure tie
      predecessors; wrote all 8 tests incl. byte-exact golden document).
      104 tests green.
- [x] T2.3 Pattern model (scale-relative moves) + built-in pattern catalog
      (thirds, fourths, arpeggios, …) + unit tests — `effort: easy`,
      `scope: local` — Spec: `docs/specs/007-patterns.md` — DONE
      (local model stalled mid-task; planner completed in place: fixed its
      phase-transition delta-index bug (the retrograde must start on the SAME
      index that failed), both-sides bounds checks per phase, and phase-3
      spelled landing; wrote all 11 tests). Reviewer note: five hand-derived
      sequences in spec 007 were wrong (letter-arithmetic slips); per spec the
      algorithm is normative and test values were pinned from actual runs —
      derive expected pattern walks by running, not by hand.

## Milestone 3 — Staff renderer + selection UI

- [x] T3.1 Staff geometry + Bravura glyph renderer (SwiftUI Canvas) —
      `effort: hard`, `scope: online` — Spec: `docs/specs/009-staff-renderer.md`
      — DONE (planner-implemented; 20 new tests, 121 total green; both app
      targets build). Bravura 1.482 (OFL) bundled via SPM resources;
      codepoints verified against w3c/smufl glyphnames.json. Key findings:
      key-signature placement is fourths-with-octave-wrap (sharps wrap
      +7 above the 2nd line, flats wrap −7 at the top line) — verified
      against all standard treble positions; `canImport(AppKit)` is true
      even for the iOS *simulator* SDK, so platform conditionals must use
      `os()`; renderer verified headlessly via ImageRenderer smoke tests
      (ink count + a clef-orientation probe above/below the staff).
      Bass keys with 5+ accidentals: wrap-rule output unverified by eye.
      Visual review: run the app (demo staff in ContentView) or see
      /tmp/staff-demo.png from the test run.
- [ ] T3.2 Selection / viewing UI with category filters, key + time signature
      controls, transpose + range controls, instrument picker — `effort: hard`,
      `scope: online` (needs Xcode) — must also include: app appearance
      preference (light / dark / system; the page itself stays white-paper
      by default) and polished zoom controls (slider is in the demo already).
      Pattern-ending preference (include/skip the ending 7th) may belong
      here or in the range controls.
- [x] T3.1b+c App-feedback rounds (2026-10-13, planner): page renderer
      (portrait 8.5×11 aspect, systems wrap favoring equal WHOLE measures
      per line, no horizontal scrolling), final barline (thin+thick),
      time-signature centering (Bravura digits are baseline-symmetric ±1 →
      baselines 3/1), header spacing from real Bravura advances (gap 1.5
      spaces, none reserved for an absent key signature, continuation
      lines leave extra room after the key signature), rest anchors
      from Bravura bounding boxes, white paper/black ink, zoom slider,
      system justification (all but the last line stretch their measures
      so notes fill each measure and sit centered — the root cause of
      "first note too far left" was the last note's advance piling ~5
      dead spaces at each measure's right; the last note is now pinned
      by its head width, lone notes centered as accidental+head group),
      musical note advances (quarter 6.5 spaces etc.), defaultScale
      (4 measures per line on an 8.5×11/612pt page) + 680×900pt default
      window, pattern endings descend to the 7th and resolve to the root
      (`includeEndingSeventh: false` skips it; floor = min(low, 7th) so
      octave patterns and mid-range starts still descend; per-pattern
      ending shapes to be tuned as we experiment), final note as a whole
      (`finalDuration`). 124 tests green; both app targets build.

## Milestone 4 — Audio

- [ ] T4.1 AudioEngine + scheduled note playback (instrument sounds, tempo) —
      `effort: hard`, `scope: online`
- [ ] T4.2 Metronome (tempo, time signature, sounds, accents) on the same clock —
      `effort: hard`, `scope: online`

## Milestone 5 — Randomizer, custom entries, persistence

- [ ] T5.1 Random selector (category + scale/pattern/both filters) — `effort: easy`,
      `scope: local` once core types exist
- [ ] T5.2 SwiftData store for custom scales/patterns + settings — `effort: hard`,
      `scope: online` (needs Xcode)
- [ ] T5.3 Click-on-staff custom note entry (note type, key, time signature) —
      `effort: hard`, `scope: online` (needs Xcode)

## Later / backlog

- MIDI note entry (external instrument)
- MusicXML / file export UI
- Verovio rendering option for advanced notation (see DECISIONS D1)
- App Store packaging: bundle ID, signing, icons, license choice
