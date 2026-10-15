import Foundation
import CoreText

/// The Bravura SMuFL font: glyph codepoints (verified against the
/// w3c/smufl `glyphnames.json`) and loading of the bundled font file.
///
/// Bravura is licensed under the SIL Open Font License (see
/// `Resources/OFL.txt`); the em size is 4 staff spaces, and glyphs anchor
/// on the baseline at their staff position (SMuFL convention).
public enum Bravura {
    public static let fontName = "Bravura"

    /// SMuFL glyphs the renderer needs, keyed by their codepoints.
    public enum Glyph: Character, CaseIterable {
        // Clefs
        case gClef = "\u{E050}"
        case fClef = "\u{E062}"

        // Noteheads
        case noteheadWhole = "\u{E0A2}"
        case noteheadHalf = "\u{E0A3}"
        case noteheadBlack = "\u{E0A4}"

        // Accidentals
        case accidentalFlat = "\u{E260}"
        case accidentalNatural = "\u{E261}"
        case accidentalSharp = "\u{E262}"
        case accidentalDoubleSharp = "\u{E263}"
        case accidentalDoubleFlat = "\u{E264}"

        // Duration decorations
        case augmentationDot = "\u{E1E7}"
        case flag8thUp = "\u{E240}"
        case flag8thDown = "\u{E241}"
        case flag16thUp = "\u{E242}"
        case flag16thDown = "\u{E243}"
        case flag32ndUp = "\u{E244}"
        case flag32ndDown = "\u{E245}"

        // Rests
        case restWhole = "\u{E4E3}"
        case restHalf = "\u{E4E4}"
        case restQuarter = "\u{E4E5}"
        case rest8th = "\u{E4E6}"
        case rest16th = "\u{E4E7}"
        case rest32nd = "\u{E4E8}"

        // Time signature digits (0–9)
        case timeSig0 = "\u{E080}"
        case timeSig1 = "\u{E081}"
        case timeSig2 = "\u{E082}"
        case timeSig3 = "\u{E083}"
        case timeSig4 = "\u{E084}"
        case timeSig5 = "\u{E085}"
        case timeSig6 = "\u{E086}"
        case timeSig7 = "\u{E087}"
        case timeSig8 = "\u{E088}"
        case timeSig9 = "\u{E089}"

        /// The time-signature digit for 0–9.
        public static func digit(_ n: Int) -> Glyph {
            precondition((0...9).contains(n), "Not a digit: \(n)")
            return allCases.first { $0.rawValue.unicodeScalars.first!.value == 0xE080 + n }!
        }

        /// The accidental glyph for an accidental value.
        public static func accidental(_ accidental: Accidental) -> Glyph {
            switch accidental {
            case .doubleFlat: return .accidentalDoubleFlat
            case .flat: return .accidentalFlat
            case .natural: return .accidentalNatural
            case .sharp: return .accidentalSharp
            case .doubleSharp: return .accidentalDoubleSharp
            }
        }

        /// The rest glyph for a duration base.
        public static func rest(for base: NoteDuration.Base) -> Glyph {
            switch base {
            case .whole: return .restWhole
            case .half: return .restHalf
            case .quarter: return .restQuarter
            case .eighth: return .rest8th
            case .sixteenth: return .rest16th
            case .thirtySecond: return .rest32nd
            }
        }
    }

    /// Registers the bundled Bravura font for this process (idempotent;
    /// runs once, thread-safe via `static let` initialization).
    @discardableResult
    public static func register() -> Bool {
        registerOnce
    }

    private static let registerOnce: Bool = {
        guard let url = bundledFontURL else { return false }
        return CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }()

    private static var bundledFontURL: URL? {
        // SPM may place the resource at the bundle root or under
        // `Resources/` depending on the toolchain; accept either.
        if let url = Bundle.module.url(forResource: fontName, withExtension: "otf") {
            return url
        }
        return Bundle.module.url(forResource: fontName, withExtension: "otf", subdirectory: "Resources")
    }

    /// The Bravura font at the given point size (em = 4 staff spaces,
    /// so a staff with `sp` points per space uses size `4 × sp`).
    /// - Precondition: the bundled font must be registrable (test-enforced).
    public static func font(size: CGFloat) -> CTFont {
        precondition(register(), "Bravura: bundled font failed to register")
        let font = CTFontCreateWithName(fontName as CFString, size, nil)
        return font
    }
}
