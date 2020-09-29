import XCTest
import Foundation
@testable import Z33

final class Z33Tests: XCTestCase {
    
    func testRangeConverter() {
        let string = "HelloMyFriend"
        var converter = CodeMap(string: string)
        let startIndex = string.startIndex
        let endOfHello = string.index(startIndex, offsetBy: 5)
        converter.replaceCharacters(in: startIndex..<endOfHello, with: "Hi")
        debugPrint(converter)
    }
    
    typealias SV = StandardVariation
    
    struct FooInstruction<Processor: ProcessorProtocol>: Instruction {
        var arguments: ArgumentsStorage<Processor>
        
        static var name: String { "foo" }
        static var opcode: UInt8 { 1 }
        static var argumentsDescription: ArgumentsDescription { .binary(.all, .all) }
        
        func execute(on processor: inout Processor) throws {}
    }
    
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
