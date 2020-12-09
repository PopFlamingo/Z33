import ParserBuilder

struct Symbol: Statement {
    var name: String
    
    static func parse(from substring: Substring) throws -> ParseResult<Symbol>? {
        
        var extractor = Extractor(substring)
        guard let symbolName = extractor.popCurrent(with: CommonMatchers.symbolNameMatcher) else {
            return nil
        }
        
        extractor.popCurrent(with: CommonMatchers.whitespace.count(0...))
        
        guard extractor.popCurrent(with: ":") != nil else {
            return nil
        }
        
        return .init(value: .init(name: String(symbolName)), advancedIndex: extractor.currentIndex)
    }
    
    var assemblyValue: String {
        return "\(name):"
    }
}
