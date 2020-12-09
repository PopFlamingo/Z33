import Foundation

public class Runner<Processor: ProcessorProtocol> {
    public init(initialState: Processor = .makeAtDefaultState()) {
        self.processor = initialState
    }
    
    var processor: Processor
    private var insertionAddress: UInt32 = 0
    
    
    public func code(at address: UInt32? = nil, @AssemblyBuilder<Processor> _ codeBuilder: ()->[AnyInstruction<Processor>]) -> Runner<Processor> {
        let instructions = codeBuilder()
        
        if let address = address {
            insertionAddress = address
        }
        
        for instruction in instructions {
            guard let binaryValue = instruction.encodeToBinary() else {
                fatalError("Instruction cannot be encoded")
            }
            try! processor.writeMemory(value: UInt32(truncatingIfNeeded: binaryValue >> 32),
                                       at: insertionAddress)
            insertionAddress += 1
            try! processor.writeMemory(value: UInt32(truncatingIfNeeded: binaryValue),
                                       at: insertionAddress)
            insertionAddress += 1
        }
                
        return self
    }
    
    public func rom(@AssemblyBuilder<Processor> _ codeBuilder: ()->[AnyInstruction<Processor>]) -> Runner<Processor> {
        return self.code(at: 0, codeBuilder)
    }
    
    public func interruptHandler(@AssemblyBuilder<Processor> _ codeBuilder: ()->[AnyInstruction<Processor>]) -> Runner<Processor> {
        return self.code(at: 200, codeBuilder)
    }
    
    public func run() {
        let cache: [AnyInstruction<Processor>?] = (0..<processor.physicalMemorySize).map { _ in
            let pc = processor.registers.pc
            let binaryInstructionMSBs = (try? processor.readMemory(at: pc)) ?? 0
            let binaryInstructionLSBs = (try? processor.readMemory(at: pc + 1)) ?? 0
            let binaryInstruction = UInt64(binaryInstructionMSBs) << 32 | UInt64(binaryInstructionLSBs)
            processor.registers.pc += 1
            if let instruction = Processor.instructionsMap.decodeInstruction(from: binaryInstruction) {
                return instruction
            } else {
                return nil
            }
        }
        
        var context = ExecutionContext(cache: cache)

        processor.registers.pc = 0
        
        var result = ExecutionStepResult.continue
        while case .continue = result {
            result = processor.executeCurrentInstruction(context: &context)
        }
    }
}

@_functionBuilder
public struct AssemblyBuilder<Processor: ProcessorProtocol> {
    @inline(__always)
    public static func buildExpression<I: Instruction>(_ expression: I) -> AnyInstruction<Processor> where I.Processor == Processor {
          return AnyInstruction(expression)
    }
    
    @inline(__always)
    public static func buildBlock(_ children: AnyInstruction<Processor>...) -> [AnyInstruction<Processor>] {
            return children
    }
}
