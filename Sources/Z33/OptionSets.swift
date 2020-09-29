/// An `OptionSet` that represents the possible values for the flags stored in the status register (SR)
struct SRValue: OptionSet {
    let rawValue: Int32
    
    // MARK: User space and kernel space
    static let carry = SRValue(rawValue: 1 << 0)
    static let zero = SRValue(rawValue: 1 << 1)
    static let negative = SRValue(rawValue: 1 << 2)
    static let overflow = SRValue(rawValue: 1 << 3)
    
    // MARK: Kernel space only
    static let interruptEnable = SRValue(rawValue: 1 << 8)
    static let supervisor = SRValue(rawValue: 1 << 9)
}

/// Namespace that holds option sets representing status and command registers flags for the keyboard
enum Keyboard {
    // An `OptionSet` that represents the possible values for the flags of the keyboard state register
    struct SRValue: OptionSet {
        let rawValue: Int
        
        /// Indicates that data is ready to be read
        static let ready = SRValue(rawValue: 1 << 0)
        
        /// Indicates that the controller has generated an interrupt
        static let interrupt = SRValue(rawValue: 1 << 1)
    }
    
    
    // An `OptionSet` that represents the possible values for the flags of the keyboard control register
    struct CRValue: OptionSet {
        let rawValue: Int
        
        /// Indicates to the controller that some new keyboard LED state is available
        /// in the data write register
        static let led = CRValue(rawValue: 1 << 0)
        
        /// Indicates that an interrupt should be generated when new data is available to
        /// be read
        static let interrupt = SRValue(rawValue: 1 << 1)
    }
}

/// Namespace that holds option sets representing status and command registers flags for the disk
enum Disk {
    // An `OptionSet` that represents the possible values for the flags of the disk state register
    struct SRValue: OptionSet {
        let rawValue: Int
        
        /// Indicates that disk is available (eg: inactive)
        static let available = SRValue(rawValue: 1 << 0)
        
        /// Indicates that data is ready to be read
        static let ready = SRValue(rawValue: 1 << 1)
        
        /// Indicates that the controller has generated an interrupt
        static let interrupt = SRValue(rawValue: 1 << 2)
        
        /// Indicates that an error has been detected
        static let error = SRValue(rawValue: 1 << 3)
    }
    
    
    // An `OptionSet` that represents the possible values for the flags of the disk control register
    struct CRValue: OptionSet {
        let rawValue: Int
        
        /// Starts a write request
        static let write = SRValue(rawValue: 1 << 0)
        
        /// Starts a read request
        static let read = SRValue(rawValue: 1 << 1)
        
        // FIXME: What's C/H/S?
        /// Indicates that data register contains C/H/S location
        static let location = SRValue(rawValue: 1 << 2)
        
        /// Indicates that an interrupt should be generated when transfer is over
        static let interrupt = SRValue(rawValue: 1 << 3)
    }
}
