import Testing
@testable import PitterCore

// Known limitation (documented in spec 003 / DECISIONS): fixed letter
// templates can yield enharmonically-correct but unconventional spellings
// for gapped scales (blues, diminished) on sharp/flat tonics — e.g. E♯ where
// F♮ is conventional. The required cases below use conventional tonics; a
// spelling-preference pass is a planned future enhancement.

@Suite("ScaleType catalog")
struct ScaleTypeCatalogTests {
    @Test func uniqueIds() {
        let ids = ScaleType.all.map(\.id)
        #expect(ids.count == Set(ids).count)
        #expect(ScaleType.all.count == 18)
    }

    @Test func templateIntegrity() {
        for type in ScaleType.all {
            guard let degrees = type.templateDegrees else { continue }
            #expect(degrees.first == ScaleDegree(letterOffset: 0, semitones: 0),
                    "\(type.id) degree 0 must be the tonic")
            #expect(degrees.map(\.semitones) == degrees.map(\.semitones).sorted(),
                    "\(type.id) semitones must be strictly increasing")
            #expect(degrees.allSatisfy { $0.letterOffset >= 0 && $0.letterOffset <= 6 })
        }
    }

    @Test func spotChecks() {
        func semis(_ typeID: String) -> [Int] {
            let type = ScaleType.all.first { $0.id == typeID }!
            return type.templateDegrees!.map(\.semitones)
        }
        func letters(_ typeID: String) -> [Int] {
            let type = ScaleType.all.first { $0.id == typeID }!
            return type.templateDegrees!.map(\.letterOffset)
        }
        #expect(semis("harmonic-minor") == [0, 2, 3, 5, 7, 8, 11])
        #expect(semis("melodic-minor") == [0, 2, 3, 5, 7, 9, 11])
        #expect(letters("whole-half-diminished") == [0, 1, 2, 3, 4, 5, 5, 6])
        #expect(semis("whole-half-diminished") == [0, 2, 3, 5, 6, 8, 9, 11])
        #expect(semis("half-whole-diminished") == [0, 1, 3, 4, 6, 7, 9, 10])
        #expect(semis("blues") == [0, 3, 5, 6, 7, 10])
        #expect(semis("major-pentatonic") == [0, 2, 4, 7, 9])
        #expect(semis("minor-pentatonic") == [0, 3, 5, 7, 10])
        #expect(semis("whole-tone") == [0, 2, 4, 6, 8, 10])
        #expect(ScaleType.all.first { $0.id == "chromatic" }?.spelling == .chromatic)
    }
}

@Suite("Scale generation")
struct ScaleGenerationTests {
    private func scale(_ typeID: String, _ letter: Letter, _ accidental: Accidental = .natural, octave: Int = 4) -> Scale {
        let type = ScaleType.all.first { $0.id == typeID }!
        return Scale(type: type, tonic: Pitch(letter, accidental, octave: octave))
    }

    @Test func cMajor() {
        let s = scale("major", .c).oneOctaveAscending(from: Pitch(.c, octave: 4))
        #expect(s == [
            Pitch(.c, octave: 4), Pitch(.d, octave: 4), Pitch(.e, octave: 4), Pitch(.f, octave: 4),
            Pitch(.g, octave: 4), Pitch(.a, octave: 4), Pitch(.b, octave: 4), Pitch(.c, octave: 5),
        ])
    }

    @Test func eFlatMajor() {
        let s = scale("major", .e, .flat).oneOctaveAscending(from: Pitch(.e, .flat, octave: 4))
        #expect(s == [
            Pitch(.e, .flat, octave: 4), Pitch(.f, octave: 4), Pitch(.g, octave: 4),
            Pitch(.a, .flat, octave: 4), Pitch(.b, .flat, octave: 4), Pitch(.c, octave: 5),
            Pitch(.d, octave: 5), Pitch(.e, .flat, octave: 5),
        ])
    }

    @Test func dHarmonicMinor() {
        // The raised 7th must be spelled C♯, not D♭.
        let s = scale("harmonic-minor", .d).oneOctaveAscending(from: Pitch(.d, octave: 4))
        #expect(s == [
            Pitch(.d, octave: 4), Pitch(.e, octave: 4), Pitch(.f, octave: 4), Pitch(.g, octave: 4),
            Pitch(.a, octave: 4), Pitch(.b, .flat, octave: 4), Pitch(.c, .sharp, octave: 5),
            Pitch(.d, octave: 5),
        ])
    }

    @Test func bFlatMixolydian() {
        let s = scale("mixolydian", .b, .flat).oneOctaveAscending(from: Pitch(.b, .flat, octave: 4))
        #expect(s == [
            Pitch(.b, .flat, octave: 4), Pitch(.c, octave: 5), Pitch(.d, octave: 5),
            Pitch(.e, .flat, octave: 5), Pitch(.f, octave: 5), Pitch(.g, octave: 5),
            Pitch(.a, .flat, octave: 5), Pitch(.b, .flat, octave: 5),
        ])
    }

    @Test func aFlatMelodicMinor() {
        // The b3 must be spelled C♭, not B♮.
        let s = scale("melodic-minor", .a, .flat).oneOctaveAscending(from: Pitch(.a, .flat, octave: 4))
        #expect(s == [
            Pitch(.a, .flat, octave: 4), Pitch(.b, .flat, octave: 4), Pitch(.c, .flat, octave: 5),
            Pitch(.d, .flat, octave: 5), Pitch(.e, .flat, octave: 5), Pitch(.f, octave: 5),
            Pitch(.g, octave: 5), Pitch(.a, .flat, octave: 5),
        ])
    }

    @Test func cWholeTone() {
        let s = scale("whole-tone", .c).oneOctaveAscending(from: Pitch(.c, octave: 4))
        #expect(s == [
            Pitch(.c, octave: 4), Pitch(.d, octave: 4), Pitch(.e, octave: 4),
            Pitch(.f, .sharp, octave: 4), Pitch(.g, .sharp, octave: 4),
            Pitch(.a, .sharp, octave: 4), Pitch(.c, octave: 5),
        ])
    }

    @Test func cWholeHalfDiminished() {
        let s = scale("whole-half-diminished", .c).oneOctaveAscending(from: Pitch(.c, octave: 4))
        #expect(s == [
            Pitch(.c, octave: 4), Pitch(.d, octave: 4), Pitch(.e, .flat, octave: 4),
            Pitch(.f, octave: 4), Pitch(.g, .flat, octave: 4), Pitch(.a, .flat, octave: 4),
            Pitch(.a, octave: 4), Pitch(.b, octave: 4), Pitch(.c, octave: 5),
        ])
    }

    @Test func cHalfWholeDiminished() {
        let s = scale("half-whole-diminished", .c).oneOctaveAscending(from: Pitch(.c, octave: 4))
        #expect(s == [
            Pitch(.c, octave: 4), Pitch(.d, .flat, octave: 4), Pitch(.e, .flat, octave: 4),
            Pitch(.e, octave: 4), Pitch(.f, .sharp, octave: 4), Pitch(.g, octave: 4),
            Pitch(.a, octave: 4), Pitch(.b, .flat, octave: 4), Pitch(.c, octave: 5),
        ])
    }

    @Test func eMinorPentatonic() {
        let s = scale("minor-pentatonic", .e).oneOctaveAscending(from: Pitch(.e, octave: 4))
        #expect(s == [
            Pitch(.e, octave: 4), Pitch(.g, octave: 4), Pitch(.a, octave: 4),
            Pitch(.b, octave: 4), Pitch(.d, octave: 5), Pitch(.e, octave: 5),
        ])
    }

    @Test func cBlues() {
        // Blues adds the augmented 4th: spelled F♯ on C, not G♭.
        let s = scale("blues", .c).oneOctaveAscending(from: Pitch(.c, octave: 4))
        #expect(s == [
            Pitch(.c, octave: 4), Pitch(.e, .flat, octave: 4), Pitch(.f, octave: 4),
            Pitch(.f, .sharp, octave: 4), Pitch(.g, octave: 4), Pitch(.b, .flat, octave: 4),
            Pitch(.c, octave: 5),
        ])
    }

    @Test func cChromaticAscending() {
        let s = scale("chromatic", .c).oneOctaveAscending(from: Pitch(.c, octave: 4))
        #expect(s == [
            Pitch(.c, octave: 4), Pitch(.c, .sharp, octave: 4), Pitch(.d, octave: 4),
            Pitch(.d, .sharp, octave: 4), Pitch(.e, octave: 4), Pitch(.f, octave: 4),
            Pitch(.f, .sharp, octave: 4), Pitch(.g, octave: 4), Pitch(.g, .sharp, octave: 4),
            Pitch(.a, octave: 4), Pitch(.a, .sharp, octave: 4), Pitch(.b, octave: 4),
            Pitch(.c, octave: 5),
        ])
    }

    @Test func fSharpChromaticAscending() {
        // The letter pattern shifts with the tonic: no G♯ right after F♯.
        let s = scale("chromatic", .f, .sharp).oneOctaveAscending(from: Pitch(.f, .sharp, octave: 4))
        #expect(s == [
            Pitch(.f, .sharp, octave: 4), Pitch(.g, octave: 4), Pitch(.g, .sharp, octave: 4),
            Pitch(.a, octave: 4), Pitch(.a, .sharp, octave: 4), Pitch(.b, octave: 4),
            Pitch(.c, octave: 5), Pitch(.c, .sharp, octave: 5), Pitch(.d, octave: 5),
            Pitch(.d, .sharp, octave: 5), Pitch(.e, octave: 5), Pitch(.f, octave: 5),
            Pitch(.f, .sharp, octave: 5),
        ])
    }

    @Test func eFlatChromaticAscending() {
        let s = scale("chromatic", .e, .flat).oneOctaveAscending(from: Pitch(.e, .flat, octave: 4))
        #expect(s == [
            Pitch(.e, .flat, octave: 4), Pitch(.e, octave: 4), Pitch(.f, octave: 4),
            Pitch(.f, .sharp, octave: 4), Pitch(.g, octave: 4), Pitch(.g, .sharp, octave: 4),
            Pitch(.a, octave: 4), Pitch(.a, .sharp, octave: 4), Pitch(.b, octave: 4),
            Pitch(.c, octave: 5), Pitch(.c, .sharp, octave: 5), Pitch(.d, octave: 5),
            Pitch(.e, .flat, octave: 5),
        ])
    }

    @Test func cChromaticDescending() {
        // Descending chromatic spells the flat side.
        let s = scale("chromatic", .c).oneOctaveDescending(from: Pitch(.c, octave: 5))
        #expect(s == [
            Pitch(.c, octave: 5), Pitch(.b, octave: 4), Pitch(.b, .flat, octave: 4),
            Pitch(.a, octave: 4), Pitch(.a, .flat, octave: 4), Pitch(.g, octave: 4),
            Pitch(.g, .flat, octave: 4), Pitch(.f, octave: 4), Pitch(.e, octave: 4),
            Pitch(.e, .flat, octave: 4), Pitch(.d, octave: 4), Pitch(.d, .flat, octave: 4),
            Pitch(.c, octave: 4),
        ])
    }

    @Test func multiOctaveWalks() {
        let major = scale("major", .c)
        let fifteen = major.degreePitches(ascendingFrom: Pitch(.c, octave: 4), count: 15)
        #expect(fifteen.count == 15)
        #expect(fifteen.last == Pitch(.c, octave: 6))

        let fromG = major.degreePitches(ascendingFrom: Pitch(.g, octave: 4), count: 8)
        #expect(fromG == [
            Pitch(.g, octave: 4), Pitch(.a, octave: 4), Pitch(.b, octave: 4),
            Pitch(.c, octave: 5), Pitch(.d, octave: 5), Pitch(.e, octave: 5),
            Pitch(.f, octave: 5), Pitch(.g, octave: 5),
        ])

        // Octave wrap: B4's next in C major is C5; C4's previous is B3.
        #expect(major.nextUp(after: Pitch(.b, octave: 4)) == Pitch(.c, octave: 5))
        #expect(major.nextDown(before: Pitch(.c, octave: 4)) == Pitch(.b, octave: 3))
        #expect(major.nextUp(after: Pitch(.g, octave: 4)) == Pitch(.a, octave: 4))
    }

    @Test func oneOctaveRoundTrips() {
        let tonics: [Pitch] = [
            Pitch(.c, octave: 4), Pitch(.e, .flat, octave: 4),
            Pitch(.f, .sharp, octave: 4), Pitch(.a, octave: 4),
        ]
        for type in ScaleType.all {
            for tonic in tonics {
                let scale = Scale(type: type, tonic: tonic)
                let up = scale.oneOctaveAscending(from: tonic)
                let down = scale.oneOctaveDescending(from: up.last!)
                // All scales: exact MIDI round trip.
                #expect(down.map(\.midiNumber) == up.map(\.midiNumber).reversed(),
                        "\(scale.name) round trip")
                // Template scales: exact spelling round trip (chromatic
                // descending deliberately spells the flat side).
                if type.templateDegrees != nil {
                    #expect(down == up.reversed(), "\(scale.name) spelled round trip")
                }
            }
        }
    }

    @Test func membership() {
        let aMajor = scale("major", .a)
        #expect(aMajor.isInScale(Pitch(.c, .sharp, octave: 4)))
        #expect(aMajor.isInScale(Pitch(.d, .flat, octave: 4)))  // enharmonic
        #expect(!aMajor.spelledInScale(Pitch(.d, .flat, octave: 4)))
        #expect(aMajor.spelledInScale(Pitch(.c, .sharp, octave: 4)))
        // A♭ is enharmonically G♯ (the M7) — in scale. C♮ is the true non-member.
        #expect(aMajor.isInScale(Pitch(.a, .flat, octave: 4)))
        #expect(!aMajor.isInScale(Pitch(.c, octave: 4)))

        let cHarmonicMinor = scale("harmonic-minor", .c)
        #expect(cHarmonicMinor.isInScale(Pitch(.b, octave: 4)))
        #expect(cHarmonicMinor.spelledInScale(Pitch(.b, octave: 4)))

        let cChromatic = scale("chromatic", .c)
        #expect(cChromatic.isInScale(Pitch(.d, .flat, octave: 4)))
        #expect(cChromatic.spelledInScale(Pitch(.c, .sharp, octave: 4)))
        #expect(cChromatic.spelledInScale(Pitch(.d, .flat, octave: 4)))  // descending spelling
    }

    @Test func enharmonicAnchoring() {
        let aMajor = scale("major", .a)
        let walk = aMajor.degreePitches(ascendingFrom: Pitch(.d, .flat, octave: 4), count: 3)
        #expect(walk == [Pitch(.c, .sharp, octave: 4), Pitch(.d, octave: 4), Pitch(.e, octave: 4)])
    }

    @Test func transposition() {
        let cMajor = scale("major", .c)
        let aMajor = cMajor.transpose(by: .M6)
        #expect(aMajor.name == "A Major")
        #expect(aMajor.oneOctaveAscending(from: Pitch(.a, octave: 4)) == [
            Pitch(.a, octave: 4), Pitch(.b, octave: 4), Pitch(.c, .sharp, octave: 5),
            Pitch(.d, octave: 5), Pitch(.e, octave: 5), Pitch(.f, .sharp, octave: 5),
            Pitch(.g, .sharp, octave: 5), Pitch(.a, octave: 5),
        ])

        let eFlatMajor = scale("major", .e, .flat)
        let gFlatMajor = eFlatMajor.transpose(by: .m3)
        #expect(gFlatMajor.name == "G♭ Major")
        #expect(gFlatMajor.keySignatureRoot.keySignature.sharpsOrFlats == -6)

        let aFlatMelodic = scale("melodic-minor", .a, .flat)
        let bFlatMelodic = aFlatMelodic.transpose(by: .M2)
        #expect(bFlatMelodic.name == "B♭ Melodic Minor")
        #expect(bFlatMelodic.oneOctaveAscending(from: Pitch(.b, .flat, octave: 4)) == [
            Pitch(.b, .flat, octave: 4), Pitch(.c, octave: 5), Pitch(.d, .flat, octave: 5),
            Pitch(.e, .flat, octave: 5), Pitch(.f, octave: 5), Pitch(.g, octave: 5),
            Pitch(.a, octave: 5), Pitch(.b, .flat, octave: 5),
        ])
    }

    @Test func keySignatureRoots() {
        #expect(scale("dorian", .d).keySignatureRoot == .major(.c))
        #expect(scale("mixolydian", .b, .flat).keySignatureRoot == .major(.e, .flat))
        #expect(scale("harmonic-minor", .a).keySignatureRoot == .major(.c))
        #expect(scale("natural-minor", .e).keySignatureRoot == .major(.g))
        #expect(scale("major", .g, .flat).keySignatureRoot == .major(.g, .flat))
        #expect(scale("locrian", .b).keySignatureRoot == .major(.c))
        #expect(scale("locrian", .g, .flat).keySignatureRoot == .major(.a, .flat))
        #expect(scale("lydian", .d, .flat).keySignatureRoot == .major(.a, .flat))
    }

    @Test func namesAndIds() {
        #expect(scale("major", .e, .flat).name == "E♭ Major")
        #expect(scale("dorian", .d).name == "D Dorian")
        #expect(scale("whole-tone", .c).name == "C Whole Tone")
        #expect(scale("major", .e, .flat).id == "eb-major")
        #expect(scale("dorian", .d).id == "d-dorian")
        #expect(scale("major", .c, .sharp).id == "c#-major")
    }
}
