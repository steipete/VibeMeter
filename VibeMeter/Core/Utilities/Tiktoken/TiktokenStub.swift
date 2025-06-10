// Minimal stub replacement for the external Tiktoken library.
// This is **temporary** until the full library is vendored.
// Provides just enough API surface for VibeMeter to compile.

import Foundation

public enum Encoding: String, CaseIterable {
    case r50k_base = "r50k_base"
    case p50k_base = "p50k_base"
    case cl100k_base = "cl100k_base"
    case o200k_base = "o200k_base"
}

public struct Tiktoken {
    public let encoding: Encoding
    public init(encoding: Encoding) throws {
        self.encoding = encoding
    }

    // Very naive token estimate: 1 token ≈ 4 characters.
    public func countTokens(of text: String) -> Int {
        max(1, text.count / 4)
    }
}

