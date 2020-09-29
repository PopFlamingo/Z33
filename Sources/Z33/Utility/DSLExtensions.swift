protocol BinaryAllModesRM : BinaryImmediateRM, BinaryRegisterRM, BinaryDirectRM, BinaryIndirectRM,  BinaryIndexedIndirectRM {}

extension BinaryAllModesRM {
    static var argumentsDescription: ArgumentsDescription {
        .binary(.all, .register)
    }
}

protocol BinaryMemoryModesRM: BinaryDirectRM, BinaryIndirectRM, BinaryIndexedIndirectRM {}

extension BinaryMemoryModesRM {
    static var argumentsDescription: ArgumentsDescription {
        .binary([.direct, .indirect, .indexedIndirect], .register)
    }
}

protocol UnaryRM: RegisterModificator {
    init(_ destination: WritableKeyPath<Processor.RegistersStorage, Int32>)
}

extension UnaryRM {
    init(_ destination: WritableKeyPath<Processor.RegistersStorage, Int32>) {
        self.init(arguments: .unary(.register(destination)))
    }
}

protocol BinaryImmediateRM: RegisterModificator {
    init(immediate: Int32, destination: WritableKeyPath<Processor.RegistersStorage, Int32>)
}

extension BinaryImmediateRM {
    init(immediate: Int32, destination: WritableKeyPath<Processor.RegistersStorage, Int32>) {
        self.init(arguments: .binary(.immediate(immediate), .register(destination)))
    }
}

protocol BinaryRegisterRM: RegisterModificator {
    init(register: WritableKeyPath<Processor.RegistersStorage, Int32>, destination: WritableKeyPath<Processor.RegistersStorage, Int32>)
}

extension BinaryRegisterRM {
    init(register: WritableKeyPath<Processor.RegistersStorage, Int32>, destination: WritableKeyPath<Processor.RegistersStorage, Int32>) {
        self.init(arguments: .binary(.register(register), .register(destination)))
    }
}

protocol BinaryDirectRM: RegisterModificator {
    init(direct: Int32, destination: WritableKeyPath<Processor.RegistersStorage, Int32>)
}

extension BinaryDirectRM {
    init(direct: Int32, destination: WritableKeyPath<Processor.RegistersStorage, Int32>) {
        self.init(arguments: .binary(.direct(direct), .register(destination)))
    }
}

protocol BinaryIndirectRM: RegisterModificator {
    init(indirect: WritableKeyPath<Processor.RegistersStorage, Int32>, destination: WritableKeyPath<Processor.RegistersStorage, Int32>)
}

extension BinaryIndirectRM {
    init(indirect: WritableKeyPath<Processor.RegistersStorage, Int32>, destination: WritableKeyPath<Processor.RegistersStorage, Int32>) {
        self.init(arguments: .binary(.indirect(indirect), .register(destination)))
    }
}

protocol BinaryIndexedIndirectRM: RegisterModificator {
    init(indirect: WritableKeyPath<Processor.RegistersStorage, Int32>, offset: Int32, destination: WritableKeyPath<Processor.RegistersStorage, Int32>)
}

extension BinaryIndexedIndirectRM {
    init(indirect: WritableKeyPath<Processor.RegistersStorage, Int32>, offset: Int32, destination: WritableKeyPath<Processor.RegistersStorage, Int32>) {
        self.init(arguments: .binary(.indexedIndirect(indirect, offset), .register(destination)))
    }
}
