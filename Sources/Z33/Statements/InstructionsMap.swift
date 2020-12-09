public struct InstructionsMap<Processor: ProcessorProtocol> {
    
    static func makeDefault(for processor: Processor.Type) -> InstructionsMap<Processor> {
        var base = InstructionsMap<Processor>()
        
        // Add all supported instructions here
        base.registerInstruction(Add.self)
        base.registerInstruction(And.self)
        base.registerInstruction(Call.self)
        base.registerInstruction(Cmp.self)
        base.registerInstruction(Div.self)
        base.registerInstruction(Fas.self)
        base.registerInstruction(Jmp.self)
        base.registerInstruction(Jeq.self)
        base.registerInstruction(Jne.self)
        base.registerInstruction(Jle.self)
        base.registerInstruction(Jlt.self)
        base.registerInstruction(Jgt.self)
        base.registerInstruction(Ld.self)
        base.registerInstruction(Nop.self)
        base.registerInstruction(Not.self)
        base.registerInstruction(Or.self)
        base.registerInstruction(Pop.self)
        base.registerInstruction(Push.self)
        base.registerInstruction(Reset.self)
        base.registerInstruction(Rti.self)
        base.registerInstruction(Rtn.self)
        base.registerInstruction(Shl.self)
        base.registerInstruction(Shr.self)
        base.registerInstruction(St.self)
        base.registerInstruction(Sub.self)
        base.registerInstruction(Swap.self)
        base.registerInstruction(Trap.self)
        base.registerInstruction(Xor.self)
        
        return base
    }
    
    
    func decodeInstruction(from binaryPattern: UInt64) -> AnyInstruction<Processor>? {
        let opcode = UInt8(binaryPattern >> 56)
        return self.binaryInstructionDecoders[opcode]?(binaryPattern)
    }
    
    private var binaryInstructionDecoders: [UInt8:(UInt64) -> (AnyInstruction<Processor>?)] = [:]
    private var instructionNameParsers: [String: ((Substring) throws -> (ParseResult<AnyInstruction<Processor>>?))] = [:]
    
    private mutating func registerInstruction<T: Instruction>(_ instruction: T.Type) where T.Processor == Processor {
        // Register on binaryToInstructionMakers
        precondition(!binaryInstructionDecoders.keys.contains(instruction.opcode), "Registering an instruction twice with the same opcode")
        self.binaryInstructionDecoders[instruction.opcode] = { bitPattern in
            if let decoded = instruction.decodeFromBinary(bitPattern) {
                return AnyInstruction(decoded)
            } else {
                return nil
            }
        }
        
        precondition(!instructionNameParsers.keys.contains(instruction.name), "Registering an instruction twice with the same name")
        self.instructionNameParsers[instruction.name] = { substring in
            if let parsed = try instruction.parse(from: substring) {
                return ParseResult(value: AnyInstruction(parsed.value), advancedIndex: parsed.advancedIndex)
            } else {
                return nil
            }
        }
    }
}

public class AnyInstruction<Processor: ProcessorProtocol> {
    
    @inline(__always)
    public init<T: Instruction>(_ instruction: T) where T.Processor == Processor {
        self._execute = { processor in
            try instruction.execute(on: &processor)
        }
        
        self._encodeToBinary = {
            return instruction.encodeToBinary()
        }
    }
    
    private let _execute: (inout Processor) throws -> ()
    private let _encodeToBinary: ()->UInt64?
    
    @inline(__always)
    public func execute(on processor: inout Processor) throws {
        try _execute(&processor)
    }
    
    @inline(__always)
    public func encodeToBinary() -> UInt64? {
        return _encodeToBinary()
    }
}
