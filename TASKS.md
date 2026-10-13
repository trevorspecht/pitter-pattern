# TASKS.md

Task board for PitterPattern. Tags: `effort: easy|hard`, `scope: local|light|online`.
Delegated work is always planner-reviewed (tests re-run locally) before it counts
as done.

## Environment notes

- Dev machine has Command Line Tools only — no Xcode.app yet. Everything in
  `PitterCore` builds/tests headlessly (`swift test`). App targets (`project.yml`,
  `App/`) are ready but cannot be compiled/verified until Xcode is installed.
- XcodeGen is not installed yet (`brew install xcodegen` when app work starts).
- CLT ships NEITHER swift-testing nor XCTest: swift-testing is pulled as a
  pinned package dependency (see `Package.swift`); test targets MUST also list
  `.target(name: "PitterCore")` explicitly (SPM does not auto-link `@testable`
  imports). Local-model delegations: write each file ONCE, then only fix
  compile/test errors in place — never delete and rewrite files.
- Delegation calibration so far (category `code`): fail / fail / pass-after-fixes
  — the local model produces decent single-module structure but breaks
  cross-checked details when its own tests fail to compile, then runs out
  of turns. Core implementation stays with the planner; the local model gets
  self-contained, single-file, table-heavy work only.

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

- [ ] T2.1 NotatedSequence model (concrete spelled pitches + durations + measure
      breaking + accidentals-in-context) — `effort: hard`, `scope: online`
- [ ] T2.2 MusicXML `score-partwise` writer + round-trip tests — `effort: easy`,
      `scope: local` after T2.1 spec is written
- [ ] T2.3 Pattern model (scale-relative moves) + built-in pattern catalog
      (thirds, fourths, arpeggios, …) + unit tests — `effort: easy`, `scope: local`

## Milestone 3 — Staff renderer + selection UI

- [ ] T3.1 Staff geometry + Bravura glyph renderer (SwiftUI Canvas) — `effort: hard`,
      `scope: online` (needs Xcode)
- [ ] T3.2 Selection / viewing UI with category filters, key + time signature
      controls, transpose + range controls, instrument picker — `effort: hard`,
      `scope: online` (needs Xcode)

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
