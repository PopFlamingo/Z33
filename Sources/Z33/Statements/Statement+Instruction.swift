import Foundation
import ParserBuilder

public protocol Statement: Equatable {
    static func parse(from substring: Substring) throws -> ParseResult<Self>?
    var assemblyValue: String { get }
}

public protocol Instruction: Statement {
    associatedtype Processor: ProcessorProtocol
    
    static var name: String { get }
    static var opcode: UInt8 { get }
    static var isPrivileged: Bool { get }
    static var isReset: Bool { get }
    static var reversedMachineCodeArguments: Bool { get }
    static var argumentsDescription: ArgumentsDescription { get }
    
    init(arguments: ArgumentsStorage<Processor>)
    var arguments: ArgumentsStorage<Processor> { get }
    
    func execute(on processor: inout Processor) throws
    
    func encodeToBinary() -> UInt64?
    static func decodeFromBinary(_ binaryPattern: UInt64) -> Self?
}

public enum ArgumentsDescription {
    case none
    case unary(AddressingMode)
    case binary(AddressingMode, AddressingMode)
}

protocol NullaryInstruction: Instruction {
}

extension NullaryInstruction {
    init() {
        self.init(arguments: .none)
    }
    public static var argumentsDescription: ArgumentsDescription { .none }
}

public protocol UnaryInstruction: Instruction {
    static func compute(input: UInt32, processor: inout Processor) throws
}

extension UnaryInstruction {
    public func execute(on processor: inout Processor) throws {
        guard case ArgumentsStorage.unary(let argument) = arguments else {
            fatalError("Unexpected kind of argument")
        }
        let value = try processor.readData(at: argument)
        try Self.compute(input: value, processor: &processor)
    }
}

protocol UnaryRegisterModificator: Instruction {
    static func compute(modified: UInt32, processor: inout Processor) throws -> UInt32
}

extension UnaryRegisterModificator {
    public func execute(on processor: inout Processor) throws {
        let register = self.arguments.extractAssertingUnaryArgument(allowedModes: .register)
        let value = try processor.readData(at: register)
        let modified = try Self.compute(modified: value, processor: &processor)
        try processor.writeData(at: register, value: modified)
    }
    
    public static var argumentsDescription: ArgumentsDescription {
        .unary(.register)
    }
}

public protocol BinaryRegisterModificator: Instruction {
    static func compute(input: UInt32, destination: UInt32, processor: inout Processor) throws -> UInt32
}

extension BinaryRegisterModificator {
    public func execute(on processor: inout Processor) throws {
        // TODO: Be more specific for lhs
        let (inputArg, outputArg) = arguments.extractAssertingBinaryArgument(lhsAllowedModes: .all, rhsAllowedModes: .register)
        let input = try processor.readData(at: inputArg)
        let destination = try processor.readData(at: outputArg)
        let result = try Self.compute(input: input, destination: destination, processor: &processor)
        try processor.writeData(at: outputArg, value: result)
    }
}

public enum ArgumentsStorage<Variation: ProcessorProtocol>: Equatable, CustomStringConvertible {
    case none
    case unary(Argument<Variation>)
    case binary(Argument<Variation>, Argument<Variation>)
    
    func extractAssertingUnaryArgument(allowedModes: AddressingMode = .all) -> Argument<Variation> {
        guard case .unary(let argument) = self else {
            fatalError("Unexpected non-unary argument")
        }
        
        switch argument {
        case .immediate:
            precondition(allowedModes.contains(.immediate))
        case .direct:
            precondition(allowedModes.contains(.direct))
        case .indirect:
            precondition(allowedModes.contains(.indirect))
        case .indexedIndirect:
            precondition(allowedModes.contains(.indexedIndirect))
        case .register:
            precondition(allowedModes.contains(.register))
        }
        
        return argument
    }
    
    @inline(__always)
    func extractAssertingBinaryArgument(lhsAllowedModes: AddressingMode = .all, rhsAllowedModes: AddressingMode = .all) -> (lhs: Argument<Variation>, rhs: Argument<Variation>) {
        guard case .binary(let lhs, let rhs) = self else {
            fatalError("Unexpected non-binary argument")
        }
        
        switch lhs {
        case .immediate:
            precondition(lhsAllowedModes.contains(.immediate))
        case .direct:
            precondition(lhsAllowedModes.contains(.direct))
        case .indirect:
            precondition(lhsAllowedModes.contains(.indirect))
        case .indexedIndirect:
            precondition(lhsAllowedModes.contains(.indexedIndirect))
        case .register:
            precondition(lhsAllowedModes.contains(.register))
        }
        
        switch rhs {
        case .immediate:
            precondition(rhsAllowedModes.contains(.immediate))
        case .direct:
            precondition(rhsAllowedModes.contains(.direct))
        case .indirect:
            precondition(rhsAllowedModes.contains(.indirect))
        case .indexedIndirect:
            precondition(rhsAllowedModes.contains(.indexedIndirect))
        case .register:
            precondition(rhsAllowedModes.contains(.register))
        }
        
        return (lhs, rhs)
    }
    
    public var description: String {
        switch self {
        case .none:
            return "[no argument]"
        case .unary(let arg):
            return arg.description
        case .binary(let lhs, let rhs):
            return "\(lhs), \(rhs)"
        }
    }
}

enum ArgumentKind: UInt8 {
    case immediate = 0
    case register = 1
    case direct = 2
    case indirect = 3
    case indexedIndirect = 4
}

public enum Argument<Variation: ProcessorProtocol>: Equatable, CustomStringConvertible {
    case immediate(UInt32)
    case register(UInt32)
    case direct(UInt32)
    case indirect(UInt32)
    case indexedIndirect(UInt32, Int32)
    
    init?(kind: ArgumentKind, isHigherPrecision: Bool, value: UInt32) {
        
        switch kind {
        case .immediate:
            self = .immediate(value)
            
        case .register:
            guard let offset = Variation.registerMemoryOffset(for: value) else {
                return nil
            }
            self = .register(offset)
        
        case .direct:
            self = .direct(value)
            
        case .indirect:
            guard Variation.registerKeyPath(for: value) != nil else {
                return nil
            }
            self = .indirect(value)
            
        case .indexedIndirect:
            // FIXME: What type should value actually be?
            let registerCode = value >> (isHigherPrecision ? 24 : 10)
            guard Variation.registerKeyPath(for: registerCode) != nil else {
                return nil
            }
            
            let offsetBitPattern = ((value << (isHigherPrecision ? 8 : 22)) >> (isHigherPrecision ? 8 : 22))
            let offset: Int32
            
            // If value has a sign, conserve it
            if offsetBitPattern & (0b1 << (isHigherPrecision ? 23 : 9)) != 0 {
                let missingOnes: UInt32 = .max << (isHigherPrecision ? 24 : 10)
                offset = Int32(bitPattern: missingOnes | offsetBitPattern)
            } else {
                offset = Int32(bitPattern: offsetBitPattern)
            }
            
            self = .indexedIndirect(registerCode, offset)
        }
    }
    
    func binaryEncodedValue(isHigherPrecision: Bool) -> UInt32? {
        switch self {
        case .immediate(let value), .direct(let value):
            if isHigherPrecision || value == value & (~0 >> 14) {
                return value
            } else {
                return nil
            }
        
        case .register(let registerCode), .indirect(let registerCode):
            return registerCode
            
        case .indexedIndirect(let registerCode, let offset):
            let registerCode = registerCode << (isHigherPrecision ? 24 : 10)
            let uOffset = UInt32(bitPattern: offset)
            let mask: UInt32 = ~0 >> (isHigherPrecision ? 8 : 22)
            if (offset < 0 && uOffset == (uOffset | ~(~0 >> (isHigherPrecision ? 9 : 23)))) ||
                (offset >= 0 && uOffset == (uOffset & (~0 >> (isHigherPrecision ? 9 : 23)))) {
                return registerCode | UInt32(bitPattern: offset) & mask
            } else {
                return nil
            }
        }
        
    }
    
    var kind: ArgumentKind {
        switch self {
        case .immediate:
            return .immediate
        case .register:
            return .register
        case .direct:
            return .direct
        case .indirect:
            return .indirect
        case .indexedIndirect:
            return .indexedIndirect
        }
    }
    
    func modifyProcessor(_ processor: inout Variation, with value: UInt32) throws {
        switch self {
        case .immediate:
            fatalError("Attempting to modify a processor using an immediate value as memory accessor")
        case .register(let registerKeyPath):
            try processor.writeRegister(value: value, at: registerKeyPath)
        case .direct(let address):
            try processor.writeMemory(value: address, at: value)
        case .indirect(let indirectAddress):
            let address = try processor.readRegister(at: indirectAddress)
            try processor.writeMemory(value: value, at: address)
        case .indexedIndirect(let indirectAddress, let offset):
            let computedAddress = try Int64(processor.readRegister(at: indirectAddress)) + Int64(offset)
            guard let address = UInt32(exactly: computedAddress) else {
                throw Exception(eventCode: .invalidMemoryAccess)
            }
            try processor.writeMemory(value: value, at: address)
        }
    }
    func extractFromProcessor(_ processor: inout Variation) throws -> UInt32 {
        switch self {
        case .immediate(let value):
            return value
        case .register(let registerKeyPath):
            return try processor.readRegister(at: registerKeyPath)
        case .direct(let address):
            return try processor.readMemory(at: address)
        case .indirect(let indirectAddress):
            let address = try processor.readRegister(at: indirectAddress)
            return try processor.readMemory(at: address)
        case .indexedIndirect(let indirectAddress, let offset):
            let computedAddress = try Int64(processor.readRegister(at: indirectAddress)) + Int64(offset)
            guard let address = UInt32(exactly: computedAddress) else {
                throw Exception(eventCode: .invalidMemoryAccess)
            }
            return try processor.readMemory(at: address)
        }
    }
    
    public var description: String {
        switch self {
        case .immediate(let value):
            return value.description
        case .register(let register):
            let registerName = Variation.registerName(for: register)
            return "$\(registerName)"
        case .direct(let address):
            return "[\(address)]"
        case .indirect(let register):
            let registerName = Variation.registerName(for: register)
            return "[$\(registerName)]"
        case .indexedIndirect(let register, let offset):
            let registerName = Variation.registerName(for: register)
            let sign = offset > 0 ? "+" : "-"
            return "[$\(registerName) \(sign) \(abs(offset))]"
        }
    }
}

public struct AddressingMode: OptionSet {
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    public let rawValue: UInt8
    
    public static let immediate = AddressingMode(rawValue: 0b1)
    public static let register = AddressingMode(rawValue: 0b1 << 1)
    public static let direct = AddressingMode(rawValue: 0b1 << 2)
    public static let indirect = AddressingMode(rawValue: 0b1 << 3)
    public static let indexedIndirect = AddressingMode(rawValue: 0b1 << 4)
    public static let all = AddressingMode(rawValue: ~0)
    
    func contains(argumentKind: ArgumentKind) -> Bool {
        switch argumentKind {
        case .immediate:
            return self.contains(.immediate)
        case .register:
            return self.contains(.register)
        case .direct:
            return self.contains(.direct)
        case .indirect:
            return self.contains(.indirect)
        case .indexedIndirect:
            return self.contains(.indexedIndirect)
        }
    }
}
