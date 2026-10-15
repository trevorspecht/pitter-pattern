import Foundation

/// Pure layout for rendering a `NotatedSequence` as notated **systems**
/// (staff lines wrapped to a page width).
///
/// All positions are in **staff spaces**: y = spaces above the bottom staff
/// line (lines at integers 0…4, spaces at half-integers, one diatonic step
/// = 0.5), x from each measure's left edge. SMuFL glyphs anchor on the
/// baseline at their staff position, so glyph y values are baselines.
/// Glyph advance widths and vertical anchors follow the Bravura font
/// metadata (`Bravura.json`); spacing constants are tunable eyeball values
/// (spec 009).
public struct StaffLayout {
    // MARK: - Tunable metrics (staff spaces; advances from Bravura.json)

    static let clefAdvance: [Clef: Double] = [.treble: 2.68, .bass: 2.74]
    /// Glyph advance per accidental kind (Bravura).
    static let accidentalGlyphAdvance: [Accidental: Double] = [
        .sharp: 1.00, .flat: 0.90, .natural: 0.67,
        .doubleSharp: 1.00, .doubleFlat: 1.80,
    ]
    static let timeDigitAdvance = 1.88

    /// Equal gap between header elements (clef | key signature | time
    /// signature | first measure) and between header elements when there
    /// is no key signature (no space is reserved for an absent one).
    /// Also the gap between the time signature and the first notehead.
    static let headerGap = 1.5
    /// Extra gap between a continuation line's key signature and its
    /// first note (clear separation + room for a note accidental).
    static let continuationKeyGap = 0.7
    /// Extra spacing between consecutive key-signature accidentals.
    static let keyAccidentalSpacing = 0.3
    /// Extra spacing between consecutive time-signature digits.
    static let timeDigitSpacing = 0.1
    /// White space on each side of a barline: every measure carries this
    /// much leading and trailing padding, and measures abut their barlines
    /// (the next measure's origin IS the barline), so the gap is symmetric
    /// — barline → first head equals last head → barline. Generous enough
    /// to fit an accidental before the first note comfortably.
    static let barlinePadding = 2.0

    static let noteAdvance: [NoteDuration.Base: Double] = [
        .whole: 11, .half: 8, .quarter: 6.5, .eighth: 5.5,
        .sixteenth: 5, .thirtySecond: 4.5,
    ]
    static let dotAdvance = 1.2
    static let accidentalAdvance = 1.5
    static let stemLength = 3.5

    // MARK: - Layout products

    /// One placed glyph in a line's header (clef, key signature, time
    /// signature) — x is absolute within the line, y is the glyph baseline.
    public struct HeaderGlyph {
        public let glyph: Bravura.Glyph
        public let x: Double
        public let y: Double
    }

    public struct NoteLayout {
        public enum Head: Equatable {
            case notehead(Bravura.Glyph)   // whole / half / black
            case rest(Bravura.Glyph)
        }

        public let head: Head
        /// Notehead center / rest anchor x, relative to the measure origin.
        public let x: Double
        /// Half the head's visual width (whole heads are wider than
        /// black/half heads): used for pinning, ties, and glyph placement.
        public let headHalfWidth: Double
        /// Glyph baseline y (spaces above the bottom line).
        public let y: Double
        public let stemUp: Bool
        /// Flag count (eighth 1 … thirty-second 3); 0 otherwise/rests.
        public let flags: Int
        public let dots: Int
        /// Display accidental to the left of the head, if any.
        public let accidental: Bravura.Glyph?
        /// Ledger-line y values (draw segments ±0.85 around x).
        public let ledgers: [Double]
        public let tiedToNext: Bool
        public let isRest: Bool
    }

    public struct MeasureLayout {
        public let notes: [NoteLayout]
        /// Natural advance (spaces) of each note: glyph + accidental + dots.
        public let advances: [Double]
        /// Natural width: barline padding + Σadvances + barline padding
        /// (symmetric padding on both sides of the barlines).
        public let width: Double

        /// The measure with its notes respaced to fill `targetWidth`
        /// (≥ `width`): the slack is shared equally by every gap (leading,
        /// between notes, trailing), so the notes fill the measure and sit
        /// centered in it (the last note is pinned by its head width, not
        /// its advance — advances carry trailing space). A single note is
        /// centered. Used for system justification.
        func stretched(to targetWidth: Double) -> MeasureLayout {
            guard notes.count > 1 else {
                guard let only = notes.first, targetWidth > width else { return self }
                let accidentalRoom = only.accidental != nil ? StaffLayout.accidentalAdvance : 0
                let centered = NoteLayout(
                    head: only.head,
                    x: targetWidth / 2 + accidentalRoom / 2,
                    headHalfWidth: only.headHalfWidth,
                    y: only.y, stemUp: only.stemUp,
                    flags: only.flags, dots: only.dots, accidental: only.accidental,
                    ledgers: only.ledgers, tiedToNext: only.tiedToNext, isRest: only.isRest
                )
                return MeasureLayout(notes: [centered], advances: advances, width: targetWidth)
            }
            let slack = targetWidth - width
            guard slack > 0 else { return self }
            let gapExtra = slack / Double(notes.count + 1)
            var respaced: [NoteLayout] = []
            var cursor = StaffLayout.barlinePadding + gapExtra
            for (index, note) in notes.enumerated() {
                let showsAccidental = note.accidental != nil
                let x: Double
                if index == notes.count - 1 {
                    // Last note: pinned from the right edge by its head.
                    x = targetWidth - StaffLayout.barlinePadding - gapExtra - note.headHalfWidth
                } else {
                    x = cursor + (showsAccidental ? StaffLayout.accidentalAdvance : 0)
                        + note.headHalfWidth
                }
                respaced.append(NoteLayout(
                    head: note.head, x: x, headHalfWidth: note.headHalfWidth, y: note.y,
                    stemUp: note.stemUp,
                    flags: note.flags, dots: note.dots, accidental: note.accidental,
                    ledgers: note.ledgers, tiedToNext: note.tiedToNext, isRest: note.isRest
                ))
                cursor += advances[index] + gapExtra
            }
            return MeasureLayout(notes: respaced, advances: advances, width: targetWidth)
        }
    }

    public struct TieSegment {
        public let fromX: Double
        public let toX: Double
        /// Tie y (opposite the stem side, 0.9 off the notehead).
        public let y: Double
        /// Curve bulges upward when true.
        public let bulgesUp: Bool
    }

    /// A measure placed at its absolute x within a line.
    public struct PlacedMeasure {
        public let measure: MeasureLayout
        public var origin: Double
    }

    /// One system: header glyphs + measures with absolute x positions.
    public struct Line {
        public let header: [HeaderGlyph]
        /// Measures with absolute origins (relative to the line origin).
        public let measures: [PlacedMeasure]
        /// Thin barlines between/after measures (absolute x).
        public let barlines: [Double]
        /// The last measure of the last system ends with a final
        /// (thin + thick) barline drawn at the last barline x.
        public let isLast: Bool
        /// Ties within this line (ties never cross systems in v1).
        public let ties: [TieSegment]
        /// Total width in staff spaces.
        public let width: Double
    }

    public let clef: Clef
    /// Measures with note positions relative to each measure's origin.
    public let measures: [MeasureLayout]
    private let keySignature: KeySignature
    private let timeSignature: TimeSignature

    // MARK: - Construction

    public init(_ sequence: NotatedSequence) {
        let context = sequence.context
        clef = context.clef
        keySignature = context.key.keySignature
        timeSignature = context.timeSignature
        let refIndex = Self.referenceIndex(for: context.clef)

        var measures: [MeasureLayout] = []
        for measure in sequence.measures {
            var notes: [NoteLayout] = []
            var advances: [Double] = []
            // Natural layout: leading padding, then advance-based spacing
            // for all but the last note, which is pinned by its head width
            // so the measure ends with symmetric padding (advances carry
            // trailing space that would otherwise pile up on the right).
            // A lone note gets its advance as the measure width with the
            // accidental + head group centered in it.
            let noteCount = measure.count
            var width = Self.barlinePadding * 2

            if noteCount == 1 {
                let note = measure[0]
                advances.append(Self.advance(of: note))
                width += Self.advance(of: note)
                let accidentalRoom = note.accidental != nil ? Self.accidentalAdvance : 0
                notes.append(Self.layout(
                    note, x: width / 2 + accidentalRoom / 2, refIndex: refIndex))
            } else {
                var cursor = Self.barlinePadding
                for (index, note) in measure.enumerated() {
                    let advance = Self.advance(of: note)
                    advances.append(advance)
                    let headHalf = Self.headHalfWidth(for: Self.headKind(of: note))
                    if index == noteCount - 1 {
                        // Last note: pinned from the right edge by its head.
                        let x = Self.barlinePadding + headHalf
                        notes.append(Self.layout(note, x: width - x, refIndex: refIndex))
                    } else {
                        let showsAccidental = note.accidental != nil
                        let x = cursor + (showsAccidental ? Self.accidentalAdvance : 0)
                            + headHalf
                        notes.append(Self.layout(note, x: x, refIndex: refIndex))
                        cursor += advance
                        width += advance
                    }
                }
                // The last note contributes only its head width.
                width += 2 * Self.headHalfWidth(for: Self.headKind(of: measure[noteCount - 1]))
            }

            measures.append(MeasureLayout(notes: notes, advances: advances, width: width))
        }

        self.measures = measures
    }

    // MARK: - System wrapping

    /// Lays measures out as systems wrapped to `contentWidth` (spaces):
    /// whole measures only. The first system is filled as full as it
    /// fits; following systems match the first system's count; the last
    /// system takes the remainder (e.g. 7 measures fitting 3 per line →
    /// 3 + 3 + 1, not 3 + 2 + 2). The first system carries clef + key
    /// signature + time signature; continuation systems carry clef + key
    /// signature (standard practice, with extra room after the key
    /// signature for a note accidental). All systems except the last are
    /// **justified**: each measure is stretched so the notes fill it and
    /// sit centered, and the system exactly spans `contentWidth`; the
    /// last system keeps natural spacing (ragged, standard practice).
    /// The final measure of the final system ends with a final barline.
    public func lines(contentWidth: Double) -> [Line] {
        let gap = Self.headerGap
        let clefWidth = Self.clefAdvance[clef]! + gap
        let keyWidth = keySignature.accidentalsInOrder.isEmpty
            ? 0
            : keySignature.accidentalsInOrder.reduce(0.0) { total, _ in
                  total + Self.keyAccidentalSlot(keySignature)
              } + gap
        let timeWidth = digitCount(timeSignature.numerator) * Self.timeDigitAdvance
            + Self.timeDigitSpacing + gap

        let firstHeaderWidth = clefWidth + keyWidth + timeWidth
        // Continuation systems leave extra room after the key signature
        // (clear separation + accidental room on the first note).
        let continuationHeaderWidth = clefWidth + keyWidth
            + (keySignature.accidentalsInOrder.isEmpty ? 0 : Self.continuationKeyGap)

        // Header glyphs for a line starting at x = 0.
        func header(includeTime: Bool) -> [HeaderGlyph] {
            var glyphs: [HeaderGlyph] = []
            var cursor = 0.0
            // Clef: gClef anchors on the G4 line (y=1), fClef on F3 (y=3).
            glyphs.append(HeaderGlyph(
                glyph: clef == .treble ? .gClef : .fClef, x: cursor, y: clef == .treble ? 1 : 3))
            cursor += Self.clefAdvance[clef]! + gap
            // Key signature.
            let sharp = keySignature.sharpsOrFlats > 0
            let accidentalGlyph: Bravura.Glyph = sharp ? .accidentalSharp : .accidentalFlat
            let positions = Self.keySignaturePositions(
                order: keySignature.accidentalsInOrder, sharps: sharp,
                refIndex: Self.referenceIndex(for: clef))
            for y in positions {
                glyphs.append(HeaderGlyph(
                    glyph: accidentalGlyph, x: cursor, y: y))
                cursor += Self.keyAccidentalSlot(keySignature)
            }
            if !keySignature.accidentalsInOrder.isEmpty { cursor += gap }
            // Time signature: digits span the staff (numerator baseline 3,
            // denominator baseline 1 — Bravura digits are symmetric ±1).
            if includeTime {
                for (index, char) in String(timeSignature.numerator).enumerated() {
                    glyphs.append(HeaderGlyph(
                        glyph: .digit(Int(String(char))!),
                        x: cursor + Double(index) * Self.timeDigitAdvance, y: 3))
                }
                for (index, char) in String(timeSignature.denominator).enumerated() {
                    glyphs.append(HeaderGlyph(
                        glyph: .digit(Int(String(char))!),
                        x: cursor + Double(index) * Self.timeDigitAdvance, y: 1))
                }
            }
            return glyphs
        }

        guard !measures.isEmpty else {
            let glyphs = header(includeTime: true)
            return [Line(header: glyphs, measures: [], barlines: [],
                         isLast: true, ties: [], width: firstHeaderWidth)]
        }

        // Max measures per system (the first system is the tightest).
        let capacity = max(4, contentWidth - firstHeaderWidth)
        var maxPerLine = 0
        var used = 0.0
        for measure in measures {
            if maxPerLine > 0, used + measure.width > capacity { break }
            used += measure.width
            maxPerLine += 1
        }
        if maxPerLine == 0 { maxPerLine = 1 }

        // Fill the first line as full as it fits; following lines match
        // it; the last line takes the remainder (user preference — a
        // consistent count reads better than balancing).
        var counts: [Int] = []
        var remaining = measures.count
        while remaining > maxPerLine {
            counts.append(maxPerLine)
            remaining -= maxPerLine
        }
        counts.append(remaining)

        var lines: [Line] = []
        var next = 0
        for (lineIndex, count) in counts.enumerated() {
            let isFirst = lineIndex == 0
            let isLast = lineIndex == counts.count - 1
            var placed: [PlacedMeasure] = []

            for _ in 0..<count {
                placed.append(PlacedMeasure(measure: measures[next], origin: 0))
                next += 1
            }

            // Justification: stretch each measure so the line exactly
            // spans contentWidth (the last line stays ragged).
            if !isLast, count > 0 {
                let naturalSpan = placed.reduce(0.0) { $0 + $1.measure.width }
                let usable = contentWidth - (isFirst ? firstHeaderWidth : continuationHeaderWidth)
                let extra = usable - naturalSpan
                if extra > 0 {
                    let perMeasure = extra / Double(count)
                    placed = placed.map {
                        PlacedMeasure(measure: $0.measure.stretched(to: $0.measure.width + perMeasure), origin: 0)
                    }
                }
            }

            // Origins and barlines, from the (possibly stretched) widths.
            // Measures abut their barlines: the next origin IS the
            // barline (each side contributes its own padding).
            var barlines: [Double] = []
            var cursor = isFirst ? firstHeaderWidth : continuationHeaderWidth
            for index in placed.indices {
                placed[index].origin = cursor
                barlines.append(cursor + placed[index].measure.width)
                cursor += placed[index].measure.width
            }

            // Ties within this line (v1: ties never cross systems).
            var ties: [TieSegment] = []
            for (measureIndex, placedMeasure) in placed.enumerated() {
                let measure = placedMeasure.measure
                let origin = placedMeasure.origin
                for (noteIndex, note) in measure.notes.enumerated() where note.tiedToNext {
                    var following: (NoteLayout, Double)?
                    if noteIndex + 1 < measure.notes.count {
                        following = (measure.notes[noteIndex + 1], origin)
                    } else if measureIndex + 1 < placed.count {
                        let nextPair = placed[measureIndex + 1]
                        following = (nextPair.measure.notes.first!, nextPair.origin)
                    }
                    guard let (nextNote, nextOrigin) = following else { continue }
                    let fromX = origin + note.x + note.headHalfWidth + 0.1
                    let toX = nextOrigin + nextNote.x - nextNote.headHalfWidth - 0.1
                    ties.append(TieSegment(
                        fromX: fromX,
                        toX: toX,
                        y: note.y + (note.stemUp ? -0.9 : 0.9),
                        bulgesUp: !note.stemUp
                    ))
                }
            }

            lines.append(Line(
                header: header(includeTime: isFirst),
                measures: placed,
                barlines: barlines,
                isLast: isLast,
                ties: ties,
                width: max(cursor, isFirst ? firstHeaderWidth : continuationHeaderWidth)
            ))
        }

        return lines
    }

    // MARK: - Default scale

    /// The staff-space point size that fits `targetMeasuresPerLine`
    /// measures on a system of `referenceWidth` points (default: the
    /// 8.5 × 11 portrait page, 612 pt wide, 4 measures per line —
    /// 1 pt = 1/72 inch). A 5% safety margin keeps rounding from
    /// dropping the target count. Zoom multiplies this base.
    public func defaultScale(
        referenceWidth: Double = 612,
        targetMeasuresPerLine: Int = 4,
        sideMargin: Double = 2.5
    ) -> Double {
        let gap = Self.headerGap
        let clefWidth = Self.clefAdvance[clef]! + gap
        let keyWidth = keySignature.accidentalsInOrder.isEmpty
            ? 0
            : keySignature.accidentalsInOrder.reduce(0.0) { total, _ in
                  total + Self.keyAccidentalSlot(keySignature)
              } + gap
        let timeWidth = digitCount(timeSignature.numerator) * Self.timeDigitAdvance
            + Self.timeDigitSpacing + gap
        let headerWidth = clefWidth + keyWidth + timeWidth

        let target = max(1, targetMeasuresPerLine)
        // Size on the first `target` measures (those compete for the first
        // system); short sequences fill the remainder with the average
        // measure width so the staff keeps a normal size.
        let averageWidth = measures.isEmpty
            ? 4 * Self.noteAdvance[.quarter]! + 2 * Self.barlinePadding
            : measures.reduce(0.0) { $0 + $1.width } / Double(measures.count)
        let prefixWidth = measures.prefix(target).reduce(0.0) { $0 + $1.width }
        let filler = Double(max(0, target - measures.count)) * averageWidth
        let measureSpan = prefixWidth + filler
        let needed = headerWidth + measureSpan + 2 * sideMargin
        return referenceWidth / (needed * 1.05)
    }

    // MARK: - Geometry

    /// Natural advance (spaces) of a notated event: base advance + dots
    /// + display-accidental room.
    static func advance(of note: NotatedNote) -> Double {
        Self.noteAdvance[note.duration.base]!
            + Self.dotAdvance * Double(note.duration.dots)
            + (note.accidental != nil ? Self.accidentalAdvance : 0)
    }

    /// The head kind for a notated event.
    static func headKind(of note: NotatedNote) -> NoteLayout.Head {
        switch note.sound {
        case .note:
            return .notehead(Self.noteheadGlyph(for: note.duration.base))
        case .rest:
            return .rest(.rest(for: note.duration.base))
        }
    }

    /// The notehead glyph for a duration base.
    static func noteheadGlyph(for base: NoteDuration.Base) -> Bravura.Glyph {
        switch base {
        case .whole: return .noteheadWhole
        case .half: return .noteheadHalf
        default: return .noteheadBlack
        }
    }

    /// Half the visual head width for a head kind (whole heads are wider).
    static func headHalfWidth(for head: NoteLayout.Head) -> Double {
        if case .notehead(.noteheadWhole) = head { return 0.85 }
        return 0.6
    }

    /// The layout for a notated event at `x` (relative to its measure's
    /// origin).
    static func layout(_ note: NotatedNote, x: Double, refIndex: Int) -> NoteLayout {
        let head = Self.headKind(of: note)
        let glyphY: Double
        let isRest: Bool
        switch note.sound {
        case .note(let pitch):
            glyphY = Self.y(of: pitch, refIndex: refIndex)
            isRest = false
        case .rest:
            glyphY = Self.restBaseline(for: note.duration.base)
            isRest = true
        }
        return NoteLayout(
            head: head,
            x: x,
            headHalfWidth: Self.headHalfWidth(for: head),
            y: glyphY,
            stemUp: isRest ? true : glyphY <= 2,
            flags: isRest ? 0 : Self.flagCount(note.duration.base),
            dots: note.duration.dots,
            accidental: note.accidental.map(Bravura.Glyph.accidental),
            ledgers: isRest ? [] : Self.ledgerLines(forY: glyphY),
            tiedToNext: note.tiedToNext,
            isRest: isRest
        )
    }

    /// Diatonic index of the bottom staff line for a clef
    /// (treble E4 = 30, bass G2 = 18).
    static func referenceIndex(for clef: Clef) -> Int {
        switch clef {
        case .treble: return 4 * 7 + Letter.e.rawValue   // E4
        case .bass: return 2 * 7 + Letter.g.rawValue     // G2
        }
    }

    /// y (spaces above the bottom line) for a pitch: one diatonic
    /// step = 0.5; lines at integers, spaces at half-integers.
    static func y(of pitch: Pitch, refIndex: Int) -> Double {
        let index = pitch.octave * 7 + pitch.letter.rawValue
        return Double(index - refIndex) / 2
    }

    /// Ledger-line y values for a note at `y`: integers from one space
    /// beyond the staff up to (and including, for line notes) the note.
    static func ledgerLines(forY y: Double) -> [Double] {
        var lines: [Double] = []
        if y > 4 {
            var line = 5.0
            while line <= y {
                lines.append(line)
                line += 1
            }
        } else if y < 0 {
            var line = -1.0
            while line >= y {
                lines.append(line)
                line -= 1
            }
        }
        return lines
    }

    /// Key-signature accidental y positions: the first accidental sits at
    /// the highest in-staff position of its letter (F on the top line in
    /// treble, B on the middle line); each following accidental is a
    /// fourth away (sharps down, flats up), jumping an octave when it
    /// would cross the wrap threshold (sharps: the 2nd line, flats: the
    /// top line). Reproduces standard placement for all treble keys and
    /// bass keys up to 4 accidentals; deeper bass keys are unverified
    /// eyeball-wise (v1).
    static func keySignaturePositions(
        order: [Letter],
        sharps: Bool,
        refIndex: Int
    ) -> [Double] {
        guard let first = order.first else { return [] }
        var index = Self.highestInStaffIndex(letter: first, refIndex: refIndex)
        var positions: [Double] = []
        for position in order.indices {
            if position > 0 {
                index += sharps ? -3 : 3
                let y = Double(index - refIndex) / 2
                if sharps ? y <= 1 : y >= 4 {
                    // Wrap the octave: sharps jump up a 5th, flats down a 5th.
                    index += sharps ? 7 : -7
                }
            }
            positions.append(Double(index - refIndex) / 2)
        }
        return positions
    }

    /// The diatonic index of the highest in-staff (y in 0…4) position of
    /// a letter.
    static func highestInStaffIndex(letter: Letter, refIndex: Int) -> Int {
        var best: Int?
        for octave in 2...6 {
            let index = octave * 7 + letter.rawValue
            let y = Double(index - refIndex) / 2
            if (0...4).contains(y) {
                best = index
            }
        }
        return best ?? (4 * 7 + letter.rawValue)
    }

    /// Rest baseline y per duration base, from the Bravura bounding boxes:
    /// whole hangs from the 2nd line from the top (y=3), half sits on the
    /// middle line (y=2), smaller rests center on the middle line
    /// (their boxes are symmetric ±1 / ±2 around the baseline, so the
    /// baseline shifts up accordingly).
    static func restBaseline(for base: NoteDuration.Base) -> Double {
        switch base {
        case .whole: return 3
        case .half: return 2
        case .quarter: return 2      // box ±1.5 → spans 0.5…3.5
        case .eighth: return 2.15    // box −1.0…+0.7 → centered
        case .sixteenth: return 2.64 // box −2.0…+0.72 → centered
        case .thirtySecond: return 2.15
        }
    }

    static func flagCount(_ base: NoteDuration.Base) -> Int {
        switch base {
        case .whole, .half, .quarter: return 0
        case .eighth: return 1
        case .sixteenth: return 2
        case .thirtySecond: return 3
        }
    }

    /// Horizontal slot of one key-signature accidental: glyph advance
    /// (sharp 1.0 / flat 0.9 per Bravura) plus inter-accidental spacing.
    private static func keyAccidentalSlot(_ signature: KeySignature) -> Double {
        let glyphAdvance = Self.accidentalGlyphAdvance[signature.sharpsOrFlats > 0 ? .sharp : .flat]!
        return glyphAdvance + Self.keyAccidentalSpacing
    }

    private func digitCount(_ value: Int) -> Double {
        Double(String(value).count)
    }
}
