import Foundation

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
