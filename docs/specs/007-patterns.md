# Spec 007 — Pattern model + built-in catalog (T2.3)

A **pattern** is an ordered list of **scale-degree deltas** applied cyclically
from a start note, bounded by a range, with reflect-at-the-edge semantics —
e.g. thirds = up a 3rd, down a step (`[+2, −1]`) producing the classic
`C E D F E G F …` zig-zag. Patterns are walk *shapes*; concrete pitches come
from the `Scale` they are walked in; durations are applied later by
`NotatedSequence` (spec 006). Custom patterns (M5, D7) are out of scope here.

## `Pattern`

```swift
public struct Pattern: Hashable, Codable, Sendable, Identifiable {
    public enum Category: String, CaseIterable, Codable, Sendable, Hashable {
        case step       // runs by step
        case interval   // runs by a fixed skip interval (thirds … octaves)
        case arpeggio   // chord-shaped runs
    }
    public let id: String        // stable, e.g. "thirds"
    public let name: String      // display name, e.g. "Thirds"
    public let category: Category
    public let deltas: [Int]     // nonzero scale-degree deltas, applied cyclically
}
```

- `deltas` must be non-empty, every element nonzero, and `deltas.sum > 0`
  (the walk must ascend overall; see termination argument below).
  Enforced by `init` precondition.

## Built-in catalog — `Pattern.builtIns: [Pattern]` (static)

| id | name | category | deltas | first notes from C4 (C major) |
|----|------|----------|--------|-------------------------------|
| `seconds` | Seconds | step | `[1]` | C D E F G … |
| `thirds` | Thirds | interval | `[2, -1]` | C E D F E G F … |
| `fourths` | Fourths | interval | `[3, -2]` | C F D G E A F … |
| `fifths` | Fifths | interval | `[4, -3]` | C G E B G C5 A4 … (derive from algorithm) |
| `sixths` | Sixths | interval | `[5, -4]` | C A E B F C G D … (derive from algorithm) |
| `sevenths` | Sevenths | interval | `[6, -5]` | C B E C5 G A D … (derive from algorithm) |
| `octaves` | Octave displacement | interval | `[7, -6]` | C C5 D D5 E E5 … |
| `tonicArpeggio` | Tonic triad arpeggio | arpeggio | `[2, 2, 3]` | C E G C5 E5 G5 C6 … |
| `diatonicTriads` | Diatonic triads | arpeggio | `[2, 2, 4]` | C E G D F A E G B … |

(The "first notes" column is illustrative except where a test pins the exact
sequence; the algorithm below is normative.)

## Generation — `Pattern.generate(in:from:low:high:) -> [Pitch]`

```swift
public func generate(in scale: Scale, from start: Pitch, low: Pitch, high: Pitch) -> [Pitch]
```

Semantics — three phases, like `RangeRun` (spec 005) but with delta-cycling
moves instead of single steps:

1. **Preconditions**: `low <= high` (as MIDI), `low <= start <= high`,
   `scale.isInScale(start)` (enharmonic start allowed).
2. **Anchor**: `anchored = scale.nextUp(after: scale.nextDown(before: start))`
   — re-anchors an enharmonic start onto the scale's own spelling, in its
   ascending form (same rationale as `RangeRun`).
3. **Phase 1 — ascend**: from `anchored`, cycle `deltas[0], deltas[1], …`
   applying each delta in the up direction (`d > 0` → `nextUp` ×d, `d < 0` →
   `nextDown` ×|d|). Append each landing note **only if** it is within
   `[low, high]` (MIDI comparison, bounds constrain landing notes only —
   intermediate pitches of a multi-step move may leave the range). The first
   landing outside the bounds ends phase 1 (that note is NOT appended), and
   phase 2 begins with **the same delta index, negated** (the natural
   retrograde turnaround).
4. **Phase 2 — descend** (amended after app feedback): continue cycling
   delta indexes, applying each delta negated. A landing appends while its
   diatonic index ≥ the descent **floor** and its MIDI ≤ `high`. The floor
   is normally the 7th below the anchored start (one diatonic step under
   the root) — the classic practice ending descends past the root to the
   7th and resolves up (… E C D B C, not … E C D C) — but never cuts the
   descent shorter than `low` allows:
   `floor = min(lowIndex, anchorIndex − 1)` (octave-jumping patterns and
   mid-range starts descend past the 7th, to the low bound).
   `includeEndingSeventh: false` (default true) keeps the floor at `low`
   for instruments that cannot reach the 7th (the user can skip it).
   **This ending shape is a v1 general rule — different patterns have
   different shapes, and per-pattern ending logic will be sorted out as
   we experiment.**
5. **Phase 3 — return**: from the last appended pitch `P`, walk by single
   scale steps toward `anchored` (`P < anchored` → `nextUp`, else `nextDown`)
   until `anchored` is appended. If phase 2 ended exactly on `anchored`,
   phase 3 is empty. This guarantees the sequence ends on its starting
   pitch, like `RangeRun`.
6. Return `[anchored] + phase1 + phase2 + phase3`.

**Termination argument** (why `deltas.sum > 0` is required): within phase 1,
a repeated `(pitch, deltaIndex)` state would imply a whole number of delta
cycles with net degree change 0, but each full cycle moves `deltas.sum > 0`
degrees — impossible, so phase 1 always escapes the top bound in finitely
many steps. Phase 2 is the mirror image (net `< 0`). Phase 3 is monotonic
between two scale notes. Belt-and-braces: a max-steps guard
(`8 * (high.midi - low.midi) * deltas.count + 64` appended notes) traps on
non-termination, exactly like `RangeRun`'s guard.

**Ending caveat (documented, v1)**: patterns that skip the 7th (or whose
zig overshoots the floor, like arpeggios) end with a stepwise phase-3
closure instead of the 7th-resolve; tests pin the exact v1 sequences.

## Files

- `Sources/PitterCore/Catalog/Pattern.swift` — model + catalog + generation.
- `Tests/PitterCoreTests/PatternTests.swift` — swift-testing, exact-sequence
  tests (below) + catalog invariants (unique ids, non-empty, positive sum,
  categories covered).

## Test plan (exact expected sequences — normative)

All in C major (`ScaleType` id `"major"`, tonic C4) unless noted.

1. **Thirds, bounds C4…G4**:
   `[C4, E4, D4, F4, E4, G4, F4, D4, E4, C4, D4, C4]`
   (phase 1 `C E D F E G F`; A4 would exceed G4 → phase 2 retrograde
   `D E C D`; B3 would undercut C4 → phase 3 stepwise `C4`.)
2. **Seconds equals the scale run**: `Pattern "seconds"` from C4, bounds
   C4…C5 gives exactly `Scale.boundedRun(from: C4, low: C4, high: C5)`:
   `[C4 D4 E4 F4 G4 A4 B4 C5 B4 A4 G4 F4 E4 D4 C4]`.
3. **Tonic triad arpeggio, bounds C4…C5**: `[C4, E4, G4, C5, A4, F4, C4]`
   (up-the-triad to C5, then the descending arpeggio lands exactly home).
4. **Octave displacement, bounds C3…C5**:
   `[C4, C5, D4, D3, B3, C4]`.
5. **Fourth pattern sanity, bounds C4…C5** (pins the zig shape): derive the
   exact sequence from the algorithm, run it, and pin the observed value in
   the test. **The algorithm is normative** — if any hand-derived example in
   this spec disagrees with the implemented algorithm, the algorithm wins
   and the test pins the algorithm's output (note the discrepancy in the
   TASKS.md reviewer notes).
6. **Enharmonic start re-anchors**: thirds from `B♯3` (enharmonic C4),
   bounds C4…G4 → same sequence as test 1.
7. **Start at the top bound**: thirds from G4, bounds C4…G4 →
   phase 1 is empty (E4? no: first move +2 → B4 exceeds), phase 2 descends,
   phase 3 returns; exact sequence derived from the algorithm and pinned in
   the test after first run (algorithm is normative).
8. **Trap coverage is documented only** (precondition failures are not
   testable headlessly — same policy as RangeRun tests).
