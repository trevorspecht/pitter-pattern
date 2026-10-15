import SwiftUI
import CoreText

#if os(macOS)
import AppKit
private let inkCGColor = NSColor.black.cgColor
#elseif os(iOS)
import UIKit
private let inkCGColor = UIColor.black.cgColor
#endif

/// Renders a `NotatedSequence` as a portrait **page** of wrapped staff
/// systems (D1: own renderer, Bravura font). The page defaults to a light
/// paper look — white background, black ink — which is what musicians
/// read; the app-level light/dark/system preference (T3.2) affects the
/// surrounding chrome, not the page.
///
/// Zoom is just `scale`: larger glyphs → fewer measures per system (the
/// wrapping adapts), so the page never needs horizontal scrolling.
public struct StaffPageView: View {
    private let sequence: NotatedSequence
    /// Points per staff space (Bravura em = 4 spaces).
    private let scale: CGFloat
    /// Page width in points (the caller's viewport).
    private let pageWidth: CGFloat

    // Page metrics (staff spaces).
    private let sideMargin: Double = 2.5
    private let topMargin: Double = 2.5
    private let bottomMargin: Double = 2.5
    /// Ink margin above / below each staff.
    private let staffTop = 3.5
    private let staffBottom = 2.5
    /// Gap between systems.
    private let systemGap = 3.5

    public init(_ sequence: NotatedSequence, scale: CGFloat = 9, pageWidth: CGFloat) {
        self.sequence = sequence
        self.scale = scale
        self.pageWidth = pageWidth
    }

    public var body: some View {
        let layout = StaffLayout(sequence)
        let contentWidth = max(8, Double(pageWidth / scale) - 2 * sideMargin)
        let lines = layout.lines(contentWidth: contentWidth)
        let lineHeight = staffTop + 4 + staffBottom
        let contentHeight = topMargin + CGFloat(lines.count) * CGFloat(lineHeight + systemGap) - systemGap + bottomMargin
        // Default portrait proportions (8.5 × 11): the page is never
        // shorter than the aspect suggests.
        let height = max(contentHeight, pageWidth * 11 / 8.5)

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
            Canvas { context, _ in
                StaffRenderer.draw(
                    lines,
                    scale: scale,
                    sideMargin: sideMargin,
                    topMargin: topMargin,
                    staffTop: staffTop,
                    lineHeight: lineHeight + systemGap,
                    in: &context
                )
            }
            .frame(width: pageWidth, height: height)
        }
        .frame(width: pageWidth, height: height)
    }
}

/// The Canvas drawing pass. Glyphs go through CoreText (SMuFL anchors on
/// the baseline, so positioning must be baseline-exact); staff lines,
/// stems, ledger lines, barlines, and ties are stroked paths.
private enum StaffRenderer {
    static func draw(
        _ lines: [StaffLayout.Line],
        scale: CGFloat,
        sideMargin: Double,
        topMargin: Double,
        staffTop: Double,
        lineHeight: Double,
        in context: inout GraphicsContext
    ) {
        let ink = GraphicsContext.Shading.color(Color.black)

        func x(_ spaces: Double) -> CGFloat {
            CGFloat(sideMargin + spaces) * scale
        }

        for (lineIndex, line) in lines.enumerated() {
            // Line origin: y of the staff's bottom line, in spaces from
            // the page top. y(spaces) maps above-bottom coordinates.
            let lineBottom = topMargin + staffTop + 4
                + Double(lineIndex) * lineHeight
            func y(_ spaces: Double) -> CGFloat {
                CGFloat(lineBottom - spaces) * scale
            }

            // Staff lines.
            for lineY in 0...4 {
                var path = Path()
                path.move(to: CGPoint(x: x(-sideMargin + 0.5), y: y(Double(lineY))))
                path.addLine(to: CGPoint(x: x(line.width), y: y(Double(lineY))))
                context.stroke(path, with: ink, lineWidth: scale * 0.09)
            }

            // Header glyphs (clef, key signature, time signature).
            let font = Bravura.font(size: 4 * scale)
            for glyph in line.header {
                drawGlyph(glyph.glyph, atX: x(glyph.x), baseline: y(glyph.y), font: font, in: &context)
            }

            // Barlines: thin between measures; the final barline
            // (thin + thick) closes the last measure of the last line.
            for (barlineIndex, barline) in line.barlines.enumerated() {
                let isFinal = line.isLast && barlineIndex == line.barlines.count - 1
                var thin = Path()
                thin.move(to: CGPoint(x: x(barline), y: y(0)))
                thin.addLine(to: CGPoint(x: x(barline), y: y(4)))
                context.stroke(thin, with: ink, lineWidth: scale * 0.12)
                if isFinal {
                    var thick = Path()
                    let thickX = x(barline) + scale * 0.55
                    thick.move(to: CGPoint(x: thickX, y: y(0)))
                    thick.addLine(to: CGPoint(x: thickX, y: y(4)))
                    context.stroke(thick, with: ink, lineWidth: scale * 0.45)
                }
            }

            // Measures and notes.
            for placed in line.measures {
                for note in placed.measure.notes {
                    drawNote(
                        note, atX: x(placed.origin + note.x), y: y,
                        font: font, ink: ink, scale: scale, context: &context
                    )
                }
            }

            // Ties.
            for tie in line.ties {
                var path = Path()
                let start = CGPoint(x: x(tie.fromX), y: y(tie.y))
                let end = CGPoint(x: x(tie.toX), y: y(tie.y))
                let controlY = tie.y + (tie.bulgesUp ? 1.2 : -1.2)
                path.move(to: start)
                path.addQuadCurve(
                    to: end,
                    control: CGPoint(x: (start.x + end.x) / 2, y: y(controlY))
                )
                context.stroke(path, with: ink, lineWidth: scale * 0.16)
            }
        }
    }

    private static func drawNote(
        _ note: StaffLayout.NoteLayout,
        atX noteX: CGFloat,
        y: (Double) -> CGFloat,
        font: CTFont,
        ink: GraphicsContext.Shading,
        scale: CGFloat,
        context: inout GraphicsContext
    ) {
        // Ledger lines.
        for ledger in note.ledgers {
            var path = Path()
            path.move(to: CGPoint(x: noteX - 0.85 * scale, y: y(ledger)))
            path.addLine(to: CGPoint(x: noteX + 0.85 * scale, y: y(ledger)))
            context.stroke(path, with: ink, lineWidth: scale * 0.12)
        }

        let headGlyph: Bravura.Glyph
        switch note.head {
        case .notehead(let glyph), .rest(let glyph): headGlyph = glyph
        }

        // Stem + flags (never on whole notes or rests).
        if !note.isRest, headGlyph != .noteheadWhole {
            let stemX = noteX + (note.stemUp ? 1 : -1) * note.headHalfWidth * scale
            let tipY = note.y + (note.stemUp ? 3.5 : -3.5)
            var stem = Path()
            stem.move(to: CGPoint(x: stemX, y: y(note.y)))
            stem.addLine(to: CGPoint(x: stemX, y: y(tipY)))
            context.stroke(stem, with: ink, lineWidth: scale * 0.12)

            for flagIndex in 0..<note.flags {
                let glyph: Bravura.Glyph = note.stemUp
                    ? (flagIndex == 0 ? .flag8thUp : flagIndex == 1 ? .flag16thUp : .flag32ndUp)
                    : (flagIndex == 0 ? .flag8thDown : flagIndex == 1 ? .flag16thDown : .flag32ndDown)
                // Stack repeated flags down the stem a space apart.
                let flagY = tipY + (note.stemUp ? -0.8 * Double(flagIndex) : 0.8 * Double(flagIndex))
                drawGlyph(glyph, atX: stemX - 0.1 * scale, baseline: y(flagY), font: font, in: &context)
            }
        }

        // Accidental, head, dots.
        let halfWidth = note.headHalfWidth * scale
        if let accidental = note.accidental {
            drawGlyph(
                accidental,
                atX: noteX - halfWidth - 0.9 * scale,
                baseline: y(note.y),
                font: font,
                in: &context
            )
        }
        drawGlyph(headGlyph, atX: noteX - halfWidth, baseline: y(note.y), font: font, in: &context)
        for dotIndex in 0..<note.dots {
            drawGlyph(
                .augmentationDot,
                atX: noteX + halfWidth + 0.6 * scale + 0.75 * scale * CGFloat(dotIndex),
                baseline: y(note.y),
                font: font,
                in: &context
            )
        }
    }

    /// Draws one Bravura glyph with its baseline at the given point.
    /// Canvas's CGContext is top-left flipped; CoreText draws y-up from
    /// the baseline, so flip locally.
    private static func drawGlyph(
        _ glyph: Bravura.Glyph,
        atX px: CGFloat,
        baseline py: CGFloat,
        font: CTFont,
        in context: inout GraphicsContext
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: inkCGColor,
        ]
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: String(glyph.rawValue), attributes: attributes)
        )
        context.withCGContext { cg in
            cg.saveGState()
            cg.translateBy(x: px, y: py)
            cg.scaleBy(x: 1, y: -1)
            cg.textPosition = .zero
            CTLineDraw(line, cg)
            cg.restoreGState()
        }
    }
}
