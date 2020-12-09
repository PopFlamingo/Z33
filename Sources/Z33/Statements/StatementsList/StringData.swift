import Foundation
import ParserBuilder

struct StringData: Statement {
    static func parse(from substring: Substring) throws -> ParseResult<StringData>? {
        var extractor = Extractor(substring)
        let stringDeclMatcher = Matcher(".string") + Matcher(" ").count(1...)
        
        guard extractor.popCurrent(with: stringDeclMatcher) != nil else {
            return nil
        }
        
        guard let value = try extractor.popStringLiteral() else {
            throw ParseError(description: "Expected a string literal", location: .single(extractor.currentIndex))
        }
        
        return ParseResult(value: .init(String(value)), advancedIndex: extractor.currentIndex)
    }
    
    init(_ value: String) {
        self.value = value
    }
    
    var value: String
    
    var assemblyValue: String {
        // FIXME: Maybe debugDescription isn't right
        return ".string \(value.debugDescription)"
    }
}
