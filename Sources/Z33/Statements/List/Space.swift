import ParserBuilder

struct Space: Statement {
    var size: Int32
    
    static func parse(from substring: Substring) throws -> ParseResult<Space>? {
        var extractor = Extractor(substring)
        guard extractor.popCurrent(with: ".space" + CommonMatchers.whitespace.count(0...)) != nil else {
            return nil
        }
        
        guard let value = try extractor.popNumberLiteral() else {
            throw ParseError(description: "Expected a number literal", location: .single(extractor.currentIndex))
        }
        
        return .init(value: .init(size: value), advancedIndex: extractor.currentIndex)
    }
    
    var assemblyValue: String {
        return ".space \(size)"
    }
}
