public enum Clef: String, CaseIterable, Codable, Sendable, Hashable {
    case treble, bass    // alto/tenor/percussion can be added when the renderer needs them
    
    public var description: String {
        switch self {
        case .treble: return "Treble"
        case .bass: return "Bass"
        }
    }
}