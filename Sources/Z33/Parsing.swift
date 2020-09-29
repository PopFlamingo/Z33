import Foundation
import ParserBuilder

struct CommonMatchers {
    static let whitespace = Matcher(" ") || Matcher("\t")
    static let lowercaseLetter = Matcher("a"..."z")
    static let uppercaseLetter = Matcher("A"..."Z")
    static let letter = lowercaseLetter || uppercaseLetter
    static let number = Matcher("0"..."9")
    static let symbolNameMatcher: Matcher = {
        let alphaUnderscore = (Matcher("a"..."z") || Matcher("A"..."Z") || Matcher("_"))
        let restOfNameMatcher = alphaUnderscore || Matcher("0"..."9")
        return alphaUnderscore + restOfNameMatcher.count(0...) // Cannot start with a digit
    }()
}

struct ParseResult<T> {
    var value: T
    var advancedIndex: String.Index
}

struct ParseError: Error {
    init(description: String, location: Location) {
        self.description = description
        self.location = location
    }
    
    init(description: String, _ index: String.Index) {
        self.init(description: description, location: .single(index))
    }
    
    init(description: String, _ range: Range<String.Index>) {
        self.init(description: description, location: .range(range))
    }
    
    var description: String
    var location: Location
    
    enum Location {
        case single(String.Index)
        case range(Range<String.Index>)
    }
}

extension Instruction {
    static func parse(from substring: Substring) throws -> ParseResult<Self>? {
        func parseArgumentKind(_ argument: AddressingMode, using extractor: inout Extractor<Substring>) throws -> Argument<Processor> {
            let startPosition = extractor.currentIndex
            let decimalNumber = Matcher("-").optional() + CommonMatchers.number.count(1...)
            let hexadecimalNumber = (CommonMatchers.number || Matcher("a"..."f") || Matcher("A"..."F")).count(1...)
            let binaryNumber: Matcher = ("0" || "1").count(1...)
            let registerNameMatcher = (CommonMatchers.letter || CommonMatchers.number).count(1...)
            let immediateValueMatcher = decimalNumber || ("0x" + hexadecimalNumber) || ("0b" + binaryNumber)
            
            // Immediate
            if extractor.peekCurrent(with: immediateValueMatcher) != nil {
                guard argument.contains(.immediate) else {
                    throw ParseError(description: "Unexpected immediate value : \(Self.name) only supports one of \(argument) for this operand", location: .range(startPosition..<extractor.currentIndex))
                }
                
                guard let value = try extractor.popNumberLiteral() else {
                    throw ParseError(description: "Expected a number literal", location: .single(extractor.currentIndex))
                }
                
                return .immediate(value)
            } else if extractor.popCurrent(with: "%") != nil { // Register
                guard argument.contains(.register) else {
                    // FIXME: Debug description for argument
                    throw ParseError(description: "Unexpected register value : \(Self.name) only supports one of \(argument) for this operand", location: .range(startPosition..<extractor.currentIndex))
                }
                
                guard let registerName = extractor.popCurrent(with: registerNameMatcher) else {
                    throw ParseError(description: "Expected register name", location: .single(extractor.currentIndex))
                }
                guard let registerKeyPath = Processor.registerKeyPath(for: "\(registerName)") else {
                    throw ParseError(description: "Register %\(registerName) doesn't exist on this architecture", location: .single(extractor.currentIndex))
                }
                
                return .register(registerKeyPath)
            } else if extractor.popCurrent(with: "[") != nil { // Direct and indirect
                let start = extractor.currentIndex
                let whitespaces = CommonMatchers.whitespace.count(0...)
                let value: Argument<Processor>
                
                // Direct
                if  extractor.peekCurrent(with: whitespaces + CommonMatchers.number.count(1...)) != nil {
                    extractor.popCurrent(with: whitespaces)
                    let addressString = extractor.popCurrent(with: CommonMatchers.number.count(1...))!
                    
                    guard let address = UInt32(addressString) else {
                        throw ParseError(description: "Address is too large", location: .range(start..<extractor.currentIndex))
                    }
                    
                    value = .direct(Int32(bitPattern: address))
                } else if extractor.popCurrent(with: "%") != nil { // Indirect
                    guard let registerName = extractor.popCurrent(with: registerNameMatcher) else {
                        throw ParseError(description: "Expected register name", location: .single(extractor.currentIndex))
                    }
                    
                    guard let registerKeyPath = Processor.registerKeyPath(for: "\(registerName)") else {
                        throw ParseError(description: "Register %\(registerName) doesn't exist on this architecture", location: .single(extractor.currentIndex))
                    }
                    
                    // Indirect indexed
                    if extractor.peekCurrent(with: whitespaces + ("+" || "-") + whitespaces) != nil {
                        guard let numberString = extractor.popCurrent(with: whitespaces + ("+" || "-") + whitespaces + decimalNumber) else {
                            throw ParseError(description: "Expected number offset", location: .single(extractor.currentIndex))
                        }
                        
                        let spaceless = String(numberString)
                            .replacingOccurrences(of: " ", with: "")
                            .replacingOccurrences(of: "\t", with: "")
                        
                        guard let offset = Int32(spaceless) else {
                            throw ParseError(description: "Offset is too large", location: .single(extractor.currentIndex))
                        }
                        
                        value = .indexedIndirect(registerKeyPath, offset)
                    } else { // Indirect
                        value = .indirect(registerKeyPath)
                    }
                } else {
                    throw ParseError(description: "Invalid syntax", location: .single(extractor.currentIndex))
                }
                
                guard extractor.popCurrent(with: whitespaces + "]") != nil else {
                    throw ParseError(description: "Missing closing bracket", location: .single(extractor.currentIndex))
                }
                
                return value
            } else {
                throw ParseError(description: "Missing argument", location: .single(extractor.currentIndex))
            }
        }
        
        var extractor = Extractor(substring)
        let instructionNameMatcher = Matcher(Self.name)
        guard let name = extractor.popCurrent(with: instructionNameMatcher), name == Self.name else {
            return nil
        }
        
        switch argumentsDescription {
        case .none:
            return ParseResult(value: .init(arguments: .none), advancedIndex: extractor.currentIndex)
            
        case .unary(let argKind):
            extractor.popCurrent(with: CommonMatchers.whitespace.count(0...))
            let arg = try parseArgumentKind(argKind, using: &extractor)
            return ParseResult(value: .init(arguments: .unary(arg)), advancedIndex: extractor.currentIndex)
            
        case .binary(let argLHS, let argRHS):
            extractor.popCurrent(with: CommonMatchers.whitespace.count(0...))
            let lhs = try parseArgumentKind(argLHS, using: &extractor)
            guard extractor.popCurrent(with: CommonMatchers.whitespace.count(0...) + "," + CommonMatchers.whitespace.count(0...)) != nil else {
                throw ParseError(description: "Missing separator between binary arguments", location: .single(extractor.currentIndex))
            }
            let rhs = try parseArgumentKind(argRHS, using: &extractor)
            return ParseResult(value: .init(arguments: .binary(lhs, rhs)), advancedIndex: extractor.currentIndex)
        }
    }
    
    var assemblyValue: String {
        fatalError("Not implemented yet")
    }
}
