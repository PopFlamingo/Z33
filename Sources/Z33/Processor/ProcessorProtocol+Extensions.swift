// Default implementations
extension ProcessorProtocol {
    
    /// Translate a register name string to a the corresponding `WritableKeyPath`
    ///
    /// Use this method for dynamic member lookup based on register string names.
    static func registerKeyPath(for registerName: String) -> RegisterKeyPath? {
        return Self._baseRegisterKeyPath(for: registerName) ?? Self.additionalRegisterKeyPath(for: registerName)
    }
    
    static func _baseRegisterKeyPath(for registerName: String) -> RegisterKeyPath? {
        switch registerName {
        case "a":
            return \.a
        case "b":
            return \.b
        case "pc":
            return \.pc
        case "sp":
            return \.sp
        case "sr":
            return \.sr
        default:
            return nil
        }
    }
    
    mutating func readRegister(at registerKeyPath: RegisterKeyPath) throws -> Int32 {
        guard self.registers.srFlags.contains(.supervisor) || !self.readReservedRegisters.contains(registerKeyPath) else {
            throw EventCode.privilegedInstruction
        }
        
        return self.registers[keyPath: registerKeyPath]
    }
    
    mutating func writeRegister(value: Int32, at registerKeyPath: RegisterKeyPath) throws {
        guard self.registers.srFlags.contains(.supervisor) || !self.writeReservedRegisters.contains(registerKeyPath) else {
            throw EventCode.privilegedInstruction
        }
        
        self.registers[keyPath: registerKeyPath] = value
    }
    
    var _baseReadReservedRegisters: Set<RegisterKeyPath> {
        return []
    }
    
    var _baseWriteReservedRegisters: Set<RegisterKeyPath> {
        return [\RegistersStorage.sr]
    }
    
    /// The set of registers that can only be read in supervisor mode
    var readReservedRegisters: Set<RegisterKeyPath> {
        return _baseReadReservedRegisters.union(additionalReadReservedRegisters)
    }
    
    /// The set of registers that can only be written in supervisor mode
    var writeReservedRegisters: Set<RegisterKeyPath> {
        return _baseWriteReservedRegisters.union(additionalWriteReservedRegisters)
    }
}

extension RegistersStorageProtocol {
    var srFlags: SRValue {
        get {
            return SRValue(rawValue: self.sr)
        }
        set {
            self.sr = newValue.rawValue
        }
    }
}
