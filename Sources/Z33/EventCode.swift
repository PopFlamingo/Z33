/// Possible event codes for interruptions and exceptions
public enum EventCode: Int, Error {
    case hardwareInterrupt = 0
    case divisionByZero = 1
    case invalidInstruction = 2
    case privilegedInstruction = 3
    case trap = 4
    case invalidMemoryAccess = 5
}
