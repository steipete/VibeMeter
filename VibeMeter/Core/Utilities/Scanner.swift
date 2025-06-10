// Scanner.swift - Custom scanner implementation adapted from AXspector
// Optimized for parsing Claude log entries

import Foundation

/// Custom character set for efficient character matching
struct CustomCharacterSet {
    private var characters: Set<Character>
    
    init(charactersInString: String) {
        self.characters = Set(charactersInString.map { $0 })
    }
    
    func contains(_ character: Character) -> Bool {
        return self.characters.contains(character)
    }
    
    static var decimalDigits: CustomCharacterSet {
        return CustomCharacterSet(charactersInString: "0123456789")
    }
    
    static var whitespacesAndNewlines: CustomCharacterSet {
        return CustomCharacterSet(charactersInString: " \t\n\r")
    }
}

/// Fast custom scanner for parsing structured text
class FastScanner {
    let string: String
    var location: Int = 0
    
    init(string: String) {
        self.string = string
    }
    
    var isAtEnd: Bool {
        return self.location >= self.string.count
    }
    
    // MARK: - String Scanning
    
    @discardableResult
    func scan(string: String) -> String? {
        // Check if we have enough characters left to scan
        guard self.location + string.count <= self.string.count else {
            return nil
        }
        
        // Check if the string matches at current location
        let startIndex = self.string.index(self.string.startIndex, offsetBy: self.location)
        let endIndex = self.string.index(startIndex, offsetBy: string.count)
        
        if self.string[startIndex..<endIndex] == string {
            self.location += string.count
            return string
        } else {
            return nil
        }
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
        while self.location < self.string.count {
            let index = self.string.index(self.string.startIndex, offsetBy: self.location)
            let char = self.string[index]
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
        while self.location < self.string.count {
            let index = self.string.index(self.string.startIndex, offsetBy: self.location)
            let char = self.string[index]
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
        
        // Ensure we're not beyond the string bounds
        guard startLocation < self.string.count else { return nil }
        
        while self.location < self.string.count {
            // Check if we have enough characters left to match the target string
            if self.location + string.count <= self.string.count {
                // Check if we found the target string
                let currentIndex = self.string.index(self.string.startIndex, offsetBy: self.location)
                let endCheckIndex = self.string.index(currentIndex, offsetBy: string.count)
                
                if self.string[currentIndex..<endCheckIndex] == string {
                    // Found the target string, return everything up to this point
                    if self.location > startLocation {
                        let startIdx = self.string.index(self.string.startIndex, offsetBy: startLocation)
                        let endIdx = self.string.index(self.string.startIndex, offsetBy: self.location)
                        return String(self.string[startIdx..<endIdx])
                    } else {
                        return nil // Nothing scanned
                    }
                }
            }
            self.location += 1
        }
        
        // Reached end without finding string - return rest of string if any
        if self.location > startLocation {
            let startIdx = self.string.index(self.string.startIndex, offsetBy: startLocation)
            let endIdx = self.string.index(self.string.startIndex, offsetBy: self.location)
            return String(self.string[startIdx..<endIdx])
        }
        
        return nil
    }
}

// MARK: - String Extension for Efficient Indexing

extension String {
    subscript(offset: Int) -> Character {
        guard offset >= 0 && offset < count else {
            fatalError("String index out of bounds")
        }
        return self[index(startIndex, offsetBy: offset)]
    }
    
    subscript(range: Range<Int>) -> Substring {
        guard range.lowerBound >= 0 && range.upperBound <= count else {
            fatalError("String range out of bounds")
        }
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(startIndex, offsetBy: range.upperBound)
        return self[start..<end]
    }
}