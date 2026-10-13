/// A concrete scale: a `ScaleType` on a spelled tonic, able to generate
/// correctly spelled, octave-exact pitch sequences in either direction.
public struct Scale: Hashable, Codable, Sendable, Identifiable {
    public let type: ScaleType
    /// The spelled tonic. Accidentals beyond sharp/flat are not allowed —
    /// scales never start on double accidentals.
    public let tonic: Pitch

    public init(type: ScaleType, tonic: Pitch) {
        precondition(
            Scale.allowedTonics.contains(tonic.accidental),
            "Scale tonic cannot carry a double accidental: \(tonic.debugDescription)"
        )
        self.type = type
        self.tonic = tonic
    }

    private static let allowedTonics: Set<Accidental> = [.natural, .sharp, .flat]

    // MARK: - Display

    /// Tonic without octave, e.g. `"E♭"`, `"F♯"`, `"C"`.
    public var tonicDescription: String {
        let accidentalPart = tonic.accidental == .natural ? "" : tonic.accidental.symbol
        return tonic.letter.description + accidentalPart
    }

    /// Display name, e.g. `"E♭ Major"`, `"D Dorian"`, `"C Whole Tone"`.
    public var name: String {
        "\(tonicDescription) \(type.name)"
    }

    /// Stable slug, e.g. `"eb-major"`, `"d-dorian"`, `"c#-major"`.
    public var id: String {
        tonic.letter.description.lowercased() + tonic.accidental.description + "-" + type.id
    }

    // MARK: - Membership

    /// True when the pitch's class (semitones above the tonic, mod 12) is a
    /// scale degree, regardless of octave and spelling. Chromatic: always true.
    public func isInScale(_ pitch: Pitch) -> Bool {
        switch type.spelling {
        case .template(let degrees):
            return ascendingAnchorIndex(of: pitch, degrees: degrees) != nil
        case .chromatic: return true
        }
    }

    /// True when the pitch is spelled exactly as this scale spells its
    /// degree (chromatic: ascending *or* descending spelling matches).
    public func spelledInScale(_ pitch: Pitch) -> Bool {
        switch type.spelling {
        case .template(let degrees):
            guard let anchor = ascendingAnchorIndex(of: pitch, degrees: degrees) else { return false }
            return templatePitch(atAscendingIndex: anchor, degrees: degrees) == pitch
        case .chromatic:
            let upIndex = pitch.midiNumber - tonic.midiNumber
            return chromaticAscendingPitch(at: upIndex) == pitch
                || chromaticDescendingPitch(at: -upIndex) == pitch
        }
    }

    // MARK: - Generation

    /// Walk `count` scale degrees upward from `start`. `start` must be in
    /// the scale (enharmonic spelling is fine — the walk is anchored to the
    /// scale's own spelling at that degree, so `D♭4` in A major walks from
    /// `C♯4`).
    public func degreePitches(ascendingFrom start: Pitch, count: Int) -> [Pitch] {
        switch type.spelling {
        case .template(let degrees):
            let anchor = tryAnchor(start, degrees: degrees)
            return (0..<count).map { templatePitch(atAscendingIndex: anchor + $0, degrees: degrees) }
        case .chromatic:
            let anchor = start.midiNumber - tonic.midiNumber
            return (0..<count).map { chromaticAscendingPitch(at: anchor + $0) }
        }
    }

    /// Walk `count` scale degrees downward from `start` (same anchoring rule).
    /// Chromatic descending uses the flat-side mirror spelling.
    public func degreePitches(descendingFrom start: Pitch, count: Int) -> [Pitch] {
        switch type.spelling {
        case .template(let degrees):
            let anchor = tryAnchor(start, degrees: degrees)
            return (0..<count).map { templatePitch(atAscendingIndex: anchor - $0, degrees: degrees) }
        case .chromatic:
            let anchor = tonic.midiNumber - start.midiNumber
            return (0..<count).map { chromaticDescendingPitch(at: anchor + $0) }
        }
    }

    /// The next scale pitch above `pitch` (enharmonic anchor allowed; traps
    /// if `pitch` is not in the scale).
    public func nextUp(after pitch: Pitch) -> Pitch {
        switch type.spelling {
        case .template(let degrees):
            return templatePitch(atAscendingIndex: tryAnchor(pitch, degrees: degrees) + 1, degrees: degrees)
        case .chromatic:
            return chromaticAscendingPitch(at: pitch.midiNumber - tonic.midiNumber + 1)
        }
    }

    /// The next scale pitch below `pitch`.
    public func nextDown(before pitch: Pitch) -> Pitch {
        switch type.spelling {
        case .template(let degrees):
            return templatePitch(atAscendingIndex: tryAnchor(pitch, degrees: degrees) - 1, degrees: degrees)
        case .chromatic:
            return chromaticDescendingPitch(at: tonic.midiNumber - pitch.midiNumber + 1)
        }
    }

    /// One full cycle from `start` up to (and including) the start's pitch an
    /// octave higher: `degreesPerOctave + 1` pitches.
    public func oneOctaveAscending(from start: Pitch) -> [Pitch] {
        degreePitches(ascendingFrom: start, count: type.degreesPerOctave + 1)
    }

    /// One full cycle down from `start` to (and including) the start's pitch
    /// an octave lower.
    public func oneOctaveDescending(from start: Pitch) -> [Pitch] {
        degreePitches(descendingFrom: start, count: type.degreesPerOctave + 1)
    }

    /// A bounded out-and-back run within absolute concert-pitch bounds
    /// (spec 005, DECISIONS D3). An enharmonic start is re-anchored to the
    /// scale's own spelling.
    public func boundedRun(from start: Pitch, low: Pitch, high: Pitch) -> [Pitch] {
        RangeRun.generate(
            from: start,
            bounds: RangeBounds(low: low, high: high),
            next: { pitch, direction in
                direction == .up ? nextUp(after: pitch) : nextDown(before: pitch)
            },
            startInWalk: isInScale
        )
    }

    // MARK: - Keys & transposition

    /// The parent major key that supplies this scale's key signature
    /// (D dorian → C major; A harmonic minor → C major; E♭ natural minor →
    /// G♭ major). Falls back to the tonic's own major key when valid, then
    /// to C major.
    public var keySignatureRoot: Key {
        if let offset = type.parentMajorLetterOffset {
            let shifted = tonic.shifted(letters: offset)
            if Key.isValid(tonicLetter: shifted.letter, tonicAccidental: shifted.accidental, mode: .major) {
                return Key(tonicLetter: shifted.letter, tonicAccidental: shifted.accidental, mode: .major)
            }
            return .major(.c)
        }
        if Key.isValid(tonicLetter: tonic.letter, tonicAccidental: tonic.accidental, mode: .major) {
            return Key(tonicLetter: tonic.letter, tonicAccidental: tonic.accidental, mode: .major)
        }
        return .major(.c)
    }

    /// Transpose the whole scale by moving the tonic. Traps if the new tonic
    /// would need a double accidental (the UI restricts transpose choices so
    /// it can't).
    public func transpose(by interval: Interval) -> Scale {
        let newTonic = tonic.transposed(by: interval)
        precondition(
            Scale.allowedTonics.contains(newTonic.accidental),
            "Transposed tonic \(newTonic.debugDescription) is not a usable scale tonic"
        )
        return Scale(type: type, tonic: newTonic)
    }

    // MARK: - Template engine

    /// The unrolled degree index of a pitch in ascending-index space
    /// (0 = the tonic; `degreesPerOctave` = the tonic an octave up).
    /// Nil when the pitch's class is not in the scale.
    private func ascendingAnchorIndex(of pitch: Pitch, degrees: [ScaleDegree]) -> Int? {
        let semisFromTonic = pitch.midiNumber - tonic.midiNumber
        let classOffset = Pitch.floorMod(semisFromTonic, 12)
        guard let within = degrees.firstIndex(where: { $0.semitones == classOffset }) else {
            return nil
        }
        let cycle = (semisFromTonic - degrees[within].semitones) / 12
        return cycle * degrees.count + within
    }

    private func tryAnchor(_ pitch: Pitch, degrees: [ScaleDegree]) -> Int {
        guard let anchor = ascendingAnchorIndex(of: pitch, degrees: degrees) else {
            preconditionFailure(
                "\(pitch.debugDescription) is not in \(name)"
            )
        }
        return anchor
    }

    /// The spelled pitch at an unrolled ascending degree index. Letter math:
    /// 7 letter positions per cycle (tonic→tonic is exactly one octave),
    /// plus the degree's letter offset; the accidental is derived from the
    /// semitone target (traps if it would need more than a double accidental).
    private func templatePitch(atAscendingIndex index: Int, degrees: [ScaleDegree]) -> Pitch {
        let n = degrees.count
        let cycle = Pitch.floorDiv(index, n)
        let within = index - cycle * n
        let degree = degrees[within]

        let shifted = tonic.shifted(letters: 7 * cycle + degree.letterOffset)
        let targetMIDI = tonic.midiNumber + 12 * cycle + degree.semitones
        let naturalMIDI = 12 * (shifted.octave + 1) + shifted.letter.naturalSemitonesFromC
        let offset = targetMIDI - naturalMIDI
        guard let accidental = Accidental(rawValue: offset) else {
            preconditionFailure(
                "Scale \(name): degree \(within) in cycle \(cycle) is unspellable "
                    + "(needs \(offset) semitones of accidental)"
            )
        }
        return Pitch(shifted.letter, accidental, octave: shifted.octave)
    }

    // MARK: - Chromatic engine

    /// One octave of ascending chromatic spelling from the tonic
    /// (index 0 = tonic, 1...11 = steps, 12 = tonic an octave up, spelled
    /// like the tonic — the octave endpoint keeps the tonic's spelling).
    private var chromaticAscendingTable: [Pitch] {
        var table: [Pitch] = [tonic]
        var current = tonic
        for _ in 1...11 {
            current = Scale.chromaticStepUp(from: current)
            table.append(current)
        }
        table.append(tonic.shifted(octaves: 1))
        return table
    }

    /// One octave of descending (flat-side) chromatic spelling.
    private var chromaticDescendingTable: [Pitch] {
        var table: [Pitch] = [tonic]
        var current = tonic
        for _ in 1...11 {
            current = Scale.chromaticStepDown(from: current)
            table.append(current)
        }
        table.append(tonic.shifted(octaves: -1))
        return table
    }

    /// The spelled pitch `index` semitones above the tonic (any integer index;
    /// index ≡ 0 mod 12 is the tonic's own spelling an octave away).
    private func chromaticAscendingPitch(at index: Int) -> Pitch {
        let cycle = Pitch.floorDiv(index, 12)
        let within = index - cycle * 12
        guard within > 0 else { return tonic.shifted(octaves: cycle) }
        return chromaticAscendingTable[within].shifted(octaves: cycle)
    }

    /// The spelled pitch `index` semitones below the tonic (flat-side mirror
    /// spelling; index ≡ 0 mod 12 is the tonic's own spelling).
    private func chromaticDescendingPitch(at index: Int) -> Pitch {
        let cycle = Pitch.floorDiv(index, 12)
        let within = index - cycle * 12
        guard within > 0 else { return tonic.shifted(octaves: -cycle) }
        return chromaticDescendingTable[within].shifted(octaves: -cycle)
    }

    /// Sharp-side chromatic step rule (see spec 003).
    private static func chromaticStepUp(from pitch: Pitch) -> Pitch {
        switch pitch.accidental {
        case .doubleFlat, .flat:
            return Pitch(pitch.letter, Accidental(rawValue: pitch.accidental.rawValue + 1)!, octave: pitch.octave)
        case .natural:
            // E→F and B→C are the single-semitone letter gaps.
            if pitch.letter == .e || pitch.letter == .b {
                return Pitch(pitch.letter.next, octave: pitch.octave + (pitch.letter == .b ? 1 : 0))
            }
            return Pitch(pitch.letter, .sharp, octave: pitch.octave)
        case .sharp:
            return Pitch(pitch.letter.next, octave: pitch.octave + (pitch.letter == .b ? 1 : 0))
        case .doubleSharp:
            preconditionFailure("Chromatic spelling from \(pitch.debugDescription) is not defined")
        }
    }

    /// Flat-side mirror step rule for descending chromatic (see spec 003).
    private static func chromaticStepDown(from pitch: Pitch) -> Pitch {
        switch pitch.accidental {
        case .doubleSharp, .sharp:
            return Pitch(pitch.letter, Accidental(rawValue: pitch.accidental.rawValue - 1)!, octave: pitch.octave)
        case .natural:
            // F→E and C→B are the single-semitone letter gaps.
            if pitch.letter == .f || pitch.letter == .c {
                return Pitch(pitch.letter.previous, octave: pitch.octave + (pitch.letter == .c ? -1 : 0))
            }
            return Pitch(pitch.letter, .flat, octave: pitch.octave)
        case .flat:
            return Pitch(pitch.letter.previous, octave: pitch.octave + (pitch.letter == .c ? -1 : 0))
        case .doubleFlat:
            preconditionFailure("Chromatic spelling from \(pitch.debugDescription) is not defined")
        }
    }
}

extension Pitch {
    /// Floor modulo (Swift's `%` truncates toward zero, wrong for negatives).
    static func floorMod(_ a: Int, _ b: Int) -> Int {
        let r = a % b
        return r < 0 ? r + b : r
    }
}
