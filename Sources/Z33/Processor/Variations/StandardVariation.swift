
public struct StandardVariation: ProcessorProtocol {
    static var additionalRegistersDescription: [RegisterDescription<RegistersStorage>] {
        return []
    }
    
    public static func makeAtDefaultState() -> StandardVariation {
        .init(registers: .init(a: 0, b: 0, pc: 0, sp: 0, sr: 0))
    }
    
    public static var instructionsMap: InstructionsMap<StandardVariation> = .makeDefault(for: StandardVariation.self)
    

    
    public var registers: RegistersStorage
    var memory = Memory(size: 10_000)
    
    @inline(__always)
    mutating public func readMemory(at address: UInt32) throws -> UInt32 {
        guard address >= 0 && address < physicalMemorySize else {
            throw EventCode.invalidMemoryAccess
        }
        return memory.storage[Int(address)]
    }
    
    @inline(__always)
    mutating public func writeMemory(value: UInt32, at address: UInt32) throws {
        guard address >= 0 && address < physicalMemorySize else {
            throw EventCode.invalidMemoryAccess
        }
        
        memory.storage[Int(address)] = value
    }
    
    public func physicalAddress(from virtual: UInt32) -> UInt32 {
        // There is no support for virtual memory on the standard variation
        return virtual
    }
    
    
    let readReservedRegisters: [UInt32] = [134, 293, 200, 200]
    let writeReservedRegisters: [UInt32] = [123, 125, 100, 3928]
    
    @inline(__always)
    mutating public func readRegister(at registerCode: UInt32) throws -> UInt32 {
        guard self.registers.srFlags.contains(.supervisor) ||  !self.readReservedRegisters.contains(registerCode) else {
            throw EventCode.privilegedInstruction
        }
        
        return withUnsafeBytes(of: &self) { buffer in
            buffer.load(fromByteOffset: Int(registerCode), as: UInt32.self)
        }
    }
    
    @inline(__always)
    mutating public func writeRegister(value: UInt32, at registerCode: UInt32) throws {
        guard self.registers.srFlags.contains(.supervisor) || !self.writeReservedRegisters.contains(registerCode) else {
            throw EventCode.privilegedInstruction
        }
 
        
        withUnsafeMutableBytes(of: &self) { buffer in
            buffer.storeBytes(of: value, toByteOffset: Int(registerCode), as: UInt32.self)
        }
    }
    
    public var physicalMemorySize: UInt32 {
        return UInt32(memory.size)
    }
    
    public struct RegistersStorage: RegistersStorageProtocol {
        public var a: UInt32
        
        public var b: UInt32
        
        public var pc: UInt32
        
        public var sp: UInt32
        
        public var sr: UInt32
    }
    
    
    public static var registersDescription: [RegisterDescription<RegistersStorage>] {
        return staticRegistersDescription
    }
    
    @inline(__always)
    public mutating func readData(at argument: Argument<Self>) throws -> UInt32 {
        switch argument {
        case .immediate(let value):
            return value
            
        case .register(let register):
            return try self.readRegister(at: register)
            
        case .direct(let address):
            return try self.readMemory(at: address)
            
        case .indirect(let addressRegister):
            let address = try self.readRegister(at: addressRegister)
            return try self.readMemory(at: address)
            
        case .indexedIndirect(let addressRegister, let offset):
            let computedAddress = try Int64(self.readRegister(at: addressRegister)) + Int64(offset)
            guard let address = UInt32(exactly: computedAddress) else {
                throw Exception(eventCode: .invalidMemoryAccess)
            }
            return try self.readMemory(at: address)
        }
    }
    
    @inline(__always)
    public mutating func writeData(at argument: Argument<Self>, value: UInt32) throws {
        switch argument {
        case .immediate:
            fatalError("Using an incorrect argument for the given context")
            
        case .register(let register):
            try self.writeRegister(value: value, at: register)
            
        case .direct(let address):
            try self.writeMemory(value: address, at: value)
            
        case .indirect(let addressRegister):
            let address = try self.readRegister(at: addressRegister)
            try self.writeMemory(value: address, at: value)
            
        case .indexedIndirect(let addressRegister, let offset):
            let computedAddress = try Int64(self.readRegister(at: addressRegister)) + Int64(offset)
            guard let address = UInt32(exactly: computedAddress) else {
                throw Exception(eventCode: .invalidMemoryAccess)
            }
            try self.writeMemory(value: address, at: value)
        }
    }
}


let b = MemoryLayout<StandardVariation>.offset(of: \StandardVariation.registers)!

typealias RS = StandardVariation.RegistersStorage


let staticRegistersDescription: [RegisterDescription<RS>]  =
    [
        RegisterDescription(keyPath: \.a,
                            name: "a",
                            code: 1,
                            memoryOffset: b + MemoryLayout<RS>.offset(of: \RS.a)!),
        
        RegisterDescription(keyPath: \.b,
                            name: "b",
                            code: 2,
                            memoryOffset: b + MemoryLayout<RS>.offset(of: \RS.b)!),
        
        RegisterDescription(keyPath: \.pc,
                            name: "pc",
                            code: 3,
                            memoryOffset: b + MemoryLayout<RS>.offset(of: \RS.pc)!),
        
        RegisterDescription(keyPath: \.sp,
                            name: "sp",
                            code: 4,
                            memoryOffset: b + MemoryLayout<RS>.offset(of: \RS.sp)!),
        
        RegisterDescription(keyPath: \.sr,
                            name: "sr",
                            code: 5,
                            memoryOffset: b + MemoryLayout<RS>.offset(of: \RS.sr)!,
                            protectionStatus: .write)
    ]

