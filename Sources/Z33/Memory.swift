struct Memory {
    
    let size: Int
    var storage: [Int32]
    
    init(size: Int) {
        self.size = size
        self.storage = .init(repeating: 0, count: size)
    }
}
