import Testing
@testable import PitterCore

// Trap paths (empty/zero/non-positive-sum deltas, start outside bounds or
// not in the scale) are documented but not trap-tested — same policy as
// the other suites. The exact sequences below pin the three-phase walk
// semantics from spec 007; expected values were hand-derived and verified
// against the algorithm (which is normative).

@Suite("Pattern")
struct PatternTests {
    private func p(_ letter: Letter, _ accidental: Accidental = .natural, octave: Int) -> Pitch {
        Pitch(letter, accidental, octave: octave)
    }

    private func cMajor() -> Scale {
        Scale(type: ScaleType.all.first { $0.id == "major" }!, tonic: Pitch(.c, octave: 4))
    }

    private func pattern(_ id: String) -> Pattern {
        Pattern.builtIns.first { $0.id == id }!
    }

    // MARK: - Catalog

    @Test func catalogInvariants() {
        #expect(Pattern.builtIns.count == 9)
        #expect(Set(Pattern.builtIns.map(\.id)).count == Pattern.builtIns.count)
        for pattern in Pattern.builtIns {
            #expect(!pattern.deltas.isEmpty)
            #expect(!pattern.deltas.contains(0))
            #expect(pattern.deltas.reduce(0, +) > 0)
        }
        let categories = Set(Pattern.builtIns.map(\.category))
        #expect(categories == [.step, .interval, .arpeggio])
    }

    // MARK: - Exact sequences (C major)

    @Test func thirdsBounded() {
        // Up-third/down-step zig to the top, retrograde down, stepwise
        // closure home.
        let run = pattern("thirds").generate(
            in: cMajor(), from: p(.c, octave: 4),
            low: p(.c, octave: 4), high: p(.g, octave: 4))
        #expect(run == [
            p(.c, octave: 4), p(.e, octave: 4), p(.d, octave: 4), p(.f, octave: 4),
            p(.e, octave: 4), p(.g, octave: 4), p(.f, octave: 4),
            p(.d, octave: 4), p(.e, octave: 4), p(.c, octave: 4), p(.d, octave: 4),
            p(.c, octave: 4),
        ])
    }

    @Test func secondsMatchesScaleRun() {
        let scale = cMajor()
        let run = pattern("seconds").generate(
            in: scale, from: p(.c, octave: 4),
            low: p(.c, octave: 4), high: p(.c, octave: 5))
        let scaleRun = scale.boundedRun(
            from: p(.c, octave: 4), low: p(.c, octave: 4), high: p(.c, octave: 5))
        #expect(run == scaleRun)
        #expect(run.count == 15)
        #expect(run.first == run.last)
    }

    @Test func tonicArpeggio() {
        let run = pattern("tonicArpeggio").generate(
            in: cMajor(), from: p(.c, octave: 4),
            low: p(.c, octave: 4), high: p(.c, octave: 5))
        #expect(run == [
            p(.c, octave: 4), p(.e, octave: 4), p(.g, octave: 4), p(.c, octave: 5),
            p(.a, octave: 4), p(.f, octave: 4), p(.c, octave: 4),
        ])
    }

    @Test func octaveDisplacement() {
        let run = pattern("octaves").generate(
            in: cMajor(), from: p(.c, octave: 4),
            low: p(.c, octave: 3), high: p(.c, octave: 5))
        #expect(run == [
            p(.c, octave: 4), p(.c, octave: 5), p(.d, octave: 4),
            p(.d, octave: 3), p(.c, octave: 4), p(.c, octave: 3),
            p(.b, octave: 3), p(.c, octave: 4),
        ])
    }

    @Test func fourthsBounded() {
        let run = pattern("fourths").generate(
            in: cMajor(), from: p(.c, octave: 4),
            low: p(.c, octave: 4), high: p(.c, octave: 5))
        #expect(run == [
            p(.c, octave: 4), p(.f, octave: 4), p(.d, octave: 4), p(.g, octave: 4),
            p(.e, octave: 4), p(.a, octave: 4), p(.f, octave: 4), p(.b, octave: 4),
            p(.g, octave: 4), p(.c, octave: 5), p(.a, octave: 4),
            p(.e, octave: 4), p(.g, octave: 4), p(.d, octave: 4), p(.f, octave: 4),
            p(.c, octave: 4), p(.e, octave: 4), p(.d, octave: 4), p(.c, octave: 4),
        ])
    }

    @Test func diatonicTriads() {
        let run = pattern("diatonicTriads").generate(
            in: cMajor(), from: p(.c, octave: 4),
            low: p(.c, octave: 4), high: p(.c, octave: 6))
        #expect(run == [
            p(.c, octave: 4), p(.e, octave: 4), p(.g, octave: 4),
            p(.d, octave: 5), p(.f, octave: 5), p(.a, octave: 5),
            p(.d, octave: 5), p(.b, octave: 4), p(.g, octave: 4),
            p(.c, octave: 4),
        ])
    }

    @Test func startAtTopBound() {
        // Phase 1 is empty (first move exceeds the top): straight into
        // the retrograde descent, then closure.
        let run = pattern("thirds").generate(
            in: cMajor(), from: p(.g, octave: 4),
            low: p(.c, octave: 4), high: p(.g, octave: 4))
        #expect(run == [
            p(.g, octave: 4),
            p(.e, octave: 4), p(.f, octave: 4), p(.d, octave: 4), p(.e, octave: 4),
            p(.c, octave: 4), p(.d, octave: 4),
            p(.e, octave: 4), p(.f, octave: 4), p(.g, octave: 4),
        ])
    }

    @Test func enharmonicStartReAnchors() {
        // B♯3 sounds C4: re-anchored onto the scale's own spelling.
        let run = pattern("thirds").generate(
            in: cMajor(), from: p(.b, .sharp, octave: 3),
            low: p(.c, octave: 4), high: p(.g, octave: 4))
        #expect(run.first == p(.c, octave: 4))
        #expect(run == pattern("thirds").generate(
            in: cMajor(), from: p(.c, octave: 4),
            low: p(.c, octave: 4), high: p(.g, octave: 4)))
    }

    // MARK: - Spelling in a flat key

    @Test func thirdsInFlatKey() {
        let ebMajor = Scale(
            type: ScaleType.all.first { $0.id == "major" }!,
            tonic: Pitch(.e, .flat, octave: 4))
        let run = pattern("thirds").generate(
            in: ebMajor, from: p(.e, .flat, octave: 4),
            low: p(.e, .flat, octave: 4), high: p(.e, .flat, octave: 5))
        #expect(run == [
            p(.e, .flat, octave: 4), p(.g, octave: 4), p(.f, octave: 4),
            p(.a, .flat, octave: 4), p(.g, octave: 4), p(.b, .flat, octave: 4),
            p(.a, .flat, octave: 4), p(.c, octave: 5), p(.b, .flat, octave: 4),
            p(.d, octave: 5), p(.c, octave: 5), p(.e, .flat, octave: 5),
            p(.d, octave: 5),
            p(.b, .flat, octave: 4), p(.c, octave: 5), p(.a, .flat, octave: 4),
            p(.b, .flat, octave: 4), p(.g, octave: 4), p(.a, .flat, octave: 4),
            p(.f, octave: 4), p(.g, octave: 4), p(.e, .flat, octave: 4),
            p(.f, octave: 4), p(.e, .flat, octave: 4),
        ])
        #expect(run.first == run.last)
    }
}
