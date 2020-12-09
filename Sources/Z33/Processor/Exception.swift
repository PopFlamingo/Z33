public struct Exception: Error {
    public init(eventCode: EventCode) {
        precondition(eventCode != .hardwareInterrupt, "Attempting to create an Exception error with interrupt event code")
        self.eventCode = eventCode
    }
    
    public var eventCode: EventCode
}
