import ParserBuilder
import Foundation

extension Extractor {
    @discardableResult
    mutating func popStringLiteral() throws -> String? {
        let delimiter = Matcher("\"")
        let startIndex = self.currentIndex
        
        guard self.popCurrent(with: delimiter) != nil else {
            return nil
        }
        
        let stringExtractor = ((Matcher("\\\"") || .any()) && !delimiter).count(1...)
        
        let value = (self.popCurrent(with: stringExtractor) ?? "")
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\r", with: "\r")
            .replacingOccurrences(of: "\\t", with: "\t")
            .replacingOccurrences(of: "\\0", with: "\0")
        
        guard self.popCurrent(with: delimiter) != nil else {
            throw ParseError(description: "Unclosed string literal", location: .single(startIndex))
        }
        
        return value
    }
    
    @discardableResult
    mutating func popComment() throws -> String? {
        guard self.popCurrent(with: "//") != nil else {
            return nil
        }
        let content = self.popCurrent(with: (.any() && !("\n" || "\r")).count(0...)) ?? ""
        return String(content)
    }
    
    @discardableResult
    mutating func popNumberLiteral() throws -> UInt32? {
        let start = self.currentIndex
        let decimalNumber = Matcher("-").optional() + CommonMatchers.number.count(1...)
        let hexadecimalNumber = (CommonMatchers.number || Matcher("a"..."f") || Matcher("A"..."F")).count(1...)
        let binaryNumber: Matcher = ("0" || "1").count(1...)
        
        // FIXME: Do the 0b and 0x literals represent bitpattern or an actual number?
        if self.popCurrent(with: "0b") != nil {
            guard let binaryLiteral = self.popCurrent(with: binaryNumber) else {
                throw ParseError(description: "Invalid binary literal", location: .single(start))
            }
            guard let bitPattern = UInt32(binaryLiteral, radix: 2) else {
                throw ParseError(description: "Literal value is too large", location: .range(start..<self.currentIndex))
            }
            
            return bitPattern
        } else if self.popCurrent(with: "0x") != nil {
            guard let hexadecimalLiteral = self.popCurrent(with: hexadecimalNumber) else {
                throw ParseError(description: "Invalid hexadecimal literal", location: .single(start))
            }
            
            guard let bitPattern = UInt32(hexadecimalLiteral, radix: 16) else {
                throw ParseError(description: "Literal value is too large", location: .range(start..<self.currentIndex))
            }
            
            return bitPattern
        } else {
            guard let decimalLiteral = self.popCurrent(with: decimalNumber) else {
                return nil
            }
            
            // FIXME: Maybe add special handling for usigned value literals
            guard let extractedValue = Int32(decimalLiteral) else {
                throw ParseError(description: "Literal value is too large", location: .range(start..<self.currentIndex))
            }
            return UInt32(bitPattern: extractedValue)
        }
    }
}
