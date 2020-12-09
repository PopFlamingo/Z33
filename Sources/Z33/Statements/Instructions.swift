public struct Add<Processor: ProcessorProtocol>: BinaryAllModesRM {
    public init(arguments: ArgumentsStorage<Processor>) {
        self.arguments = arguments
    }
    
    public static func compute(input: UInt32, destination: UInt32, processor: inout Processor) throws -> UInt32 {
        let msb: UInt32 = ~(UInt32.max >> 1)
        let result = input.addingReportingOverflow(destination)
        let resultValue = result.partialValue
        
        // Set the carry flag appropriately
        if result.overflow {
            processor.registers.srFlags.insert(.carry)
        } else {
            processor.registers.srFlags.remove(.carry)
        }
        
        // Set the overflow flag appropriately
        if ((input & msb) == (destination & msb)) && ((result.partialValue & msb) != (input & msb)) {
            processor.registers.srFlags.insert(.overflow)
        } else {
            processor.registers.srFlags.remove(.overflow)
        }
        
        processor.registers.srFlags.updateZeroNegativeFlags(for: resultValue)
        
        return resultValue
    }
    
    public static var name: String { "add" }
    
    public static var opcode: UInt8 { 0 }
    
    public var arguments: ArgumentsStorage<Processor>
}

public struct And<Processor: ProcessorProtocol>: BinaryAllModesRM {
    public init(arguments: ArgumentsStorage<Processor>) {
        self.arguments = arguments
    }
    
    public static func compute(input: UInt32, destination: UInt32, processor: inout Processor) throws -> UInt32 {
        let result = input & destination
        processor.registers.srFlags.updateZeroNegativeFlags(for: result)
        return result
    }
    
    public static var name: String { "and" }
    
    public static var opcode: UInt8 { 1 }
    
    public var arguments: ArgumentsStorage<Processor>
}

public struct Call<Processor: ProcessorProtocol>: UnaryAllModesInstruction {
    public init(arguments: ArgumentsStorage<Processor>) {
        self.arguments = arguments
    }
    
    public static func compute(input: UInt32, processor: inout Processor) throws {
        // FIXME: Maybe don't use hardcoded code
        try processor.writeRegister(value: input, at: 3)
    }
    
    public static var name: String { "call" }
    
    public static var opcode: UInt8 { 2 }
    
    public var arguments: ArgumentsStorage<Processor>
}

public struct Cmp<Processor: ProcessorProtocol>: BinaryAllModesRM {
    public init(arguments: ArgumentsStorage<Processor>) {
        self.arguments = arguments
    }
    
    public static func compute(input: UInt32, destination: UInt32, processor: inout Processor) throws -> UInt32 {
        _ = try Sub.compute(input: input, destination: destination, processor: &processor)
        return destination
    }
    
    public static var name: String { "cmp" }
    
    public static var opcode: UInt8 { 3 }
        
    public var arguments: ArgumentsStorage<Processor>
}

public struct Div<Processor: ProcessorProtocol>: BinaryAllModesRM {
    public init(arguments: ArgumentsStorage<Processor>) {
        self.arguments = arguments
    }
    
    public static func compute(input: UInt32, destination: UInt32, processor: inout Processor) throws -> UInt32 {
        guard destination != 0 else {
            throw Exception(eventCode: .divisionByZero)
        }
        let result = input / destination
        processor.registers.srFlags.updateZeroNegativeFlags(for: result)
        return result
    }
    
    public static var name: String { "div" }
    
    public static var opcode: UInt8 { 4 }
    
    public var arguments: ArgumentsStorage<Processor>
}

public struct Fas<Processor: ProcessorProtocol>: Instruction {
    
    public func execute(on processor: inout Processor) throws {
        let (lhs, rhs) = arguments.extractAssertingBinaryArgument(lhsAllowedModes: [.direct, .indirect, .indexedIndirect], rhsAllowedModes: .register)
        let value = try rhs.extractFromProcessor(&processor)
        try rhs.modifyProcessor(&processor, with: 1)
        try lhs.modifyProcessor(&processor, with: value)
    }
    
    public static var name: String { "fas" }
    
    public static var opcode: UInt8 { 5 }
    
    // FIXME: Add corresponding DSL inits
    public static var argumentsDescription: ArgumentsDescription {
        .binary([.direct, .indirect, .indexedIndirect], .register)
    }
    
    public init(arguments: ArgumentsStorage<Processor>) {
        self.arguments = arguments
    }
    
    init(direct: UInt32, destination: WritableKeyPath<Processor.RegistersStorage, UInt32>) {
        let code = Processor.registerCode(for: destination)
        self.arguments = .binary(.direct(direct), .register(code))
    }
    
    init(indirect: WritableKeyPath<Processor.RegistersStorage, UInt32>, destination: WritableKeyPath<Processor.RegistersStorage, UInt32>) {
        let indirectCode = Processor.registerCode(for: indirect)
        let destinationCode = Processor.registerCode(for: destination)
        self.arguments = .binary(.indirect(indirectCode), .register(destinationCode))
    }
    
    init(indirect: WritableKeyPath<Processor.RegistersStorage, UInt32>, offset: Int32, destination: WritableKeyPath<Processor.RegistersStorage, UInt32>) {
        let indirectCode = Processor.registerCode(for: indirect)
        let destinationCode = Processor.registerCode(for: destination)
        self.arguments = .binary(.indexedIndirect(indirectCode, offset), .register(destinationCode))
    }
    
    public var arguments: ArgumentsStorage<Processor>
}

// FIXME: Implement in

public struct Jmp<Processor: ProcessorProtocol>: UnaryAllModesInstruction {
    public init(arguments: ArgumentsStorage<Processor>) {
        self.arguments = arguments
    }
    
    public static func compute(input: UInt32, processor: inout Processor) throws {
        processor.registers.pc = input
    }
    
    public static var name: String { "jmp" }
    
    public static var opcode: UInt8 { 6 }
    
    public var arguments: ArgumentsStorage<Processor>
}

public struct Jeq<Processor: ProcessorProtocol>: UnaryAllModesInstruction {
    public init(arguments: ArgumentsStorage<Processor>) {
        self.arguments = arguments
    }
    
    public static func compute(input: UInt32, processor: inout Processor) throws {
        if processor.registers.srFlags.contains(.zero) {
            processor.registers.pc = input
        }
    }
    
    public static var name: String { "jeq" }
    
    public static var opcode: UInt8 { 7 }
    
    public var arguments: ArgumentsStorage<Processor>
}

public struct Jne<Processor: ProcessorProtocol>: UnaryAllModesInstruction {
    public init(arguments: ArgumentsStorage<Processor>) {
        self.arguments = arguments
    }
    
    public static func compute(input: UInt32, processor: inout Processor) throws {
        if !processor.registers.srFlags.contains(.zero) {
            processor.registers.pc = input
        }
    }
    
    public static var name: String { "jne" }
    
    public static var opcode: UInt8 { 8 }
    
    public var arguments: ArgumentsStorage<Processor>
}

public struct Jle<Processor: ProcessorProtocol>: UnaryAllModesInstruction {
    public init(arguments: ArgumentsStorage<Processor>) {
        self.arguments = arguments
    }
    
    public static func compute(input: UInt32, processor: inout Processor) throws {
        if (processor.registers.srFlags.contains(.overflow) != processor.registers.srFlags.contains(.carry)) || processor.registers.srFlags.contains(.zero) {
            processor.registers.pc = input
        }
    }
    
    public static var name: String { "jle" }
    
    public static var opcode: UInt8 { 9 }
    
    public var arguments: ArgumentsStorage<Processor>
}

public struct Jlt<Processor: ProcessorProtocol>: UnaryAllModesInstruction {
    public init(arguments: ArgumentsStorage<Processor>) {
        self.arguments = arguments
    }
    
    public static func compute(input: UInt32, processor: inout Processor) throws {
        if processor.registers.srFlags.contains(.overflow) != processor.registers.srFlags.contains(.carry) {
            processor.registers.pc = input
        }
    }
    
    public static var name: String { "jlt" }
    
    public static var opcode: UInt8 { 10 }
    
    public var arguments: ArgumentsStorage<Processor>
}

public struct Jge<Processor: ProcessorProtocol>: UnaryAllModesInstruction {
    public init(arguments: ArgumentsStorage<Processor>) {
        self.arguments = arguments
    }
    
    public static func compute(input: UInt32, processor: inout Processor) throws {
        if processor.registers.srFlags.contains(.overflow) == processor.registers.srFlags.contains(.carry) {
            processor.registers.pc = input
        }
    }
    
    public static var name: String { "jge" }
    
    public static var opcode: UInt8 { 11 }
    
    public var arguments: ArgumentsStorage<Processor>
}

public struct Jgt<Processor: ProcessorProtocol>: UnaryAllModesInstruction {
    public init(arguments: ArgumentsStorage<Processor>) {
        self.arguments = arguments
    }
    
    public static func compute(input: UInt32, processor: inout Processor) throws {
        if (processor.registers.srFlags.contains(.overflow) == processor.registers.srFlags.contains(.carry)) && processor.registers.srFlags.contains(.zero) {
            processor.registers.pc = input
        }
    }
    
    public static var name: String { "jgt" }
    
    public static var opcode: UInt8 { 12 }
    
    public var arguments: ArgumentsStorage<Processor>
}

public struct Ld<Processor: ProcessorProtocol>: BinaryAllModesRM {
    public init(arguments: ArgumentsStorage<Processor>) {
        self.arguments = arguments
    }
    
    public static func compute(input: UInt32, destination: UInt32, processor: inout Processor) throws -> UInt32 {
        return input
    }
    
    public static var name: String { "ld" }
    
    public static var opcode: UInt8 { 13 }
    
    public var arguments: ArgumentsStorage<Processor>
}

public struct Nop<Processor: ProcessorProtocol>: NullaryInstruction {
    public init(arguments: ArgumentsStorage<Processor>) {
        self.arguments = arguments
    }
    
    public static var name: String { "nop" }
    
    public static var opcode: UInt8 { 14 }
    
    public var arguments: ArgumentsStorage<Processor>
    
    public func execute(on processor: inout Processor) throws {}
}

public struct Not<Processor: ProcessorProtocol>: UnaryRegisterModificator {
    public init(arguments: ArgumentsStorage<Processor>) {
        self.arguments = arguments
    }
    
    static func compute(modified: UInt32, processor: inout Processor) throws -> UInt32 {
        let result = ~modified
        processor.registers.srFlags.updateZeroNegativeFlags(for: result)
        return result
    }
    
    public static var name: String { "not" }
    public static var opcode: UInt8 { 15 }
    
    public var arguments: ArgumentsStorage<Processor>
}

public struct Or<Processor: ProcessorProtocol>: BinaryAllModesRM {
    public init(arguments: ArgumentsStorage<Processor>) {
        self.arguments = arguments
    }
    
    public static func compute(input: UInt32, destination: UInt32, processor: inout Processor) throws -> UInt32 {
        let result = input | destination
        processor.registers.srFlags.updateZeroNegativeFlags(for: result)
        return result
    }
    
    public static var name: String { "or" }
    
    public static var opcode: UInt8 { 16 }
    
    public var arguments: ArgumentsStorage<Processor>
}

// FIXME: Implement out

public struct Pop<Processor: ProcessorProtocol>: UnaryRegisterModificator {
    public init(arguments: ArgumentsStorage<Processor>) {
        self.arguments = arguments
    }
    
    static func compute(modified: UInt32, processor: inout Processor) throws -> UInt32 {
        let resultValue = try processor.readMemory(at: processor.registers.sp)
        processor.registers.sp += 1
        return resultValue
    }
    
    
    
    public static var name: String { "pop" }
    
    public static var opcode: UInt8 { 18 }
    
    public static var argumentsDescription: ArgumentsDescription { .unary(.register) }
    
    public var arguments: ArgumentsStorage<Processor>
}

public struct Push<Processor: ProcessorProtocol>: ImmediateUnaryInstruction, RegisterUnaryInstruction {
    public init(arguments: ArgumentsStorage<Processor>) {
        self.arguments = arguments
    }
    
    public static func compute(input: UInt32, processor: inout Processor) throws {
        try processor.writeMemory(value: input, at: processor.registers.sp)
        processor.registers.sp -= 1
    }
    
    public static var name: String { "push" }
    
    public static var opcode: UInt8 { 19 }
    
    public static var argumentsDescription: ArgumentsDescription { .unary([.immediate, .register]) }
    
    public var arguments: ArgumentsStorage<Processor>
}

public struct Reset<Processor: ProcessorProtocol>: NullaryInstruction {
    public init(arguments: ArgumentsStorage<Processor>) {
        self.arguments = arguments
    }
    
    public static var name: String { "reset" }
    public static var opcode: UInt8 { 20 }
    
    public var arguments: ArgumentsStorage<Processor>
    
    public func execute(on processor: inout Processor) throws {
        processor = .makeAtDefaultState()
    }
}

public struct Rti<Processor: ProcessorProtocol>: NullaryInstruction {
    public init(arguments: ArgumentsStorage<Processor>) {
        self.arguments = arguments
    }
    
    public static var name: String { "rti" }
    public static var opcode: UInt8 { 21 }
    
    public var arguments: ArgumentsStorage<Processor>
    
    public func execute(on processor: inout Processor) throws {
        processor.registers.pc = try processor.readMemory(at: 100)
        processor.registers.sr = try processor.readMemory(at: 101)
    }
    
    public static var isPrivileged: Bool { true }
}

public struct Rtn<Processor: ProcessorProtocol>: NullaryInstruction {
    public init(arguments: ArgumentsStorage<Processor>) {
        self.arguments = arguments
    }
    
    public static var name: String { "rtn" }
    public static var opcode: UInt8 { 22 }
    
    public var arguments: ArgumentsStorage<Processor>
    
    public func execute(on processor: inout Processor) throws {
        let destination = try processor.readMemory(at: processor.registers.sp)
        processor.registers.pc = destination
    }
}

public struct Shl<Processor: ProcessorProtocol>: BinaryAllModesRM {
    public init(arguments: ArgumentsStorage<Processor>) {
        self.arguments = arguments
    }
    
    public static func compute(input: UInt32, destination: UInt32, processor: inout Processor) throws -> UInt32 {
        let result = destination << input
        processor.registers.srFlags.updateZeroNegativeFlags(for: result)
        return result
    }
    
    public static var name: String { "shl" }
    
    public static var opcode: UInt8 { 23 }
    
    public var arguments: ArgumentsStorage<Processor>
}

public struct Shr<Processor: ProcessorProtocol>: BinaryAllModesRM {
    public init(arguments: ArgumentsStorage<Processor>) {
        self.arguments = arguments
    }
    
    public static func compute(input: UInt32, destination: UInt32, processor: inout Processor) throws -> UInt32 {
        let result = destination >> input
        processor.registers.srFlags.updateZeroNegativeFlags(for: result)
        return result
    }
    
    public static var name: String { "shr" }
    
    public static var opcode: UInt8 { 24 }
    
    public var arguments: ArgumentsStorage<Processor>
}

public struct St<Processor: ProcessorProtocol>: Instruction {
    public init(arguments: ArgumentsStorage<Processor>) {
        self.arguments = arguments
    }
    
    public static var argumentsDescription: ArgumentsDescription {
        .binary(.register, [.direct, .indirect, .indexedIndirect])
    }
    
    public func execute(on processor: inout Processor) throws {
        let (sourceRegister, destination) = arguments.extractAssertingBinaryArgument()
        let value = try processor.readData(at: sourceRegister)
        try processor.writeData(at: destination, value: value)
    }
    
    public static var name: String { "st" }
    
    public static var opcode: UInt8 { 25 }
    
    public var arguments: ArgumentsStorage<Processor>
}


public struct Sub<Processor: ProcessorProtocol>: BinaryAllModesRM {
    public init(arguments: ArgumentsStorage<Processor>) {
        self.arguments = arguments
    }
    
    public static func compute(input: UInt32, destination: UInt32, processor: inout Processor) throws -> UInt32 {
        let msb: UInt32 = ~(UInt32.max >> 1)
        let result = destination.subtractingReportingOverflow(input)
        let resultValue = result.partialValue
        
        // Set the carry flag appropriately
        if result.overflow {
            processor.registers.srFlags.insert(.carry)
        } else {
            processor.registers.srFlags.remove(.carry)
        }
        
        // Set the overflow flag appropriately
        if ((input & msb) == (destination & msb)) && ((result.partialValue & msb) != (input & msb)) {
            processor.registers.srFlags.insert(.overflow)
        } else {
            processor.registers.srFlags.remove(.overflow)
        }
        
        processor.registers.srFlags.updateZeroNegativeFlags(for: resultValue)
        
        return resultValue
    }
    
    public static var name: String { "sub" }
    
    public static var opcode: UInt8 { 26 }
    
    public var arguments: ArgumentsStorage<Processor>
}

public struct Swap<Processor: ProcessorProtocol>: Instruction {
    public init(arguments: ArgumentsStorage<Processor>) {
        self.arguments = arguments
    }
    
    // FIXME: Add corresponding DSL inits
    public static var argumentsDescription: ArgumentsDescription {
        .binary([.register, .direct, .indirect, .indexedIndirect], [.register])
    }
    
    public func execute(on processor: inout Processor) throws {
        let (lhs, rhs) = arguments.extractAssertingBinaryArgument()
        let lhsValue = try processor.readData(at: lhs)
        let rhsValue = try processor.readData(at: rhs)
        // FIXME: What if we throw on the second line
        // Is it ok to have the processor in this unclear state
        // with half the instruction executed?
        try processor.writeData(at: lhs, value: rhsValue)
        try processor.writeData(at: rhs, value: lhsValue)
    }
    
    public static var name: String { "swap" }
    
    public static var opcode: UInt8 { 27 }
    
    public var arguments: ArgumentsStorage<Processor>
}

public struct Trap<Processor: ProcessorProtocol>: NullaryInstruction {
    public init(arguments: ArgumentsStorage<Processor>) {
        self.arguments = arguments
    }
    
    public static var name: String { "trap" }
    public static var opcode: UInt8 { 28 }
    
    public var arguments: ArgumentsStorage<Processor>
    
    public func execute(on processor: inout Processor) throws {
        throw Exception(eventCode: .trap)
    }
}

public struct Xor<Processor: ProcessorProtocol>: BinaryAllModesRM {
    public init(arguments: ArgumentsStorage<Processor>) {
        self.arguments = arguments
    }
    
    public static func compute(input: UInt32, destination: UInt32, processor: inout Processor) throws -> UInt32 {
        let result = input ^ destination
        processor.registers.srFlags.updateZeroNegativeFlags(for: result)
        return result
    }
    
    public static var name: String { "xor" }
    
    public static var opcode: UInt8 { 29 }
    
    public var arguments: ArgumentsStorage<Processor>
}

