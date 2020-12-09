// Default implementations
extension ProcessorProtocol {
    
    /// Executes the instruction placed at the address pointed by the program counter register
    ///
    /// This function will throw if an exception is raised while executing the current instruction
    @inline(__always)
    public mutating func executeCurrentInstruction(_ cache: [AnyInstruction<Self>?]) throws {
        let pc = self.registers.pc
        
        do {
            if let instruction = cache[Int(pc)] {
                let pcBefore = self.registers.pc
                try instruction.execute(on: &self)
                if self.registers.pc == pcBefore {
                    self.registers.pc += 2
                }
            } else {
                // FIXME: Should probably throw something else
                throw Exception(eventCode: .invalidInstruction)
            }
        } catch {
            if let exception = error as? Exception {
                try! self.writeMemory(value: self.registers.pc, at: 100)
                try! self.writeMemory(value: self.registers.sr, at: 101)
                try! self.writeMemory(value: UInt32(exception.eventCode.rawValue), at: 102)
                self.registers.srFlags.insert(.supervisor)
                self.registers.pc = 200
            } else {
                fatalError("Unexpected error at \(#fileID):\(#function) : \(error)")
            }
        }
    }
    
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
 
    /// Translate a register name string to a the corresponding `WritableKeyPath`
    ///
    /// Use this method for dynamic member lookup based on register string names.
    static func registerKeyPath(for registerName: String) -> RegisterKeyPath? {
        return Self.registersDescription.first(where: { $0.name == registerName })?.keyPath
    }
    
    /// Translate a register key path to a register name
    static func registerName(for registerKeyPath: RegisterKeyPath) -> String {
        return Self.registersDescription.first(where: { $0.keyPath == registerKeyPath })!.name
    }
    
    /// Translate a register code to a register name
    static func registerName(for registerCode: UInt32) -> String {
        return Self.registersDescription.first(where: { $0.code == registerCode })!.name
    }
    
    /// Translate a register key path to a register code
    static func registerCode(for registerKeyPath: RegisterKeyPath) -> UInt32 {
        return Self.registersDescription.first(where: { $0.keyPath == registerKeyPath })!.code
    }
    
    /// Translate a register code to a register key path
    static func registerKeyPath(for registerCode: UInt32) -> RegisterKeyPath? {
        return Self.registersDescription.first(where: { $0.code == registerCode })?.keyPath
    }
    
    static func registerMemoryOffset(for registerCode: UInt32) -> UInt32? {
        return Self.registersDescription.first(where: { $0.code == registerCode })?.memoryOffset
    }
    
    /*
    mutating func readRegister(at registerKeyPath: RegisterKeyPath) throws -> UInt32 {
        /*
        guard self.registers.srFlags.contains(.supervisor) /* || !self.readReservedRegisters.contains(registerKeyPath) */ else {
            throw EventCode.privilegedInstruction
        }
        */
        return self.registers[keyPath: registerKeyPath]
    }
    
    mutating func writeRegister(value: UInt32, at registerKeyPath: RegisterKeyPath) throws {
        /*
        guard self.registers.srFlags.contains(.supervisor) /* || !self.writeReservedRegisters.contains(registerKeyPath) */ else {
            throw EventCode.privilegedInstruction
        }
        */
        self.registers[keyPath: registerKeyPath] = value
    }
 */
}

extension ProcessorProtocol {
    public var description: String {
        """
        Registers:
        \(Self.registersDescription.map({ "\($0.name) = \(self.registers[keyPath: $0.keyPath])" }).joined(separator: "\n"))
        """
    }
}

extension RegistersStorageProtocol {
    public var srFlags: SRValue {
        get {
            return SRValue(rawValue: self.sr)
        }
        set {
            self.sr = newValue.rawValue
        }
    }
}
