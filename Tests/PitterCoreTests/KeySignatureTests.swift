import Testing
@testable import PitterCore

// Trap tests for invalid key tonics are expressed via `Key.isValid(...)`
// instead — `preconditionFailure` aborts the process, so swift-testing
// cannot catch it directly. The initializer traps when `isValid` is false,
// which these tests pin down from both sides.

@Suite("KeySignature")
struct KeySignatureTests {
    @Test func bounds() {
        #expect(KeySignature(sharpsOrFlats: 0).isEmpty)
        #expect(!KeySignature(sharpsOrFlats: 3).isEmpty)
        #expect(KeySignature(sharpsOrFlats: 3).sharps == 3)
        #expect(KeySignature(sharpsOrFlats: 3).flats == 0)
        #expect(KeySignature(sharpsOrFlats: -3).flats == 3)
        #expect(KeySignature(sharpsOrFlats: -3).sharps == 0)
    }

    @Test func accidentalOrders() {
        let sharpOrder: [Letter] = [.f, .c, .g, .d, .a, .e, .b]
        let flatOrder: [Letter] = [.b, .e, .a, .d, .g, .c, .f]
        for n in 1...7 {
            #expect(KeySignature(sharpsOrFlats: n).accidentalsInOrder == Array(sharpOrder[..<n]))
            #expect(KeySignature(sharpsOrFlats: -n).accidentalsInOrder == Array(flatOrder[..<n]))
        }
        #expect(KeySignature(sharpsOrFlats: 0).accidentalsInOrder.isEmpty)
    }

    @Test func accidentalForLetter() {
        // Regression: only this signature's accidentals count, not the full
        // order (A major = F♯ C♯ G♯ — D stays natural).
        let aMajor = KeySignature(sharpsOrFlats: 3)
        #expect(aMajor.accidental(for: .f) == .sharp)
        #expect(aMajor.accidental(for: .c) == .sharp)
        #expect(aMajor.accidental(for: .g) == .sharp)
        #expect(aMajor.accidental(for: .d) == .natural)
        #expect(aMajor.accidental(for: .a) == .natural)
        #expect(aMajor.accidental(for: .e) == .natural)
        #expect(aMajor.accidental(for: .b) == .natural)

        let eFlatMajor = KeySignature(sharpsOrFlats: -3)
        #expect(eFlatMajor.accidental(for: .b) == .flat)
        #expect(eFlatMajor.accidental(for: .e) == .flat)
        #expect(eFlatMajor.accidental(for: .a) == .flat)
        #expect(eFlatMajor.accidental(for: .f) == .natural)
        #expect(eFlatMajor.accidental(for: .c) == .natural)

        #expect(KeySignature(sharpsOrFlats: 0).accidental(for: .f) == .natural)
    }

    @Test func descriptions() {
        #expect(KeySignature(sharpsOrFlats: 0).description == "no accidentals")
        #expect(KeySignature(sharpsOrFlats: 1).description == "1 sharp (F♯)")
        #expect(KeySignature(sharpsOrFlats: 2).description == "2 sharps (F♯ C♯)")
        #expect(KeySignature(sharpsOrFlats: -1).description == "1 flat (B♭)")
        #expect(KeySignature(sharpsOrFlats: -3).description == "3 flats (B♭ E♭ A♭)")
    }
}

@Suite("Key")
struct KeyTests {
    // (key, expected sharpsOrFlats) — the full circle of fifths.
    private static let majorCircle: [(Key, Int)] = KeyTests.makeMajorCircle()
    private static let minorCircle: [(Key, Int)] = KeyTests.makeMinorCircle()

    private static func makeMajorCircle() -> [(Key, Int)] { [//swift-format:ignore
        (.major(.c), 0), (.major(.g), 1), (.major(.d), 2), (.major(.a), 3),
        (.major(.e), 4), (.major(.b), 5), (.major(.f, .sharp), 6), (.major(.c, .sharp), 7),
        (.major(.f), -1), (.major(.b, .flat), -2), (.major(.e, .flat), -3),
        (.major(.a, .flat), -4), (.major(.d, .flat), -5), (.major(.g, .flat), -6),
        (.major(.c, .flat), -7),
        ] }

    private static func makeMinorCircle() -> [(Key, Int)] { [//swift-format:ignore
        (.minor(.a), 0), (.minor(.e), 1), (.minor(.b), 2), (.minor(.f, .sharp), 3),
        (.minor(.c, .sharp), 4), (.minor(.g, .sharp), 5), (.minor(.d, .sharp), 6),
        (.minor(.a, .sharp), 7),
        (.minor(.d), -1), (.minor(.g), -2), (.minor(.c), -3), (.minor(.f), -4),
        (.minor(.b, .flat), -5), (.minor(.e, .flat), -6), (.minor(.a, .flat), -7),
        ] }

    @Test func allMajorKeys() {
        for (key, expected) in KeyTests.majorCircle {
            #expect(key.keySignature.sharpsOrFlats == expected,
                    "\(key.description) expected \(expected)")
        }
    }

    @Test func allMinorKeys() {
        for (key, expected) in KeyTests.minorCircle {
            #expect(key.keySignature.sharpsOrFlats == expected,
                    "\(key.description) expected \(expected)")
        }
    }

    @Test func keySignatureSpelling() {
        // E♭ major: B♭ E♭ A♭; everything else natural.
        let eFlat = Key.major(.e, .flat)
        #expect(eFlat.keySignature.accidentalsInOrder == [.b, .e, .a])
        #expect(eFlat.spell(.a) == .flat)
        #expect(eFlat.spell(.c) == .natural)
        #expect(eFlat.spell(.f) == .natural)

        // B minor: C♯ F♯.
        #expect(Key.minor(.b).keySignature.accidentalsInOrder == [.f, .c])

        // C major / A minor: empty.
        #expect(Key.major(.c).keySignature.isEmpty)
        #expect(Key.minor(.a).keySignature.isEmpty)
    }

    @Test func extremeSignatures() {
        // C♯ major (7 sharps) spells B♯.
        #expect(Key.major(.c, .sharp).spell(.b) == .sharp)
        // C♭ major (7 flats) spells F♭ and B♭.
        #expect(Key.major(.c, .flat).spell(.f) == .flat)
        #expect(Key.major(.c, .flat).spell(.b) == .flat)
    }

    @Test func validation() {
        // Every conventional tonic is valid.
        for (key, _) in KeyTests.majorCircle + KeyTests.minorCircle {
            #expect(Key.isValid(
                tonicLetter: key.tonicLetter,
                tonicAccidental: key.tonicAccidental,
                mode: key.mode))
        }
        // Invalid tonics: not on the circle of fifths.
        #expect(!Key.isValid(tonicLetter: .a, tonicAccidental: .sharp, mode: .major))
        #expect(!Key.isValid(tonicLetter: .d, tonicAccidental: .sharp, mode: .major))
        #expect(!Key.isValid(tonicLetter: .f, tonicAccidental: .flat, mode: .major))
        #expect(!Key.isValid(tonicLetter: .g, tonicAccidental: .flat, mode: .minor))
        #expect(!Key.isValid(tonicLetter: .d, tonicAccidental: .flat, mode: .minor))
        #expect(!Key.isValid(tonicLetter: .e, tonicAccidental: .sharp, mode: .minor))
        // Double accidentals never appear on the circle of fifths.
        #expect(!Key.isValid(tonicLetter: .b, tonicAccidental: .sharp, mode: .major))
        #expect(!Key.isValid(tonicLetter: .a, tonicAccidental: .doubleFlat, mode: .minor))
    }

    @Test func relativeKeys() {
        #expect(Key.minor(.e).relativeMajor == .major(.g))
        #expect(Key.minor(.b, .flat).relativeMajor == .major(.d, .flat))
        #expect(Key.minor(.g, .sharp).relativeMajor == .major(.b))
        #expect(Key.minor(.c, .sharp).relativeMajor == .major(.e))
        #expect(Key.minor(.e, .flat).relativeMajor == .major(.g, .flat))

        #expect(Key.major(.b, .flat).relativeMinor == .minor(.g))
        #expect(Key.major(.c, .flat).relativeMinor == .minor(.a, .flat))
        #expect(Key.major(.c, .sharp).relativeMinor == .minor(.a, .sharp))
        #expect(Key.major(.f, .sharp).relativeMinor == .minor(.d, .sharp))
    }

    @Test func descriptions() {
        #expect(Key.major(.e, .flat).description == "E♭ major")
        #expect(Key.minor(.f, .sharp).description == "F♯ minor")
        #expect(Key.major(.c).description == "C major")
        #expect(Key.major(.e, .flat).tonicDescription == "E♭")
    }
}
