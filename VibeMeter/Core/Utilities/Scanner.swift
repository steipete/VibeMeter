import Foundation

/// Custom character set for efficient character matching
struct CustomCharacterSet {
    private var characters: Set<Character>

    init(charactersInString: String) {
        self.characters = Set(charactersInString.map(\.self))
    }

    func contains(_ character: Character) -> Bool {
        self.characters.contains(character)
    }

    static var decimalDigits: CustomCharacterSet {
        CustomCharacterSet(charactersInString: "0123456789")
    }

    static var whitespacesAndNewlines: CustomCharacterSet {
        CustomCharacterSet(charactersInString: " \t\n\r")
    }
}

/// Fast custom scanner for parsing structured text
class FastScanner {
    let string: String
    let characters: [Character]
    var location: Int = 0

    init(string: String) {
        self.string = string
        self.characters = Array(string)
    }

    var isAtEnd: Bool {
        self.location >= self.characters.count
    }

    // MARK: - String Scanning

    @discardableResult
    func scan(string: String) -> String? {
        let targetChars = Array(string)

        // Check if we have enough characters left to scan
        guard self.location + targetChars.count <= self.characters.count else {
            return nil
        }

        // Check if the string matches at current location
        for (index, char) in targetChars.enumerated() {
            if self.characters[self.location + index] != char {
                return nil
            }
        }

        self.location += targetChars.count
        return string
    }

    // MARK: - Integer Scanning

    func scanInteger() -> Int? {
        scanWhitespaces()
        let initialLocation = self.location

        // Parse sign if present
        let sign = scan(string: "-") != nil ? -1 : 1
        if sign == 1 {
            _ = scan(string: "+")
        }

        // Parse digits
        var digitString = ""
        while self.location < self.characters.count {
            let char = self.characters[self.location]
            if CustomCharacterSet.decimalDigits.contains(char) {
                digitString.append(char)
                self.location += 1
            } else {
                break
            }
        }

        if digitString.isEmpty {
            self.location = initialLocation
            return nil
        }

        return Int(digitString).map { $0 * sign }
    }

    // MARK: - Whitespace Handling

    func scanWhitespaces() {
        while self.location < self.characters.count {
            let char = self.characters[self.location]
            if CustomCharacterSet.whitespacesAndNewlines.contains(char) {
                self.location += 1
            } else {
                break
            }
        }
    }

    // MARK: - Utility Methods

    func scanUpTo(string: String) -> String? {
        let startLocation = self.location
        let targetChars = Array(string)

        // Ensure we're not beyond the string bounds
        guard startLocation < self.characters.count else { return nil }
        guard !targetChars.isEmpty else { return nil }

        // Use first character for quick rejection
        let firstChar = targetChars[0]

        while self.location < self.characters.count {
            // Quick check: skip if first character doesn't match
            if self.characters[self.location] == firstChar {
                // Check if we have enough characters left to match the target string
                if self.location + targetChars.count <= self.characters.count {
                    // Now check the full match
                    var matches = true
                    for i in 1 ..< targetChars.count {
                        if self.characters[self.location + i] != targetChars[i] {
                            matches = false
                            break
                        }
                    }

                    if matches {
                        // Found the target string, return everything up to this point
                        if self.location > startLocation {
                            return String(self.characters[startLocation ..< self.location])
                        } else {
                            return nil // Nothing scanned
                        }
                    }
                }
            }
            self.location += 1
        }

        // Reached end without finding string - return rest of string if any
        if self.location > startLocation {
            return String(self.characters[startLocation ..< self.location])
        }

        return nil
    }
}

// MARK: - String Extension for Efficient Indexing

extension String {
    subscript(offset: Int) -> Character {
        guard offset >= 0, offset < count else {
            fatalError("String index out of bounds")
        }
        return self[index(startIndex, offsetBy: offset)]
    }

    subscript(range: Range<Int>) -> Substring {
        guard range.lowerBound >= 0, range.upperBound <= count else {
            fatalError("String range out of bounds")
        }
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(startIndex, offsetBy: range.upperBound)
        return self[start ..< end]
    }
}
