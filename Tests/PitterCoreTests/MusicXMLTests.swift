import Foundation
import Testing
@testable import PitterCore

// Spec 008 test plan: a byte-exact golden document, tie/accidental/
// transpose shapes via exact note-block contains checks, and Foundation
// XMLParser well-formedness + structural assertions over an
// instrument × key/meter matrix.

@Suite("MusicXML")
struct MusicXMLTests {
    // MARK: - XML parsing helper

    private final class XMLProbe: NSObject, XMLParserDelegate {
        struct Node {
            let name: String
            let attributes: [String: String]
            var text: String = ""
        }

        private(set) var nodes: [Node] = []
        private(set) var parseError: String?
        private var currentIndex: Int?

        static func parse(_ xml: String) -> XMLProbe {
            let probe = XMLProbe()
            let parser = XMLParser(data: Data(xml.utf8))
            parser.delegate = probe
            parser.parse()
            probe.parseError = parser.parserError.map { "\($0)" }
            return probe
        }

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            nodes.append(Node(name: elementName, attributes: attributeDict))
            currentIndex = nodes.count - 1
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if let index = currentIndex { nodes[index].text += string }
        }

        func count(_ name: String) -> Int { nodes.filter { $0.name == name }.count }
        // Text is trimmed: XMLParser also delivers inter-element
        // whitespace through foundCharacters.
        func texts(_ name: String) -> [String] {
            nodes.filter { $0.name == name }.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        func text(_ name: String) -> String? {
            first(name)?.text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        func first(_ name: String) -> Node? { nodes.first { $0.name == name } }
    }

    // MARK: - Fixtures

    private func p(_ letter: Letter, _ accidental: Accidental = .natural, octave: Int) -> Pitch {
        Pitch(letter, accidental, octave: octave)
    }

    private var cMajor44: NotationContext {
        NotationContext(key: .major(.c), timeSignature: .common, clef: .treble)
    }

    private func oneOctaveRun() -> [Pitch] {
        [
            p(.c, octave: 4), p(.d, octave: 4), p(.e, octave: 4), p(.f, octave: 4),
            p(.g, octave: 4), p(.a, octave: 4), p(.b, octave: 4), p(.c, octave: 5),
        ]
    }

    private func noteBlock(
        _ step: String,
        _ octave: Int,
        duration: Int = 32,
        type: String = "quarter"
    ) -> String {
        [
            "      <note>",
            "        <pitch>",
            "          <step>\(step)</step>",
            "          <octave>\(octave)</octave>",
            "        </pitch>",
            "        <duration>\(duration)</duration>",
            "        <voice>1</voice>",
            "        <type>\(type)</type>",
            "      </note>",
        ].joined(separator: "\n")
    }

    // MARK: - Golden document

    @Test func goldenOneOctaveConcert() {
        let doc = MusicXML.scorePartwise(
            NotatedSequence(pitches: oneOctaveRun(), context: cMajor44),
            partName: "Concert Pitch (C)"
        )
        let expected = [
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
            "<!DOCTYPE score-partwise PUBLIC \"-//Recordare//DTD MusicXML 4.0 Partwise//EN\" \"http://www.musicxml.org/dtds/partwise.dtd\">",
            "<score-partwise version=\"4.0\">",
            "  <part-list>",
            "    <score-part id=\"P1\">",
            "      <part-name>Concert Pitch (C)</part-name>",
            "    </score-part>",
            "  </part-list>",
            "  <part id=\"P1\">",
            "    <measure number=\"1\">",
            "      <attributes>",
            "        <divisions>32</divisions>",
            "        <key>",
            "          <fifths>0</fifths>",
            "        </key>",
            "        <time>",
            "          <beats>4</beats>",
            "          <beat-type>4</beat-type>",
            "        </time>",
            "        <clef>",
            "          <sign>G</sign>",
            "          <line>2</line>",
            "        </clef>",
            "      </attributes>",
            noteBlock("C", 4),
            noteBlock("D", 4),
            noteBlock("E", 4),
            noteBlock("F", 4),
            "    </measure>",
            "    <measure number=\"2\">",
            noteBlock("G", 4),
            noteBlock("A", 4),
            noteBlock("B", 4),
            noteBlock("C", 5),
            "    </measure>",
            "  </part>",
            "</score-partwise>",
        ].joined(separator: "\n") + "\n"
        #expect(doc == expected)
    }

    // MARK: - Tie shape

    @Test func barlineTieShape() {
        let seq = NotatedSequence(
            pitches: [p(.c, octave: 4), p(.c, octave: 4)],
            durations: [.half, .whole],
            context: cMajor44
        )
        let doc = MusicXML.scorePartwise(seq, partName: "Piano")

        // Measure 1, note 2: tie start, no stop.
        let startBlock = [
            "      <note>",
            "        <pitch>",
            "          <step>C</step>",
            "          <octave>4</octave>",
            "        </pitch>",
            "        <duration>64</duration>",
            "        <tie type=\"start\"/>",
            "        <voice>1</voice>",
            "        <type>half</type>",
            "        <notations>",
            "          <tied type=\"start\"/>",
            "        </notations>",
            "      </note>",
        ].joined(separator: "\n")
        #expect(doc.contains(startBlock))

        // Measure 2, note 1: tie stop, no start.
        let stopBlock = [
            "      <note>",
            "        <pitch>",
            "          <step>C</step>",
            "          <octave>4</octave>",
            "        </pitch>",
            "        <duration>64</duration>",
            "        <tie type=\"stop\"/>",
            "        <voice>1</voice>",
            "        <type>half</type>",
            "        <notations>",
            "          <tied type=\"stop\"/>",
            "        </notations>",
            "      </note>",
        ].joined(separator: "\n")
        #expect(doc.contains(stopBlock))

        // Measure 2, note 2: the fill rest.
        let restBlock = [
            "      <note>",
            "        <rest/>",
            "        <duration>64</duration>",
            "        <voice>1</voice>",
            "        <type>half</type>",
            "      </note>",
        ].joined(separator: "\n")
        #expect(doc.contains(restBlock))

        let probe = XMLProbe.parse(doc)
        #expect(probe.parseError == nil)
        #expect(probe.count("note") == 4)
        #expect(probe.count("tie") == 2) // one start, one stop
        #expect(probe.count("rest") == 1)
    }

    // MARK: - Accidentals

    @Test func accidentalShapeInFlatKey() {
        let run: [Pitch] = [
            p(.e, .flat, octave: 4), p(.e, .natural, octave: 4),
            p(.e, .flat, octave: 4), p(.e, .flat, octave: 4),
            p(.e, .flat, octave: 4), p(.e, .flat, octave: 5),
            p(.a, .natural, octave: 4), p(.e, .flat, octave: 4),
        ]
        let seq = NotatedSequence(
            pitches: run,
            context: NotationContext(key: .major(.e, .flat), timeSignature: .common, clef: .treble)
        )
        let doc = MusicXML.scorePartwise(seq, partName: "Piano")
        let probe = XMLProbe.parse(doc)
        #expect(probe.parseError == nil)
        #expect(probe.text("fifths") == "-3")

        // In-key E♭: alter, but no display accidental.
        let inKey = [
            "      <note>",
            "        <pitch>",
            "          <step>E</step>",
            "          <alter>-1</alter>",
            "          <octave>4</octave>",
            "        </pitch>",
            "        <duration>32</duration>",
            "        <voice>1</voice>",
            "        <type>quarter</type>",
            "      </note>",
        ].joined(separator: "\n")
        #expect(doc.contains(inKey))

        // Deviating E♮: no alter (natural), natural glyph shown.
        let natural = [
            "      <note>",
            "        <pitch>",
            "          <step>E</step>",
            "          <octave>4</octave>",
            "        </pitch>",
            "        <duration>32</duration>",
            "        <voice>1</voice>",
            "        <type>quarter</type>",
            "        <accidental>natural</accidental>",
            "      </note>",
        ].joined(separator: "\n")
        #expect(doc.contains(natural))

        // Re-established E♭: alter AND flat glyph.
        let flat = [
            "      <note>",
            "        <pitch>",
            "          <step>E</step>",
            "          <alter>-1</alter>",
            "          <octave>4</octave>",
            "        </pitch>",
            "        <duration>32</duration>",
            "        <voice>1</voice>",
            "        <type>quarter</type>",
            "        <accidental>flat</accidental>",
            "      </note>",
        ].joined(separator: "\n")
        #expect(doc.contains(flat))

        #expect(probe.texts("accidental") == ["natural", "flat", "natural"])
    }

    // MARK: - Transposing instrument

    @Test func clarinetWrittenPitchAndTranspose() {
        let seq = NotatedSequence(
            pitches: [p(.c, octave: 4), p(.e, octave: 4), p(.g, octave: 4)],
            context: cMajor44
        )
        let doc = MusicXML.scorePartwise(seq, partName: "B♭ Clarinet", instrument: .bbClarinet)
        let probe = XMLProbe.parse(doc)
        #expect(probe.parseError == nil)
        #expect(probe.text("fifths") == "2")
        #expect(probe.texts("diatonic") == ["-1"])
        #expect(probe.texts("chromatic") == ["-2"])

        // Pitches are written: D4, F♯4 (alter 1, no glyph — in key), A4;
        // the fill rest contributes no step.
        #expect(probe.texts("step") == ["D", "F", "A"])
        #expect(probe.texts("octave") == ["4", "4", "4"])
        #expect(probe.texts("alter") == ["1"])

        let fSharp = [
            "      <note>",
            "        <pitch>",
            "          <step>F</step>",
            "          <alter>1</alter>",
            "          <octave>4</octave>",
            "        </pitch>",
            "        <duration>32</duration>",
            "        <voice>1</voice>",
            "        <type>quarter</type>",
            "      </note>",
        ].joined(separator: "\n")
        #expect(doc.contains(fSharp))
        #expect(probe.count("accidental") == 0)
        #expect(probe.count("rest") == 1) // quarter rest fills the measure
    }

    // MARK: - Dots and structure

    @Test func dottedDurationStructure() {
        let seq = NotatedSequence(
            pitches: [p(.c, octave: 4), p(.d, octave: 4)],
            durations: [.quarter, NoteDuration(base: .half, dots: 1)],
            context: cMajor44
        )
        let doc = MusicXML.scorePartwise(seq, partName: "Piano")
        let probe = XMLProbe.parse(doc)
        #expect(probe.parseError == nil)
        #expect(probe.count("measure") == 1)
        #expect(probe.count("note") == 2)
        #expect(probe.count("dot") == 1)
        #expect(probe.texts("duration") == ["32", "96"])
        #expect(probe.texts("type") == ["quarter", "half"])
        #expect(probe.text("divisions") == "32")
    }

    // MARK: - Well-formedness matrix

    @Test func matrixWellFormedAcrossInstruments() {
        let quarters = NotatedSequence(
            pitches: [p(.c, octave: 4), p(.d, octave: 4), p(.e, octave: 4), p(.f, octave: 4)],
            context: cMajor44
        )
        let ebMajor68 = NotationContext(
            key: .major(.e, .flat),
            timeSignature: TimeSignature(numerator: 6, denominator: 8),
            clef: .treble
        )
        let eighths = NotatedSequence(
            pitches: [
                p(.e, .flat, octave: 4), p(.f, octave: 4), p(.g, octave: 4),
                p(.a, .flat, octave: 4), p(.b, .flat, octave: 4), p(.c, octave: 5),
            ],
            uniformDuration: .eighth,
            context: ebMajor68
        )

        for instrument in Instrument.allCases {
            for (seq, noteCount) in [(quarters, 4), (eighths, 6)] {
                let doc = MusicXML.scorePartwise(
                    seq, partName: instrument.displayName, instrument: instrument
                )
                let probe = XMLProbe.parse(doc)
                #expect(probe.parseError == nil)
                #expect(probe.count("measure") == 1)
                #expect(probe.count("note") == noteCount)
                #expect(probe.text("divisions") == "32")
            }
        }
    }

    // MARK: - Escaping

    @Test func partNameEscaped() {
        let seq = NotatedSequence(pitches: [p(.c, octave: 4)], context: cMajor44)
        let doc = MusicXML.scorePartwise(seq, partName: "Flute & \"Friends\" <Section>")
        #expect(doc.contains("<part-name>Flute &amp; &quot;Friends&quot; &lt;Section&gt;</part-name>"))
        #expect(XMLProbe.parse(doc).parseError == nil)
    }
}
