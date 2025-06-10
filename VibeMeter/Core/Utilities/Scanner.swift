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
        let savepoint = self.location
        
        for character in string {
            guard self.location < self.string.count else {
                self.location = savepoint
                return nil
            }
            
            if self.string[self.location] != character {
                self.location = savepoint
                return nil
            }
            
            self.location += 1
        }
        
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
        while self.location < self.string.count {
            let char = self.string[self.location]
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
        while self.location < self.string.count,
              CustomCharacterSet.whitespacesAndNewlines.contains(self.string[self.location]) {
            self.location += 1
        }
    }
    
    // MARK: - Utility Methods
    
    func scanUpTo(string: String) -> String? {
        let startLocation = self.location
        
        while self.location < self.string.count {
            // Check if we found the target string
            let startIndex = self.string.index(self.string.startIndex, offsetBy: self.location)
            if self.string[startIndex...].hasPrefix(string) {
                let endIndex = self.string.index(self.string.startIndex, offsetBy: self.location)
                let startIdx = self.string.index(self.string.startIndex, offsetBy: startLocation)
                let result = String(self.string[startIdx..<endIndex])
                return result.isEmpty ? nil : result
            }
            self.location += 1
        }
        
        // Reached end without finding string
        let startIdx = self.string.index(self.string.startIndex, offsetBy: startLocation)
        let result = String(self.string[startIdx...])
        return result.isEmpty ? nil : result
    }
}

// MARK: - String Extension for Efficient Indexing

extension String {
    subscript(offset: Int) -> Character {
        self[index(startIndex, offsetBy: offset)]
    }
    
    subscript(range: Range<Int>) -> Substring {
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(startIndex, offsetBy: range.upperBound)
        return self[start..<end]
    }
}