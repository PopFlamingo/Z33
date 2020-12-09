import Z33
import Darwin


Runner<StandardVariation>().rom {
    Jmp(immediate: 500)
}.interruptHandler {
    Jmp(immediate: 500)
}.code(at: 500) {
    Ld(immediate: 5, destination: \.a)
    Ld(immediate: 5, destination: \.a)
    Ld(immediate: 5, destination: \.a)
    Cmp(immediate: 1, destination: \.a)
    Cmp(immediate: 1, destination: \.a)
    Cmp(immediate: 1, destination: \.a)
    Jmp(immediate: 500)
    Jge(direct: 526) // casparticulier
    Sub(immediate: 1, destination: \.a)
    // Push(register: \.a)
    Jmp(immediate: 500)
}.printSteps()
