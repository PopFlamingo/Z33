struct StandardVariation: ProcessorProtocol {
    static func additionalRegisterKeyPath(for registerName: String) -> RegisterKeyPath? {
        return nil
    }
    
    var additionalReadReservedRegisters: Set<RegisterKeyPath>
    
    var additionalWriteReservedRegisters: Set<RegisterKeyPath>
    
    var registers: RegistersStorage
    var memory = Memory(size: 8192)
    
    mutating func readMemory(at address: Int32) throws -> Int32 {
        guard address >= 0 && address < maxMemoryAddress else {
            throw EventCode.invalidMemoryAccess
        }
        return memory.storage[Int(address)]
    }
    
    mutating func writeMemory(value: Int32, at address: Int32) throws {
        guard address >= 0 && address < maxMemoryAddress else {
            throw EventCode.invalidMemoryAccess
        }
        
        memory.storage[Int(address)] = value
    }
    
    var maxMemoryAddress: Int32 {
        return Int32(memory.size)
    }
    
    struct RegistersStorage: RegistersStorageProtocol {
        var a: Int32
        
        var b: Int32
        
        var pc: Int32
        
        var sp: Int32
        
        var sr: Int32
    }
}
