
@_functionBuilder
struct ProgramBuilder<Arch: ProcessorProtocol> {
    
    static func buildBlock(_ expression: Erased...) -> Any {
        return expression
    }
    
    static func buildExpression<T: Instruction>(_ expression: T) -> Erased where T.Processor == Arch {
        return Erased()
    }
}

struct Erased {}
