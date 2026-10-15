import CoreText
import Foundation
import Testing
@testable import PitterCore

@Suite("Bravura")
struct BravuraTests {
    @Test func fontRegistersAndLoads() {
        #expect(Bravura.register())
        let font = Bravura.font(size: 36)
        #expect(CTFontCopyPostScriptName(font) as String? == "Bravura")
    }

    @Test func everyGlyphIsInTheFont() {
        let font = Bravura.font(size: 36)
        for glyph in Bravura.Glyph.allCases {
            var characters = [UniChar](String(glyph.rawValue).utf16)
            var glyphs = [CGGlyph](repeating: 0, count: characters.count)
            let mapped = CTFontGetGlyphsForCharacters(font, &characters, &glyphs, characters.count)
            #expect(mapped)
            #expect(glyphs[0] != 0, "no glyph for \(glyph)")
        }
    }

    @Test func digitAndAccidentalMappings() {
        #expect(Bravura.Glyph.digit(0) == .timeSig0)
        #expect(Bravura.Glyph.digit(9) == .timeSig9)
        #expect(Bravura.Glyph.accidental(.sharp) == .accidentalSharp)
        #expect(Bravura.Glyph.accidental(.doubleFlat) == .accidentalDoubleFlat)
        #expect(Bravura.Glyph.rest(for: .thirtySecond) == .rest32nd)
        #expect(Bravura.Glyph.rest(for: .whole) == .restWhole)
    }
}
