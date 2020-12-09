import Z33

let count = UInt32(CommandLine.arguments[1])!

print("Will stop at \(count)")

Runner<StandardVariation>().rom {
    Jmp(immediate: 500)
}.code(at: 500) {
    Ld(direct: 505, destination: \.a)
    Ld(direct: 505, destination: \.a)
    Ld(direct: 505, destination: \.a)
    Cmp(immediate: 1, destination: \.a)
    Cmp(immediate: 2, destination: \.a)
    Cmp(immediate: 3, destination: \.a)
    Add(immediate: 1, destination: \.b)
    Cmp(immediate: count, destination: \.b)
    Jne(immediate: 500)
    Reset()
}.run()
