import Foundation

public enum Encoding: String, CaseIterable {
    case r50k_base
    case p50k_base
    case cl100k_base
    case o200k_base // Added for Claude support

    public var vocabSize: Int {
        switch self {
        case .r50k_base:
            50257
        case .p50k_base, .cl100k_base:
            100_277
        case .o200k_base:
            200_000 // Approximate size, will be determined by actual vocab file
        }
    }
}
