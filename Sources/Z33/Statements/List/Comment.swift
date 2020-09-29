import ParserBuilder

struct Comment: Statement {
    init(_ content: String) {
        self.content = content
    }
    
    var content: String
    
    static func parse(from substring: Substring) throws -> ParseResult<Comment>? {
        var extractor = Extractor(substring)
        guard let commentContent = try extractor.popComment() else {
            return nil
        }
        return .init(value: .init(commentContent), advancedIndex: extractor.currentIndex)
    }
    
    var assemblyValue: String {
        return "//\(content)"
    }
}
