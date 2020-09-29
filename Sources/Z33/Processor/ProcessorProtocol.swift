/// A protocol to which all architecture variations should conform.
///
/// This protocol guarantees the presence of common registers as well as the
/// presence of memory I/O operations
protocol ProcessorProtocol {
    
    /// The type that stores the registers for this processor
    ///
    /// This type conforms to `RegistersStorageProtocol` which guarantees the presence
    /// of a set of basic registers common to all Z33 variations.
    /// It is also used as a destination for the registers key paths, which enables to make use
    /// of autocompletion and type safety for accessing the registers
    associatedtype RegistersStorage: RegistersStorageProtocol
    
    /// A  `WritableKeyPath` to an integer property in `RegistersStorage`
    typealias RegisterKeyPath = WritableKeyPath<RegistersStorage, Int32>
    
    // MARK: - Registers
    
    /// The registers for the processor
    ///
    /// - Seealso: `RegistersStorage`
    var registers: RegistersStorage { get set }
    
    /// Get base registers key paths from their names
    ///
    /// - Warning:
    /// This method has a default implementation that should be valid for all types that conform to `CommonArchitecture`
    /// You should probably never re-define it, instead, use `additionalRegistersKeyPath` to specify additional registers
    static func _baseRegisterKeyPath(for registerName: String) -> RegisterKeyPath?
    
    /// Translate register names not defined by `CommonArchitecture` to a `RegisterKeyPath`
    ///
    /// - Note:
    /// All registers supported by this method will also be directly availble from the default implementation of `registerKeyPath`
    /// as it calls `additionalRegistersKeyPath` itself for names that `_baseRegisterKeyPath` is unaware of
    static func additionalRegisterKeyPath(for registerName: String) -> RegisterKeyPath?
    
    mutating func readRegister(at registerKeyPath: RegisterKeyPath) throws -> Int32
    mutating func writeRegister(value: Int32, at registerKeyPath: RegisterKeyPath) throws
    
    // MARK: - Memory I/O
    
    // Memory I/O operations are a variation agnostic representation
    // of the memory operations : adress translation is handled transparently
    // by the variation, instructions can be written as if they were dealing
    // with the standard Z33 processor
    
    mutating func readMemory(at address: Int32) throws -> Int32
    mutating func writeMemory(value: Int32, at address: Int32) throws
    var maxMemoryAddress: Int32 { get }
    
    // MARK: - Registers access rights
    // Defines the sets of registers that can only be read/written in supervisor mode
    
    // MARK: Default implementations
    // This should probably not be re-implemented, use the `additional*ReservedRegisters`
    // properties instead
    var _baseReadReservedRegisters: Set<RegisterKeyPath> { get }
    var _baseWriteReservedRegisters: Set<RegisterKeyPath> { get }
    
    // MARK: Custom registers
    /// The set of additional registers that can only be read in supervisor mode
    var additionalReadReservedRegisters: Set<RegisterKeyPath> { get }
    
    /// The set of additional registers that can only be written in supervisor mode
    var additionalWriteReservedRegisters: Set<RegisterKeyPath> { get }
}


/// Represents the set of registers common to all Z33 variations
///
/// Variations may define additional registers in their implementations of this protocol
///
/// - Note: All types conforming to this protocol automatically get additional properties
/// such as `srFlags` to deal with flags  at a higher level using `OptionSet`.
protocol RegistersStorageProtocol {
    /// General purpose register A
    var a: Int32 { get set }
    
    /// General purpose register B
    var b: Int32 { get set }
    
    /// Program counter
    var pc: Int32 { get set }
    
    /// Stack pointer
    var sp: Int32 { get set }
    
    /// Status register
    var sr: Int32 { get set }
}
