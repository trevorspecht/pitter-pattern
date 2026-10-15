import Testing
@testable import PitterCore

// Pins the staff-geometry math (spec 009): pitch→y mapping, ledger lines,
// key-signature placement (the fourths-with-octave-wrap rule), rest
// baselines, flag counts, header spacing, and system wrapping.

@Suite("StaffLayout")
struct StaffLayoutTests {
    private func p(_ letter: Letter, _ accidental: Accidental = .natural, octave: Int) -> Pitch {
        Pitch(letter, accidental, octave: octave)
    }

    private func context(
        key: Key = .major(.c),
        time: TimeSignature = .common,
        clef: Clef = .treble
    ) -> NotationContext {
        NotationContext(key: key, timeSignature: time, clef: clef)
    }

    private var trebleRef: Int { StaffLayout.referenceIndex(for: .treble) }
    private var bassRef: Int { StaffLayout.referenceIndex(for: .bass) }

    // MARK: - Pitch → y

    @Test func treblePitchPositions() {
        let ref = trebleRef
        #expect(StaffLayout.y(of: p(.e, octave: 4), refIndex: ref) == 0)      // bottom line
        #expect(StaffLayout.y(of: p(.g, octave: 4), refIndex: ref) == 1)      // 2nd line (G clef curl)
        #expect(StaffLayout.y(of: p(.b, octave: 4), refIndex: ref) == 2)      // middle line
        #expect(StaffLayout.y(of: p(.c, octave: 5), refIndex: ref) == 2.5)
        #expect(StaffLayout.y(of: p(.f, octave: 5), refIndex: ref) == 4)      // top line
        #expect(StaffLayout.y(of: p(.c, octave: 6), refIndex: ref) == 6)
        #expect(StaffLayout.y(of: p(.c, octave: 4), refIndex: ref) == -1)     // middle C ledger
        #expect(StaffLayout.y(of: p(.d, octave: 4), refIndex: ref) == -0.5)
        #expect(StaffLayout.y(of: p(.b, octave: 3), refIndex: ref) == -1.5)
        #expect(StaffLayout.y(of: p(.a, octave: 3), refIndex: ref) == -2)
    }

    @Test func bassPitchPositions() {
        let ref = bassRef
        #expect(StaffLayout.y(of: p(.g, octave: 2), refIndex: ref) == 0)      // bottom line
        #expect(StaffLayout.y(of: p(.d, octave: 3), refIndex: ref) == 2)      // middle line
        #expect(StaffLayout.y(of: p(.f, octave: 3), refIndex: ref) == 3)      // F clef dots
        #expect(StaffLayout.y(of: p(.a, octave: 3), refIndex: ref) == 4)      // top line
        #expect(StaffLayout.y(of: p(.c, octave: 4), refIndex: ref) == 5)      // ledger above
        #expect(StaffLayout.y(of: p(.e, octave: 2), refIndex: ref) == -1)     // ledger below
    }

    // MARK: - Ledger lines

    @Test func ledgerLines() {
        #expect(StaffLayout.ledgerLines(forY: 3) == [])
        #expect(StaffLayout.ledgerLines(forY: 4.5) == [])
        #expect(StaffLayout.ledgerLines(forY: -0.5) == [])
        #expect(StaffLayout.ledgerLines(forY: -1) == [-1])     // middle C, treble
        #expect(StaffLayout.ledgerLines(forY: -1.5) == [-1])   // B3 under the ledger
        #expect(StaffLayout.ledgerLines(forY: -2) == [-1, -2])
        #expect(StaffLayout.ledgerLines(forY: 5) == [5])
        #expect(StaffLayout.ledgerLines(forY: 5.5) == [5])
        #expect(StaffLayout.ledgerLines(forY: 6) == [5, 6])    // C6
    }

    // MARK: - Key signature placement

    @Test func sharpKeyPositions() {
        #expect(StaffLayout.keySignaturePositions(order: [.f], sharps: true, refIndex: trebleRef) == [4])
        #expect(StaffLayout.keySignaturePositions(order: [.f, .c, .g], sharps: true, refIndex: trebleRef) == [4, 2.5, 4.5])
        #expect(StaffLayout.keySignaturePositions(order: [.f, .c, .g, .d, .a, .e, .b], sharps: true, refIndex: trebleRef) == [4, 2.5, 4.5, 3, 1.5, 3.5, 2])
    }

    @Test func flatKeyPositions() {
        #expect(StaffLayout.keySignaturePositions(order: [.b], sharps: false, refIndex: trebleRef) == [2])
        #expect(StaffLayout.keySignaturePositions(order: [.b, .e, .a, .d], sharps: false, refIndex: trebleRef) == [2, 3.5, 1.5, 3])
        #expect(StaffLayout.keySignaturePositions(order: [.b, .e, .a, .d, .g, .c, .f], sharps: false, refIndex: trebleRef) == [2, 3.5, 1.5, 3, 1, 2.5, 0.5])
    }

    @Test func emptyKeyHasNoPositions() {
        #expect(StaffLayout.keySignaturePositions(order: [], sharps: true, refIndex: trebleRef) == [])
    }

    // MARK: - Rests and flags

    @Test func restBaselines() {
        // From the Bravura bounding boxes (spec 009).
        #expect(StaffLayout.restBaseline(for: .whole) == 3)
        #expect(StaffLayout.restBaseline(for: .half) == 2)
        #expect(StaffLayout.restBaseline(for: .quarter) == 2)
        #expect(StaffLayout.restBaseline(for: .eighth) == 2.15)
        #expect(StaffLayout.restBaseline(for: .sixteenth) == 2.64)
        #expect(StaffLayout.restBaseline(for: .thirtySecond) == 2.15)
    }

    @Test func flagCounts() {
        #expect(StaffLayout.flagCount(.whole) == 0)
        #expect(StaffLayout.flagCount(.quarter) == 0)
        #expect(StaffLayout.flagCount(.eighth) == 1)
        #expect(StaffLayout.flagCount(.sixteenth) == 2)
        #expect(StaffLayout.flagCount(.thirtySecond) == 3)
    }

    // MARK: - Header (per system)

    @Test func headerGlyphsAndTimeSignatureCentering() {
        let layout = StaffLayout(NotatedSequence(
            pitches: [p(.c, octave: 4)],
            context: context()
        ))
        let header = layout.lines(contentWidth: 1000)[0].header
        #expect(header.first?.glyph == .gClef)
        #expect(header.first?.y == 1)
        // Time-signature digits: numerator baseline 3 (top half),
        // denominator baseline 1 (bottom half) — Bravura digits are
        // symmetric ±1, so they align with the staff top/bottom.
        let digits = header.filter { $0.glyph == .timeSig4 }
        #expect(digits.map(\.y).sorted() == [1, 3])
        // Equal header gaps: clef → digits advance = clef width + gap
        // (no key signature reserves no space).
        #expect(abs(digits[0].x - (header[0].x + 2.68 + 1.5)) < 1e-9)
    }

    @Test func keySignatureGlyphsInHeader() {
        let layout = StaffLayout(NotatedSequence(
            pitches: [p(.c, octave: 4)],
            context: context(key: .major(.e, .flat))   // E♭ major: 3 flats
        ))
        let header = layout.lines(contentWidth: 1000)[0].header
        let flats = header.filter { $0.glyph == .accidentalFlat }
        #expect(flats.map(\.y) == [2, 3.5, 1.5])   // B♭ E♭ A♭
        #expect(flats.map(\.x) == flats.map(\.x).sorted())
    }

    // MARK: - Measure layout and system wrapping

    private func oneOctaveRun() -> [Pitch] {
        [
            p(.c, octave: 4), p(.d, octave: 4), p(.e, octave: 4), p(.f, octave: 4),
            p(.g, octave: 4), p(.a, octave: 4), p(.b, octave: 4), p(.c, octave: 5),
        ]
    }

    @Test func twoMeasuresOfQuarters() {
        let layout = StaffLayout(NotatedSequence(pitches: oneOctaveRun(), context: context()))
        #expect(layout.measures.count == 2)

        let first = layout.measures[0]
        #expect(first.notes.count == 4)
        #expect(first.notes.map(\.x) == first.notes.map(\.x).sorted())
        #expect(first.notes.allSatisfy { $0.flags == 0 && $0.dots == 0 })
        #expect(first.notes.allSatisfy { $0.accidental == nil })
        // C4 rides its ledger line; D4–F4 are inside the staff.
        #expect(first.notes[0].ledgers == [-1])
        #expect(first.notes.dropFirst().allSatisfy { $0.ledgers == [] })

        // One wide system: both measures; measures abut their barlines, so
        // the next origin IS the previous barline.
        let lines = layout.lines(contentWidth: 1000)
        #expect(lines.count == 1)
        #expect(lines[0].measures.count == 2)
        let gap = lines[0].measures[1].origin - lines[0].measures[0].origin
        #expect(abs(gap - first.width) < 1e-9)
        #expect(lines[0].ties.isEmpty)
        #expect(lines[0].isLast)
    }

    @Test func wrappingFavorsEqualWholeMeasures() {
        // Four measures (the demo pattern: 12 quarters + final whole).
        let major = ScaleType.all.first { $0.id == "major" }!
        let scale = Scale(type: major, tonic: Pitch(.c, octave: 4))
        let thirds = Pattern.builtIns.first { $0.id == "thirds" }!
        let run = thirds.generate(
            in: scale, from: p(.c, octave: 4),
            low: p(.c, octave: 4), high: p(.c, octave: 5))
        let seq = NotatedSequence(
            pitches: run,
            uniformDuration: .quarter,
            finalDuration: .whole,
            context: context()
        )
        // 24 quarters + final whole = 7 full 4/4 measures.
        #expect(seq.measures.count == 7)

        let layout = StaffLayout(seq)

        // Two measures per line → [2, 2, 2, 1]: following lines match
        // the first line's count, last line takes the remainder.
        let narrow = layout.lines(contentWidth: 60)
        #expect(narrow.count == 4)
        #expect(narrow.map { $0.measures.count } == [2, 2, 2, 1])

        // Three measures fit → [3, 3, 1] (not 3 + 2 + 2).
        let medium = layout.lines(contentWidth: 85)
        #expect(medium.count == 3)
        #expect(medium.map { $0.measures.count } == [3, 3, 1])

        // Four measures fit → [4, 3].
        let four = layout.lines(contentWidth: 112)
        #expect(four.count == 2)
        #expect(four.map { $0.measures.count } == [4, 3])
        // Only the first line carries the time signature.
        #expect(narrow[0].header.contains { $0.glyph == .timeSig4 })
        #expect(!narrow[1].header.contains { $0.glyph == .timeSig4 })
        // Continuation lines still carry clef + key signature.
        #expect(narrow[1].header.first?.glyph == .gClef)

        // Very narrow → one measure per line (never split).
        let tiny = layout.lines(contentWidth: 20)
        #expect(tiny.count == 7)
        #expect(tiny.allSatisfy { $0.measures.count == 1 })

        // Wide → everything on one line.
        let wide = layout.lines(contentWidth: 200)
        #expect(wide.count == 1)
        #expect(wide[0].measures.count == 7)
    }

    @Test func justificationFillsSystemsExceptTheLast() {
        let major = ScaleType.all.first { $0.id == "major" }!
        let scale = Scale(type: major, tonic: Pitch(.c, octave: 4))
        let thirds = Pattern.builtIns.first { $0.id == "thirds" }!
        let run = thirds.generate(
            in: scale, from: p(.c, octave: 4),
            low: p(.c, octave: 4), high: p(.c, octave: 5))
        let seq = NotatedSequence(
            pitches: run,
            uniformDuration: .quarter,
            finalDuration: .whole,
            context: context()
        )
        let layout = StaffLayout(seq)

        // 3 measures per line: the justified lines span exactly the
        // content width; the last line stays ragged.
        let lines = layout.lines(contentWidth: 85)
        #expect(lines.map({ $0.measures.count }) == [3, 3, 1])
        for line in lines.dropLast() {
            #expect(abs(line.barlines.last! - 85) < 1e-6)
            // Notes centered: leading and trailing gaps symmetric, and
            // (measures abut barlines) the leading gap from the BARLINE
            // equals the trailing gap to it.
            let first = line.measures[0]
            let firstNote = first.measure.notes[0]
            let leadingFromBarline = firstNote.x - firstNote.headHalfWidth
            let last = first.measure.notes[first.measure.notes.count - 1]
            let trailing = first.measure.width - (last.x + last.headHalfWidth)
            #expect(abs(leadingFromBarline - trailing) < 1e-6)
        }
        #expect(lines.last!.barlines.last! < 85)
    }

    @Test func defaultScaleTargetsFourPerLine() {
        let major = ScaleType.all.first { $0.id == "major" }!
        let scale = Scale(type: major, tonic: Pitch(.c, octave: 4))
        let thirds = Pattern.builtIns.first { $0.id == "thirds" }!
        let run = thirds.generate(
            in: scale, from: p(.c, octave: 4),
            low: p(.c, octave: 4), high: p(.c, octave: 5))
        let seq = NotatedSequence(
            pitches: run,
            uniformDuration: .quarter,
            finalDuration: .whole,
            context: context()
        )
        let layout = StaffLayout(seq)

        // On an 8.5 × 11 portrait page (612 pt wide) at the default
        // scale, four measures fit per system: [4, 3].
        let base = layout.defaultScale()
        #expect(base > 4 && base < 8)
        let contentWidth = 612 / base - 2 * 2.5
        let lines = layout.lines(contentWidth: contentWidth)
        #expect(lines.map({ $0.measures.count }) == [4, 3])
    }

    @Test func middleCUsesLedgerAndTieSegment() {
        // [half C4, whole C4] in 4/4: C4 sits on its ledger line; the
        // whole splits across the barline into a tied pair.
        let seq = NotatedSequence(
            pitches: [p(.c, octave: 4), p(.c, octave: 4)],
            durations: [.half, .whole],
            context: context()
        )
        let layout = StaffLayout(seq)
        #expect(layout.measures[0].notes.allSatisfy { $0.y == -1 && $0.ledgers == [-1] })

        let lines = layout.lines(contentWidth: 1000)
        #expect(lines.count == 1)
        #expect(lines[0].ties.count == 1)
        let tie = lines[0].ties[0]
        #expect(tie.fromX < tie.toX)
        #expect(tie.y == -1.9)      // stem up (y ≤ 2) → tie below the head
        #expect(tie.bulgesUp == false)

        // The fill rest in measure 2.
        let rest = layout.measures[1].notes.last!
        #expect(rest.isRest)
        #expect(rest.head == .rest(.restHalf))
        #expect(rest.y == 2)
    }

    @Test func accidentalShiftsNoteRight() {
        // F♯4 in C major shows a sharp: as a leading note its x includes
        // the accidental advance, and the glyph rides left of the head.
        // (A lone note is centered as accidental + head group instead.)
        let withAccidental = StaffLayout(
            NotatedSequence(pitches: [p(.f, .sharp, octave: 4), p(.g, octave: 4)], context: context())
        ).measures[0].notes[0]
        let without = StaffLayout(
            NotatedSequence(pitches: [p(.f, octave: 4), p(.g, octave: 4)], context: context())
        ).measures[0].notes[0]
        #expect(withAccidental.accidental == .accidentalSharp)
        #expect(abs(withAccidental.x - without.x - 1.5) < 1e-9)
    }
}
