import Foundation
import ParserBuilder

protocol Statement {
    static func parse(from substring: Substring) throws -> ParseResult<Self>?
    var assemblyValue: String { get }
}

protocol Instruction: Statement {
    associatedtype Processor: ProcessorProtocol
    
    static var name: String { get }
    static var opcode: UInt8 { get }
    static var argumentsDescription: ArgumentsDescription { get }
    
    init(arguments: ArgumentsStorage<Processor>)
    var arguments: ArgumentsStorage<Processor> { get }
    
    func execute(on processor: inout Processor) throws
}

enum ArgumentsDescription {
    case none
    case unary(AddressingMode)
    case binary(AddressingMode, AddressingMode)
}

protocol RegisterModificator: Instruction {
    func compute(input: Int32, destination: Int32, processor: inout Processor) throws -> Int32
}

extension RegisterModificator {
    func execute(on processor: inout Processor) throws {
        guard case ArgumentsStorage.binary(let lhs, let rhs) = arguments else {
            fatalError("Unexpected kind of argument")
        }
        
        guard case Argument<Processor>.register(let destinationRegister) = rhs else {
            fatalError("Unexpected value for rhs argument")
        }
        
        let destination = processor.registers[keyPath: destinationRegister]
        let result: Int32
        switch lhs {
        case .immediate(let value):
            result = try self.compute(input: value, destination: destination, processor: &processor)
        case .register(let registerKeyPath):
            let input = processor.registers[keyPath: registerKeyPath]
            result = try self.compute(input: input, destination: destination, processor: &processor)
        case .direct(let address):
            let input = try processor.readMemory(at: address)
            result = try self.compute(input: input, destination: destination, processor: &processor)
        case .indirect(let registerKeyPath):
            let address = processor.registers[keyPath: registerKeyPath]
            let input = try processor.readMemory(at: address)
            result = try self.compute(input: input, destination: destination, processor: &processor)
        case .indexedIndirect(let registerKeyPath, let offset):
            let address = processor.registers[keyPath: registerKeyPath]
            let input = try processor.readMemory(at: address) + offset
            result = try self.compute(input: input, destination: destination, processor: &processor)
        }
        
        processor.registers[keyPath: destinationRegister] = result
    }
}

enum ArgumentsStorage<Variation: ProcessorProtocol> {
    case none
    case unary(Argument<Variation>)
    case binary(Argument<Variation>, Argument<Variation>)
}

enum Argument<Variation: ProcessorProtocol> {
    case immediate(Int32)
    case register(WritableKeyPath<Variation.RegistersStorage, Int32>)
    case direct(Int32)
    case indirect(WritableKeyPath<Variation.RegistersStorage, Int32>)
    case indexedIndirect(WritableKeyPath<Variation.RegistersStorage, Int32>, Int32)
}

struct AddressingMode: OptionSet {
    let rawValue: UInt8
    
    static let immediate = AddressingMode(rawValue: 0b1)
    static let register = AddressingMode(rawValue: 0b1 << 1)
    static let direct = AddressingMode(rawValue: 0b1 << 2)
    static let indirect = AddressingMode(rawValue: 0b1 << 3)
    static let indexedIndirect = AddressingMode(rawValue: 0b1 << 4)
    static let all = AddressingMode(rawValue: ~0)
}
