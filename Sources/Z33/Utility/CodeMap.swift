import Foundation

/// This types maps modifications of a string to an original string
///
/// This is used to map code after its been modified by the preprocessor to the original code
struct CodeMap: CustomDebugStringConvertible {
    init(string: String) {
        self.original = string
        self.modified = string
        let stringRange = string.startIndex..<string.endIndex
        self.segments = [Segment(previous: stringRange, current: stringRange, isDirectMapping: true)]
    }
    
    var debugDescription: String {
        return """
        {
        Original:
        \(original.debugDescription)

        Modified:
        \(modified.debugDescription)

        Segments:
        \(segments.map({ "original: \(original[$0.previous].debugDescription), modified: \(modified[$0.current].debugDescription), isDirectMapping: \($0.isDirectMapping)" }).joined(separator: "\n"))
        }
        """
    }
    
    let original: String
    var modified: String
    var segments: [Segment]

    enum OriginalConversionResult {
        case oneToOne(String.Index)
        case oneToRange(Range<String.Index>)
        case oneToFileOffset(UUID,Int)
    }
    
    func convertToOriginal(from modifiedIndex: String.Index) -> OriginalConversionResult {
        let segmentIndex = self.segmentIndex(for: modifiedIndex, in: .modified)!
        let segment = self.segments[segmentIndex]
        let offset = modified.distance(from: segment.current.lowerBound, to: modifiedIndex)
        
        if let uuid = segment.externalUUID {
            return .oneToFileOffset(uuid, offset)
        } else if segment.isDirectMapping {
            let base = segment.previous.lowerBound
            return .oneToOne(original.index(base, offsetBy: offset))
        } else {
            return .oneToRange(segment.previous)
        }
    }
    
    func convertToModified(from offset: Int, in fileUUID: UUID) -> String.Index? {
        guard let segment = self.segments.first(where: { $0.externalUUID == fileUUID }) else {
            return nil
        }
        return self.modified.index(segment.current.lowerBound, offsetBy: offset)
    }
    
    func convertToModified(from originalIndex: String.Index) -> String.Index? {
        guard let segmentIndex = self.segmentIndex(for: originalIndex, in: .original) else {
            return nil
        }
        let segment = self.segments[segmentIndex]
        
        // This wouldn't make much sense to convert from the index of a file to a
        // different file inclusion
        guard segment.externalUUID != nil else {
            return nil
        }
        
        let distance = original.distance(from: segment.previous.lowerBound, to: originalIndex)
        return modified.index(segment.current.lowerBound, offsetBy: distance)
    }
    
    @discardableResult
    mutating func insertFileContents(_ contents: String, file: UUID, at range: Range<String.Index>) -> String.Index {
        return self._replaceCharacters(in: range, with: contents, uuid: file)
    }
    
    @discardableResult
    mutating func replaceCharacters(in range: Range<String.Index>, with string: String) -> String.Index {
        return self._replaceCharacters(in: range, with: string, uuid: nil)
    }
    
    private mutating func _replaceCharacters(in range: Range<String.Index>, with string: String, uuid: UUID?) -> String.Index {
        let insertIndex = self.removeCharacters(in: range)
        let start = self.segments[insertIndex-1].previous.upperBound
        let end = self.segments[insertIndex].previous.lowerBound
        modified.insert(contentsOf: string, at: range.lowerBound)
        let currentEnd = modified.index(range.lowerBound, offsetBy: string.count)
        self.segments.insert(.init(previous: start..<end, current: range.lowerBound..<currentEnd, isDirectMapping: false, externalUUID: uuid), at: insertIndex)
        for i in insertIndex+1..<segments.count {
            let segment = self.segments[i]
            let newLowerBound = modified.index(segment.current.lowerBound, offsetBy: string.count)
            let newUpperBound = modified.index(segment.current.upperBound, offsetBy: string.count)
            self.segments[i].current = newLowerBound..<newUpperBound
        }
        
        return currentEnd
    }
    
    @discardableResult
    mutating func removeCharacters(in range: Range<String.Index>) -> Int {
        guard let lastRemovedIndex = modified.index(range.upperBound, offsetBy: -1, limitedBy: range.lowerBound) else {
            return self.splitSegment(at: range.lowerBound) + 1
        }
        
        let insertIndex = self.splitSegment(at: range.lowerBound) + 1
        self.splitSegment(at: range.upperBound)
        let start = segmentIndex(for: range.lowerBound, in: .modified)!
        let end = segmentIndex(for: lastRemovedIndex, in: .modified)!

        let distances = Dictionary(
            (start..<segments.count).map { (i: Int) -> (index: Int, distance: Int) in
                let segment = self.segments[i]
                let beforeEnd = modified.index(before: segment.current.upperBound)
                return (index: i, distance: modified.distance(from: segment.current.lowerBound, to: beforeEnd))}
        ) { index,_ in
            return index
        }
        
        modified.removeSubrange(range)
        self.segments.removeSubrange(start...end)
        for i in start..<segments.count {
            let lowerBound = self.segments[i-1].current.upperBound
            let upperBound = modified.index(lowerBound, offsetBy: distances[end+1]! + 1)
            segments[i].current = lowerBound..<upperBound
        }
        
        return insertIndex
    }
    
    @discardableResult
    mutating func splitSegment(at stringIndex: String.Index) -> Int {
        let index = self.segmentIndex(for: stringIndex, in: .modified)!
        let segment = self.segments[index]
        guard segment.isDirectMapping else {
            fatalError("Splitting a segment that isn't a direct mapping isn't supported")
        }
        
        let lowerToIndexDistance = modified.distance(from: segment.current.lowerBound, to: stringIndex)
        
        let currentRangeA = segment.current.lowerBound..<stringIndex
        let currentRangeB = stringIndex..<segment.current.upperBound
        
        let middle = original.index(segment.previous.lowerBound, offsetBy: lowerToIndexDistance)
        let originalRangeA = segment.previous.lowerBound..<middle
        let originalRangeB = middle..<segment.previous.upperBound
        
        let segmentA = Segment(previous: originalRangeA, current: currentRangeA, isDirectMapping: true)
        let segmentB = Segment(previous: originalRangeB, current: currentRangeB, isDirectMapping: true)
        
        self.segments.insert(contentsOf: [segmentA, segmentB], at: index+1)
        self.segments.remove(at: index)
        return index
    }
    
    func segmentIndex(for stringIndex: String.Index, in context: StringContext) -> Int? {
        let keyPath: KeyPath<Segment, Range<String.Index>>
        
        switch context {
        case .modified:
            keyPath = \.current
        case .original:
            keyPath = \.previous
        }
        
        for (index, segment) in segments.enumerated() {
            if segment[keyPath: keyPath].lowerBound <= stringIndex && stringIndex < segment[keyPath: keyPath].upperBound {
                return index
            }
        }
        
        if stringIndex == modified.endIndex {
            return segments.endIndex-1
        } else {
            return nil
        }
    }
    
    enum StringContext {
        case original
        case modified
    }
    
    struct Segment {
        init(previous: Range<String.Index>,
             current: Range<String.Index>,
             isDirectMapping: Bool,
             externalUUID: UUID? = nil) {
            self.previous = previous
            self.current = current
            self.isDirectMapping = isDirectMapping
            self.externalUUID = externalUUID
        }
        
        var previous: Range<String.Index>
        var current: Range<String.Index>
        var isDirectMapping: Bool
        var externalUUID: UUID?
    }
}
