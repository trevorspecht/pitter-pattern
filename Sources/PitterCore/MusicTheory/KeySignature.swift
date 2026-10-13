import Foundation

/// A key signature: sharps if positive, flats if negative, 0 = none.
public struct KeySignature: Hashable, Codable, Sendable {
    /// Sharps if positive, flats if negative, 0 = none. Range: -7...7.
    public let sharpsOrFlats: Int
    
    public init(sharpsOrFlats: Int) {
        precondition(-7...7 ~= sharpsOrFlats, "Key signature must be between -7 and 7 sharps/flats")
        self.sharpsOrFlats = sharpsOrFlats
    }
    
    /// Number of sharps (0 if negative or 0).
    public var sharps: Int {
        return max(0, sharpsOrFlats)
    }
    
    /// Number of flats (0 if positive or 0).
    public var flats: Int {
        return max(0, -sharpsOrFlats)
    }
    
    /// True if there are no accidentals.
    public var isEmpty: Bool {
        return sharpsOrFlats == 0
    }
    
    /// The accidentals in order they appear on the staff.
    public var accidentalsInOrder: [Letter] {
        if sharpsOrFlats > 0 {
            // Sharps: F, C, G, D, A, E, B
            let sharpOrder: [Letter] = [.f, .c, .g, .d, .a, .e, .b]
            return Array(sharpOrder[0..<sharps])
        } else if sharpsOrFlats < 0 {
            // Flats: B, E, A, D, G, C, F
            let flatOrder: [Letter] = [.b, .e, .a, .d, .g, .c, .f]
            return Array(flatOrder[0..<flats])
        } else {
            return []
        }
    }
    
    /// Returns the accidental for a given letter in this key signature:
    /// sharp/flat if the letter is one of *this signature's* accidentals
    /// (not the whole order), otherwise natural.
    public func accidental(for letter: Letter) -> Accidental {
        if accidentalsInOrder.contains(letter) {
            return sharpsOrFlats > 0 ? .sharp : .flat
        }
        return .natural
    }
    
    /// String description of the key signature.
    public var description: String {
        if sharpsOrFlats == 0 {
            return "no accidentals"
        } else if sharpsOrFlats > 0 {
            let count = sharps
            let letters = accidentalsInOrder.map { $0.description + accidental(for: $0).symbol }.joined(separator: " ")
            return "\(count) sharp\(count == 1 ? "" : "s") (\(letters))"
        } else {
            let count = flats
            let letters = accidentalsInOrder.map { $0.description + accidental(for: $0).symbol }.joined(separator: " ")
            return "\(count) flat\(count == 1 ? "" : "s") (\(letters))"
        }
    }
}