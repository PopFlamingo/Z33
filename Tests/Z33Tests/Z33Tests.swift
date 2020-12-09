import XCTest
import Foundation
@testable import Z33

final class Z33Tests: XCTestCase {
    
    typealias SV = StandardVariation
    
    func compute<T: BinaryRegisterModificator>(_ type: T.Type, lhs: Int32, rhs: Int32) throws -> Int32 where T.Processor == SV {
        var fakeProc = StandardVariation.makeAtDefaultState()
        return try Int32(bitPattern: T.compute(input: UInt32(bitPattern: lhs), destination: UInt32(bitPattern: rhs), processor: &fakeProc))
        
    }
    
    func testAdd() throws {
        XCTAssertEqual(try compute(Add.self, lhs: 0, rhs: 0), 0)
        XCTAssertEqual(try compute(Add.self, lhs: 1, rhs: 0), 1)
        XCTAssertEqual(try compute(Add.self, lhs: 0, rhs: 1), 1)
        XCTAssertEqual(try compute(Add.self, lhs: 0, rhs: -1), -1)
        XCTAssertEqual(try compute(Add.self, lhs: -1, rhs: -1), -2)
        XCTAssertEqual(try compute(Add.self, lhs: 1, rhs: 1), 2)
    }
    
    func testAddEncode() {
//        let add = Add<SV>(indirect: \.b, offset: -512, destination: \.a)
        let add = Add<SV>(direct: 262143, destination: \.a)
        let encoded = add.encodeToBinary()!
        let bits = String(encoded, radix: 2)
        print(String(repeatElement("0", count: 64 - bits.count)) + bits)
        print(Add<SV>.decodeFromBinary(encoded)!.assemblyValue)
        print(add.assemblyValue)
        XCTAssertEqual(Add<SV>.decodeFromBinary(encoded), add)
        print("Done")
    }
    
    func testSub() throws {
        XCTAssertEqual(try compute(Sub.self, lhs: 0, rhs: 0), 0) // Z : ==
        XCTAssertEqual(try compute(Sub.self, lhs: -1, rhs: 0), 1) // C : <
        XCTAssertEqual(try compute(Sub.self, lhs: 1, rhs: 0), -1) // C O : >
        XCTAssertEqual(try compute(Sub.self, lhs: 5, rhs: 5), 0) // Z : ==
        XCTAssertEqual(try compute(Sub.self, lhs: 5, rhs: 0), -5) // CO : >
        XCTAssertEqual(try compute(Sub.self, lhs: 10, rhs: 5), -5) // CO : >
        XCTAssertEqual(try compute(Sub.self, lhs: 5, rhs: 10), 5) // NOTHING : <
        XCTAssertEqual(try compute(Sub.self, lhs: -10, rhs: -5), 5) // O : <
        XCTAssertEqual(try compute(Sub.self, lhs: -5, rhs: -10), -5) // C : >
        XCTAssertEqual(try compute(Sub.self, lhs: -12, rhs: -2), 10) // O : <
        XCTAssertEqual(try compute(Sub.self, lhs: -2, rhs: -12), -10) // C : >
        XCTAssertEqual(try compute(Sub.self, lhs: -2, rhs: 12), 14) // C : <
        XCTAssertEqual(try compute(Sub.self, lhs: 2, rhs: -12), -14) // NOTHING : >
        
        
    }
    
    func testRunner() throws {
        Runner<StandardVariation>().rom {
            Jmp(immediate: 500)
        }.interruptHandler {
            Jmp(immediate: 500)
        }.code(at: 500) {
            Ld(immediate: 5, destination: \.a)
            Cmp(immediate: 1, destination: \.a)
            Jmp(immediate: 500)
            Jge(direct: 526) // casparticulier
            Sub(immediate: 1, destination: \.a)
            // Push(register: \.a)
            Jmp(immediate: 500)
        }.run()
    }
    
    func testRangeConverter() {
        let string = "HelloMyFriend"
        var converter = CodeMap(string: string)
        let startIndex = string.startIndex
        let endOfHello = string.index(startIndex, offsetBy: 5)
        converter.replaceCharacters(in: startIndex..<endOfHello, with: "Hi")
        debugPrint(converter)
    }
    
    
    
    struct FooInstruction<Processor: ProcessorProtocol>: Instruction {
        func encodeToBinary() -> UInt64 {
            fatalError()
        }
        
        static func decodeFromBinary(_ binaryPattern: UInt64) -> Z33Tests.FooInstruction<Processor>? {
            fatalError()
        }
        
        var arguments: ArgumentsStorage<Processor>
        
        static var name: String { "foo" }
        static var opcode: UInt8 { 1 }
        static var argumentsDescription: ArgumentsDescription { .binary(.all, .all) }
        
        func execute(on processor: inout Processor) throws {}
    }
    /*
    func testFoo() throws {
        guard let value = try FooInstruction<SV>.parse(from: "foo 2   , %b") else {
            XCTFail("Couldn't parse value")
            return
        }
        
        print(value)
        
        guard case ArgumentsStorage<SV>.binary(let lhs, let rhs) = value.value.arguments else {
            XCTFail("Didn't parse correct kind of argument")
            return
        }
        
        guard case Argument<SV>.register(let lhsName) = lhs, case Argument<SV>.register(let rhsName) = rhs else {
            XCTFail("Incorrect argument type")
            return
        }
        
        
        XCTAssertEqual(lhsName, \.a)
        XCTAssertEqual(rhsName, \.b)
    }
    */
    
    
    struct TestFileStore: FileResolver {
        
        init(files: [String:String]) {
            self.files = files
        }
        
        var files: [String:String]
        
        func fileContents(at path: String) throws -> String {
            guard let file = files[path] else {
                fatalError("File doesn't exist at path \(path.debugDescription)")
            }
            return file
        }
        
        func canonicalPath(for path: String) -> String {
            return path
        }
        
        
    }
    
    func testPreprocessor() throws {
        let context = Preprocessor.Context(fileResolver: TestFileStore(files: [
            "main.s" : """
            #include <a.s>
            // Some comment
            // Some other comment that contains BAR and FOO
            add FOO, $a
            """,
            
            "a.s" : """
            #define FOO 10
            """
        ]))
        
        let preprocessor = try Preprocessor(programPath: "main.s", context: context)
        
        do {
            let codeMap = try preprocessor.process()
            for segment in codeMap.segments {
                if let uuid = segment.externalUUID, let externalCodeMap = context.codeMaps[uuid] {
                    print("Other file:")
                    debugPrint("\(codeMap.modified[segment.current])")
                    debugPrint("\(externalCodeMap.modified)")
                } else {
                    print("Self:")
                    debugPrint("\(codeMap.modified[segment.current])")
                    debugPrint("\(preprocessor.program[segment.previous])")
                }
            }
            print(codeMap.modified)
            print(codeMap.convertToOriginal(from: codeMap.modified.index(codeMap.modified.startIndex, offsetBy: 18)))
            print("Done")
        } catch {
            if let error = error as? ParseError {
                print("Error: \(error.description)")
                switch error.location {
                case .single(let index):
                    print(preprocessor.program[index...])
                case .range(let range):
                    print(preprocessor.program[range])
                }
            }
        }
        
        print("Cool")
    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        // XCTAssertEqual(Z33().text, "Hello, World!")
        print("\\\"")
        // StringData
        let value: Substring = """
        .string \t      "hey"
        """
        print(value)
        print(try! StringData.parse(from: value)!.value.value)
        print("wow")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
