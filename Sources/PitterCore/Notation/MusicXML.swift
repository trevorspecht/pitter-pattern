import Foundation

/// MusicXML score-partwise writer for PitterPattern.
public enum MusicXML {
    /// Full document string for one part.
    /// - Parameters:
    ///   - sequence: concert-pitch sequence (canonical, D2).
    ///   - partName: `<part-name>` text (e.g. instrument display name).
    ///   - instrument: when transposing, the sequence is emitted in written
    ///     pitch (via `NotatedSequence.transposed(for:)`) and a
    ///     `<transpose>` element describes written → sounding.
    public static func scorePartwise(
        _ sequence: NotatedSequence,
        partName: String,
        instrument: Instrument = .concertPitch
    ) -> String {
        let sequence = instrument.isTransposing ? sequence.transposed(for: instrument) : sequence
        let context = sequence.context
        
        // Escape XML special characters in part name
        let escapedPartName = partName
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
        
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<!DOCTYPE score-partwise PUBLIC \"-//Recordare//DTD MusicXML 4.0 Partwise//EN\" \"http://www.musicxml.org/dtds/partwise.dtd\">\n"
        xml += "<score-partwise version=\"4.0\">\n"
        xml += "  <part-list>\n"
        xml += "    <score-part id=\"P1\">\n"
        xml += "      <part-name>\(escapedPartName)</part-name>\n"
        xml += "    </score-part>\n"
        xml += "  </part-list>\n"
        xml += "  <part id=\"P1\">\n"
        
        for (index, measure) in sequence.measures.enumerated() {
            let measureNumber = index + 1
            xml += "    <measure number=\"\(measureNumber)\">\n"
            
            // Add attributes only to the first measure
            if index == 0 {
                xml += "      <attributes>\n"
                xml += "        <divisions>32</divisions>\n"
                xml += "        <key>\n"
                xml += "          <fifths>\(context.key.keySignature.sharpsOrFlats)</fifths>\n"
                xml += "        </key>\n"
                xml += "        <time>\n"
                xml += "          <beats>\(context.timeSignature.numerator)</beats>\n"
                xml += "          <beat-type>\(context.timeSignature.denominator)</beat-type>\n"
                xml += "        </time>\n"
                xml += "        <clef>\n"
                xml += "          <sign>\(context.clef.sign)</sign>\n"
                xml += "          <line>\(context.clef.line)</line>\n"
                xml += "        </clef>\n"
                
                // Add transpose element for transposing instruments
                if instrument.isTransposing {
                    let transpose = instrument.writtenTransposition
                    xml += "        <transpose>\n"
                    xml += "          <diatonic>\(-transpose.letterSteps)</diatonic>\n"
                    xml += "          <chromatic>\(-transpose.semitones)</chromatic>\n"
                    xml += "        </transpose>\n"
                }
                
                xml += "      </attributes>\n"
            }
            
            // Add notes/rests in the measure
            for (noteIndex, note) in measure.enumerated() {
                // Does this note continue a tie from its predecessor (the
                // previous note in this measure, or the last note of the
                // previous measure)? Rests never tie.
                let tiedFromPrevious: Bool
                if noteIndex > 0 {
                    tiedFromPrevious = measure[noteIndex - 1].tiedToNext
                } else if index > 0 {
                    tiedFromPrevious = sequence.measures[index - 1].last?.tiedToNext ?? false
                } else {
                    tiedFromPrevious = false
                }

                xml += "      <note>\n"

                switch note.sound {
                case .note(let pitch):
                    xml += "        <pitch>\n"
                    xml += "          <step>\(pitch.letter.description)</step>\n"
                    // Alter comes from the pitch's own spelling (NOT the
                    // display accidental — an in-key F♯ shows no glyph but
                    // still needs alter=1).
                    if pitch.accidental != .natural {
                        xml += "          <alter>\(pitch.accidental.semitoneOffset)</alter>\n"
                    }
                    xml += "          <octave>\(pitch.octave)</octave>\n"
                    xml += "        </pitch>\n"
                case .rest:
                    xml += "        <rest/>\n"
                }

                xml += "        <duration>\(note.duration.units)</duration>\n"
                if tiedFromPrevious { xml += "        <tie type=\"stop\"/>\n" }
                if note.tiedToNext { xml += "        <tie type=\"start\"/>\n" }
                xml += "        <voice>1</voice>\n"
                xml += "        <type>\(note.duration.base.name)</type>\n"
                for _ in 0..<note.duration.dots {
                    xml += "        <dot/>\n"
                }
                // The *display* accidental (resolved by NotatedSequence).
                if let accidental = note.accidental {
                    xml += "        <accidental>\(accidental.musicXMLName)</accidental>\n"
                }
                if tiedFromPrevious || note.tiedToNext {
                    xml += "        <notations>\n"
                    if tiedFromPrevious { xml += "          <tied type=\"stop\"/>\n" }
                    if note.tiedToNext { xml += "          <tied type=\"start\"/>\n" }
                    xml += "        </notations>\n"
                }

                xml += "      </note>\n"
            }
            
            xml += "    </measure>\n"
        }
        
        xml += "  </part>\n"
        xml += "</score-partwise>\n"
        
        return xml
    }
}

extension Clef {
    /// Returns the sign for the clef
    var sign: String {
        switch self {
        case .treble: return "G"
        case .bass: return "F"
        }
    }
    
    /// Returns the line for the clef
    var line: Int {
        switch self {
        case .treble: return 2
        case .bass: return 4
        }
    }
}

extension Accidental {
    /// Returns the MusicXML name for the accidental
    var musicXMLName: String {
        switch self {
        case .sharp: return "sharp"
        case .flat: return "flat"
        case .natural: return "natural"
        case .doubleSharp: return "sharp-sharp"
        case .doubleFlat: return "flat-flat"
        }
    }
}