/// A protocol to which all architecture variations should conform.
///
/// This protocol guarantees the presence of common registers as well as the
/// presence of memory I/O operations
public protocol ProcessorProtocol: CustomStringConvertible {
    /// The type that stores the registers for this processor
    ///
    /// This type conforms to `RegistersStorageProtocol` which guarantees the presence
    /// of a set of basic registers common to all Z33 variations.
    /// It is also used as a destination for the registers key paths, which enables to make use
    /// of autocompletion and type safety for accessing the registers
    associatedtype RegistersStorage: RegistersStorageProtocol
    
    /// A  `WritableKeyPath` to an integer property in `RegistersStorage`
    typealias RegisterKeyPath = WritableKeyPath<RegistersStorage, UInt32>
    
    // MARK: - Initializer
    static func makeAtDefaultState() -> Self
    
    // MARK: - Registers
    
    /// A struct that stores all registers for the processor
    ///
    /// - Seealso: `RegistersStorage`
    var registers: RegistersStorage { get set }

    /// Registers description
    ///
    /// Associates additional registers key paths with their names and code which is then used for translation of names
    /// and opcodes from and to key paths
    static var registersDescription: [RegisterDescription<RegistersStorage>] { get }
    
    mutating func readRegister(at registerKeyPath: UInt32) throws -> UInt32
    mutating func writeRegister(value: UInt32, at registerKeyPath: UInt32) throws
    
    // MARK: - Instructions map
    static var instructionsMap: InstructionsMap<Self> { get }
    
    // MARK: - Memory I/O
    
    // Memory I/O operations are a variation agnostic representation
    // of the memory operations : adress translation is handled transparently
    // by the variation, instructions can be written as if they were dealing
    // with the standard Z33 processor
    
    mutating func readMemory(at address: UInt32) throws -> UInt32
    mutating func writeMemory(value: UInt32, at address: UInt32) throws
    func physicalAddress(from virtual: UInt32) -> UInt32
    var physicalMemorySize: UInt32 { get }
    
    // MARK: - Registers access rights
    // Defines the sets of registers that can only be read/written in supervisor mode
    
    /*
    // MARK: Custom registers
    /// The set of additional registers that can only be read in supervisor mode
    var readReservedRegisters: [RegisterKeyPath] { get }
    
    /// The set of additional registers that can only be written in supervisor mode
    var writeReservedRegisters: [RegisterKeyPath] { get }
 */
    
    mutating func readData(at argument: Argument<Self>) throws -> UInt32
    
    mutating func writeData(at argument: Argument<Self>, value: UInt32) throws
    
    // MARK: - Execution
    mutating func executeCurrentInstruction(context: inout ExecutionContext<Self>) -> ExecutionStepResult
}

public struct ExecutionContext<Processor: ProcessorProtocol> {
    @inlinable
    public func cachedInstruction(at physicalAddress: UInt32) -> AnyInstruction<Processor>? {
        return cache[Int(physicalAddress)]
    }
    
    @usableFromInline
    var cache: [AnyInstruction<Processor>?]
}

public enum ExecutionStepResult {
    case `continue`
    case reset
    case exception(Exception)
}


/// Represents the set of registers common to all Z33 variations
///
/// Variations may define additional registers in their implementations of this protocol
///
/// - Note: All types conforming to this protocol automatically get additional properties
/// such as `srFlags` to deal with flags  at a higher level using `OptionSet`.
public protocol RegistersStorageProtocol {
    /// General purpose register A
    var a: UInt32 { get set }
    
    /// General purpose register B
    var b: UInt32 { get set }
    
    /// Program counter
    var pc: UInt32 { get set }
    
    /// Stack pointer
    var sp: UInt32 { get set }
    
    /// Status register
    var sr: UInt32 { get set }
}

/// Associates a register key path with its name and code
///
/// This is used for translation between key paths, names and codes during parsing, assembly and execution
public struct RegisterDescription<RegistersStorage: RegistersStorageProtocol> {
    init(keyPath: WritableKeyPath<RegistersStorage, UInt32>, name: String, code: UInt32, memoryOffset: Int, protectionStatus: ProtectionStatus = .none) {
        self.keyPath = keyPath
        self.name = name
        self.code = code
        self.memoryOffset = UInt32(memoryOffset)
        self.protectionStatus = protectionStatus
    }
    
    /// The key path for this register on its `RegistersStorage` type
    var keyPath: WritableKeyPath<RegistersStorage, UInt32>
    
    /// The name of this register
    ///
    /// This is used for parsing and debug descriptions
    var name: String
    
    /// The code of this register
    ///
    /// This is used for assembly and execution of instructions
    var code: UInt32
    
    // Offset in processor memory
    var memoryOffset: UInt32
    
    var protectionStatus: ProtectionStatus
    
    
}

struct ProtectionStatus: OptionSet {
    let rawValue: UInt8
    
    static let none = ProtectionStatus([])
    static let read = ProtectionStatus(rawValue: 1)
    static let write = ProtectionStatus(rawValue: 1 << 1)
}
