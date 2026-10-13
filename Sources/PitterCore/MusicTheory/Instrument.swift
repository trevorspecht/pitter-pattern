public enum Instrument: String, CaseIterable, Codable, Sendable, Identifiable, Hashable {
    case concertPitch   // generic non-transposing (piano, voice, C instruments)
    case flute
    case bbClarinet
    case sopranoSax
    case altoSax
    case tenorSax
    case bariSax
    public var id: String { rawValue }
}

extension Instrument {
    public var displayName: String {
        switch self {
        case .concertPitch: return "Concert Pitch (C)"
        case .flute: return "Flute"
        case .bbClarinet: return "B♭ Clarinet"
        case .sopranoSax: return "Soprano Sax"
        case .altoSax: return "Alto Sax"
        case .tenorSax: return "Tenor Sax"
        case .bariSax: return "Baritone Sax"
        }
    }
    
    public var isTransposing: Bool {
        switch self {
        case .concertPitch: return false
        case .flute: return false
        case .bbClarinet: return true
        case .sopranoSax: return true
        case .altoSax: return true
        case .tenorSax: return true
        case .bariSax: return true
        }
    }
    
    public var writtenTransposition: Interval {
        switch self {
        case .concertPitch, .flute: return .unison
        case .bbClarinet, .sopranoSax, .tenorSax: return .M2
        case .altoSax, .bariSax: return .M6
        }
    }
    
    public var defaultClef: Clef {
        .treble
    }
    
    public var suggestedLow: Pitch {
        switch self {
        case .concertPitch: return Pitch(.c, octave: 2)
        case .flute: return Pitch(.c, octave: 4)
        case .bbClarinet: return Pitch(.d, octave: 3)
        case .sopranoSax: return Pitch(.a, .flat, octave: 3)
        case .altoSax: return Pitch(.d, .flat, octave: 3)
        case .tenorSax: return Pitch(.a, .flat, octave: 2)
        case .bariSax: return Pitch(.d, .flat, octave: 2)
        }
    }
    
    public var suggestedHigh: Pitch {
        switch self {
        case .concertPitch: return Pitch(.c, octave: 6)
        case .flute: return Pitch(.c, octave: 7)
        case .bbClarinet: return Pitch(.b, .flat, octave: 6)
        case .sopranoSax: return Pitch(.e, .flat, octave: 6)
        case .altoSax: return Pitch(.a, .flat, octave: 5)   // concert pitch (written F♯6)
        case .tenorSax: return Pitch(.e, octave: 5)
        case .bariSax: return Pitch(.a, .flat, octave: 4)
        }
    }
    
    public func writtenPitch(fromConcert pitch: Pitch) -> Pitch {
        pitch.transposed(by: writtenTransposition)
    }
    
    public func concertPitch(fromWritten pitch: Pitch) -> Pitch {
        pitch.transposed(by: writtenTransposition.inverted)
    }
    
    public func writtenKey(fromConcert key: Key) -> Key {
        // First try the transposed tonic in the same spelling
        let transposedTonic = Pitch(key.tonicLetter, key.tonicAccidental, octave: 4)
            .transposed(by: writtenTransposition)
        
        // Try to build the key with the transposed tonic
        if Key.isValid(tonicLetter: transposedTonic.letter, tonicAccidental: transposedTonic.accidental, mode: key.mode) {
            return Key(tonicLetter: transposedTonic.letter, tonicAccidental: transposedTonic.accidental, mode: key.mode)
        }
        
        // If that failed, try the enharmonic respelling (sharp ↔ flat)
        let alternativeAccidental: Accidental
        switch key.tonicAccidental {
        case .sharp: alternativeAccidental = .flat
        case .flat: alternativeAccidental = .sharp
        case .natural: alternativeAccidental = .natural
        case .doubleFlat: alternativeAccidental = .doubleSharp
        case .doubleSharp: alternativeAccidental = .doubleFlat
        }
        
        let altTonic = Pitch(key.tonicLetter, alternativeAccidental, octave: 4)
            .transposed(by: writtenTransposition)
        
        if Key.isValid(tonicLetter: altTonic.letter, tonicAccidental: altTonic.accidental, mode: key.mode) {
            return Key(tonicLetter: altTonic.letter, tonicAccidental: altTonic.accidental, mode: key.mode)
        }
        
        // If both fail, return the original key unchanged
        return key
    }
}
