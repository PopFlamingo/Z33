public protocol UnaryAllModesInstruction: ImmediateUnaryInstruction, RegisterUnaryInstruction, DirectUnaryInstruction, IndirectUnaryInstruction, IndexedIndirectUnaryInstruction {
}

extension UnaryAllModesInstruction {
    public static var argumentsDescription: ArgumentsDescription {
        .unary(.all)
    }
}

public protocol ImmediateUnaryInstruction: UnaryInstruction {
    init(immediate: UInt32)
}

extension ImmediateUnaryInstruction {
    public init(immediate: UInt32) {
        self.init(arguments: .unary(.immediate(immediate)))
    }
}

public protocol RegisterUnaryInstruction: UnaryInstruction {
    init(register: WritableKeyPath<Processor.RegistersStorage, UInt32>)
}

extension RegisterUnaryInstruction {
    public init(register: WritableKeyPath<Processor.RegistersStorage, UInt32>) {
        self.init(arguments: .unary(.register(Processor.registerCode(for: register))))
    }
}

public protocol DirectUnaryInstruction: UnaryInstruction {
    init(direct: UInt32)
}

extension DirectUnaryInstruction {
    public init(direct: UInt32) {
        self.init(arguments: .unary(.direct(direct)))
    }
}

public protocol IndirectUnaryInstruction: UnaryInstruction {
    init(indirect: WritableKeyPath<Processor.RegistersStorage, UInt32>)
}

extension IndirectUnaryInstruction {
    public init(indirect: WritableKeyPath<Processor.RegistersStorage, UInt32>) {
        self.init(arguments: .unary(.indirect(Processor.registerCode(for: indirect))))
    }
}

public protocol IndexedIndirectUnaryInstruction: UnaryInstruction {
    init(indirect: WritableKeyPath<Processor.RegistersStorage, UInt32>, offset: Int32)
}

extension IndexedIndirectUnaryInstruction {
    public init(indirect: WritableKeyPath<Processor.RegistersStorage, UInt32>, offset: Int32) {
        self.init(arguments: .unary(.indexedIndirect(Processor.registerCode(for: indirect), offset)))
    }
}

public protocol BinaryAllModesRM : BinaryImmediateRM, BinaryRegisterRM, BinaryDirectRM, BinaryIndirectRM,  BinaryIndexedIndirectRM {}

extension BinaryAllModesRM {
    public static var argumentsDescription: ArgumentsDescription {
        .binary(.all, .register)
    }
}

public protocol BinaryMemoryModesRM: BinaryDirectRM, BinaryIndirectRM, BinaryIndexedIndirectRM {}

extension BinaryMemoryModesRM {
    static var argumentsDescription: ArgumentsDescription {
        .binary([.direct, .indirect, .indexedIndirect], .register)
    }
}

extension UnaryRegisterModificator {
    public init(_ destination: WritableKeyPath<Processor.RegistersStorage, UInt32>) {
        self.init(arguments: .unary(.register(Processor.registerCode(for: destination))))
    }
}

public protocol BinaryImmediateRM: BinaryRegisterModificator {
    init(immediate: UInt32, destination: WritableKeyPath<Processor.RegistersStorage, UInt32>)
}

extension BinaryImmediateRM {
    public init(immediate: UInt32, destination: WritableKeyPath<Processor.RegistersStorage, UInt32>) {
        self.init(arguments: .binary(.immediate(immediate), .register(Processor.registerCode(for: destination))))
    }
}

public protocol BinaryRegisterRM: BinaryRegisterModificator {
    init(register: WritableKeyPath<Processor.RegistersStorage, UInt32>, destination: WritableKeyPath<Processor.RegistersStorage, UInt32>)
}

extension BinaryRegisterRM {
    public init(register: WritableKeyPath<Processor.RegistersStorage, UInt32>, destination: WritableKeyPath<Processor.RegistersStorage, UInt32>) {
        self.init(arguments: .binary(.register(Processor.registerCode(for: register)), .register(Processor.registerCode(for: register))))
    }
}

public protocol BinaryDirectRM: BinaryRegisterModificator {
    init(direct: UInt32, destination: WritableKeyPath<Processor.RegistersStorage, UInt32>)
}

extension BinaryDirectRM {
    public init(direct: UInt32, destination: WritableKeyPath<Processor.RegistersStorage, UInt32>) {
        self.init(arguments: .binary(.direct(direct), .register(Processor.registerCode(for: destination))))
    }
}

public protocol BinaryIndirectRM: BinaryRegisterModificator {
    init(indirect: WritableKeyPath<Processor.RegistersStorage, UInt32>, destination: WritableKeyPath<Processor.RegistersStorage, UInt32>)
}

extension BinaryIndirectRM {
    public init(indirect: WritableKeyPath<Processor.RegistersStorage, UInt32>, destination: WritableKeyPath<Processor.RegistersStorage, UInt32>) {
        self.init(arguments: .binary(.indirect(Processor.registerCode(for: indirect)), .register(Processor.registerCode(for: destination))))
    }
}

public protocol BinaryIndexedIndirectRM: BinaryRegisterModificator {
    init(indirect: WritableKeyPath<Processor.RegistersStorage, UInt32>, offset: Int32, destination: WritableKeyPath<Processor.RegistersStorage, UInt32>)
}

extension BinaryIndexedIndirectRM {
    public init(indirect: WritableKeyPath<Processor.RegistersStorage, UInt32>, offset: Int32, destination: WritableKeyPath<Processor.RegistersStorage, UInt32>) {
        self.init(arguments: .binary(.indexedIndirect(Processor.registerCode(for: indirect), offset), .register(Processor.registerCode(for: destination))))
    }
}
