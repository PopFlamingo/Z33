import ParserBuilder

struct Word: Statement {
    var value: Int32
    
    static func parse(from substring: Substring) throws -> ParseResult<Word>? {
        var extractor = Extractor(substring)
        guard extractor.popCurrent(with: ".addr" + CommonMatchers.whitespace.count(0...)) != nil else {
            return nil
        }
        
        guard let value = try extractor.popNumberLiteral() else {
            throw ParseError(description: "Expected a number literal", location: .single(extractor.currentIndex))
        }
        
        return .init(value: .init(value: value), advancedIndex: extractor.currentIndex)
    }
    
    var assemblyValue: String {
        return ".word \(value)"
    }
}
