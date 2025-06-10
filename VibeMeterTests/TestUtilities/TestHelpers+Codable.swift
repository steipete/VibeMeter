import Foundation
import Testing

// MARK: - Codable Test Helpers

extension Encodable where Self: Decodable {
    /// Tests roundtrip encoding/decoding for types that conform to both Encodable and Decodable
    /// - Returns: The decoded instance after roundtrip encoding
    /// - Throws: Any encoding or decoding errors
    func testRoundtrip() throws -> Self {
        let encoder = JSONEncoder()
        let encoded = try encoder.encode(self)

        let decoder = JSONDecoder()
        return try decoder.decode(Self.self, from: encoded)
    }
}

extension Encodable where Self: Decodable & Equatable {
    /// Tests roundtrip encoding/decoding and verifies equality
    /// - Throws: Any encoding, decoding, or equality assertion errors
    func verifyRoundtrip() throws {
        let decoded = try testRoundtrip()
        #expect(decoded == self)
    }
}

// MARK: - JSON String Helpers

extension Encodable {
    /// Encodes the object to a pretty-printed JSON string
    /// - Returns: JSON string representation
    /// - Throws: Encoding errors
    func toJSONString(prettyPrinted: Bool = true) throws -> String {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        let data = try encoder.encode(self)
        guard let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return string
    }
}

extension String {
    /// Decodes a JSON string to the specified type
    /// - Parameter type: The type to decode to
    /// - Returns: The decoded instance
    /// - Throws: Decoding errors
    func fromJSON<T: Decodable>(to type: T.Type) throws -> T {
        guard let data = self.data(using: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return try JSONDecoder().decode(type, from: data)
    }
}

// MARK: - Test Assertion Helpers

/// Asserts that encoding and decoding produce identical results
/// - Parameters:
///   - value: The value to test
///   - file: Source file (automatically provided)
///   - line: Source line (automatically provided)
func assertCodableRoundtrip<T: Codable & Equatable>(
    _ value: T,
    sourceLocation: SourceLocation = #_sourceLocation) throws {
    let encoded = try JSONEncoder().encode(value)
    let decoded = try JSONDecoder().decode(T.self, from: encoded)
    #expect(decoded == value, sourceLocation: sourceLocation)
}

/// Asserts that a type can be encoded to JSON without errors
/// - Parameters:
///   - value: The value to encode
///   - file: Source file (automatically provided)
///   - line: Source line (automatically provided)
func assertEncodable(
    _ value: some Encodable,
    sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(throws: Never.self, sourceLocation: sourceLocation) {
        _ = try JSONEncoder().encode(value)
    }
}

/// Asserts that JSON data can be decoded to the specified type
/// - Parameters:
///   - data: The JSON data to decode
///   - type: The type to decode to
///   - file: Source file (automatically provided)
///   - line: Source line (automatically provided)
func assertDecodable(
    _ data: Data,
    to type: (some Decodable).Type,
    sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(throws: Never.self, sourceLocation: sourceLocation) {
        _ = try JSONDecoder().decode(type, from: data)
    }
}
