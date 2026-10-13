import Testing
@testable import PitterCore

@Suite("Instrument")
struct InstrumentTests {
    @Test func transpositionRoundTrips() {
        // Every instrument: writtenPitch(fromConcert:).concertPitch(fromWritten:) round-trips to the original spelled pitch
        for instrument in Instrument.allCases {
            let originalPitch = Pitch(.c, octave: 4)
            let written = instrument.writtenPitch(fromConcert: originalPitch)
            let back = instrument.concertPitch(fromWritten: written)
            #expect(back == originalPitch)
        }
    }
    
    @Test func specificTranspositionTests() {
        // B♭ instruments: concert C4 → written D4; concert F♯4 → written G♯4
        let bbInstrument = Instrument.bbClarinet
        #expect(bbInstrument.writtenPitch(fromConcert: Pitch(.c, octave: 4)) == Pitch(.d, octave: 4))
        #expect(bbInstrument.writtenPitch(fromConcert: Pitch(.f, .sharp, octave: 4)) == Pitch(.g, .sharp, octave: 4))
        
        // E♭ instruments: concert C4 → written A4; concert E♭4 → written C5
        let eFlatInstrument = Instrument.altoSax
        #expect(eFlatInstrument.writtenPitch(fromConcert: Pitch(.c, octave: 4)) == Pitch(.a, octave: 4))
        #expect(eFlatInstrument.writtenPitch(fromConcert: Pitch(.e, .flat, octave: 4)) == Pitch(.c, octave: 5))
    }
    
    @Test func identityInstruments() {
        // Flute/concertPitch: identity (C4 → C4, spelled key unchanged)
        let flute = Instrument.flute
        #expect(flute.writtenPitch(fromConcert: Pitch(.c, octave: 4)) == Pitch(.c, octave: 4))
        
        let concertPitch = Instrument.concertPitch
        #expect(concertPitch.writtenPitch(fromConcert: Pitch(.c, octave: 4)) == Pitch(.c, octave: 4))
    }
    
    @Test func writtenKeyTests() {
        // concert C major → D major on B♭ instruments and A major on E♭ instruments
        let bbInstrument = Instrument.bbClarinet
        let eFlatInstrument = Instrument.altoSax
        
        let concertCMajor = Key.major(.c)
        #expect(bbInstrument.writtenKey(fromConcert: concertCMajor) == Key.major(.d))
        #expect(eFlatInstrument.writtenKey(fromConcert: concertCMajor) == Key.major(.a))
        
        // concert E♭ major → F major on B♭
        let concertEMajor = Key.major(.e, .flat)
        #expect(bbInstrument.writtenKey(fromConcert: concertEMajor) == Key.major(.f))
        
        // concert B♭ major → G major on E♭
        let concertBMajor = Key.major(.b, .flat)
        #expect(eFlatInstrument.writtenKey(fromConcert: concertBMajor) == Key.major(.g))
        
        // concert F♯ minor → G♯ minor on B♭ (valid — 5 sharps)
        let concertFSharpMinor = Key.minor(.f, .sharp)
        #expect(bbInstrument.writtenKey(fromConcert: concertFSharpMinor) == Key.minor(.g, .sharp))
        
        // respelling fallback: concert C♯ major on an E♭ instrument → transposed tonic G♯ major (invalid) → respelled A♭ major
        let concertCSharpMajor = Key.major(.c, .sharp)
        let writtenKey = eFlatInstrument.writtenKey(fromConcert: concertCSharpMajor)
        // The transposed tonic would be G♯, which is invalid for E♭ instrument, so it should fall back to A♭
        #expect(writtenKey == Key.major(.a, .flat))
    }
    
    @Test func suggestedRangeSanity() {
        // All instruments should have suggestedLow < suggestedHigh and both within MIDI 0…127
        for instrument in Instrument.allCases {
            #expect(instrument.suggestedLow < instrument.suggestedHigh)
            #expect(instrument.suggestedLow.midiNumber >= 0)
            #expect(instrument.suggestedHigh.midiNumber <= 127)
        }
    }
    
    @Test func suggestedRangePerInstrument() {
        // Specific range checks for each instrument
        #expect(Instrument.concertPitch.suggestedLow == Pitch(.c, octave: 2))
        #expect(Instrument.concertPitch.suggestedHigh == Pitch(.c, octave: 6))
        
        #expect(Instrument.flute.suggestedLow == Pitch(.c, octave: 4))
        #expect(Instrument.flute.suggestedHigh == Pitch(.c, octave: 7))
        
        #expect(Instrument.bbClarinet.suggestedLow == Pitch(.d, octave: 3))
        #expect(Instrument.bbClarinet.suggestedHigh == Pitch(.b, .flat, octave: 6))
        
        #expect(Instrument.sopranoSax.suggestedLow == Pitch(.a, .flat, octave: 3))
        #expect(Instrument.sopranoSax.suggestedHigh == Pitch(.e, .flat, octave: 6))
        
        #expect(Instrument.altoSax.suggestedLow == Pitch(.d, .flat, octave: 3))
        #expect(Instrument.altoSax.suggestedHigh == Pitch(.a, .flat, octave: 5))   // concert pitch (written F♯6)
        
        #expect(Instrument.tenorSax.suggestedLow == Pitch(.a, .flat, octave: 2))
        #expect(Instrument.tenorSax.suggestedHigh == Pitch(.e, octave: 5))
        
        #expect(Instrument.bariSax.suggestedLow == Pitch(.d, .flat, octave: 2))
        #expect(Instrument.bariSax.suggestedHigh == Pitch(.a, .flat, octave: 4))
    }
    
    @Test func catalogTests() {
        // No duplicate rawValues (guaranteed by enum)
        let rawValues = Instrument.allCases.map(\.rawValue)
        #expect(rawValues.count == Set(rawValues).count)
        
        // all.count == 7
        #expect(Instrument.allCases.count == 7)
        
        // Every instrument has .treble defaultClef in this set
        for instrument in Instrument.allCases {
            #expect(instrument.defaultClef == .treble)
        }
    }
}