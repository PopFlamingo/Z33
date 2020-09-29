import Foundation
import ParserBuilder

struct Preprocessor {
    init(programPath: String, context: Context) throws {
        self.context = context
        self.programPath = try context.fileResolver.canonicalPath(for: programPath)
        self.program = try context.fileResolver.fileContents(at: programPath)
        self.uuid = UUID()
    }
    
    /// The contents of the program to preprocess
    ///
    /// These contents are loaded with the context's `FileResolver` at the specified `programPath`
    /// for this preprocessor
    let program: String
    
    /// The canonical path of the program to preprocess
    let programPath: String
    
    /// The `UUID` of this preprocessor
    ///
    /// The `UUID` is used to uniquely idenitfy a preprocessor as well as its output.
    /// There is indeed one preprocessor per file inclusion plus the preprocessor of
    /// the main assembly file.
    let uuid: UUID
    
    /// The current context
    ///
    /// The context holds information shared by all preprocessors such as defines
    /// up to this point. It also holds the `StringRangeConverter`s that have
    /// been computed up to this point by calling `process()`
    let context: Context
    
    func process() throws -> CodeMap {
        let parts = try self.extractTokens()
        let tree = try self.buildTree(from: parts)
        try self.evaluate(ast: tree)
        let codeMap = self.evaluateToCodeMap(tree)
        self.context.codeMaps[self.uuid] = codeMap
        return codeMap
    }
    
    // MARK: - Lexing (kind of...)
    func extractTokens() throws -> [Token] {
        var currentIndex = program.startIndex
        var currentCodeSectionStartIndex = currentIndex
        var parts = [Token]()
        var isAtStart = true
        while currentIndex != program.endIndex {
            var extractor = Extractor(program[currentIndex...])
            
            // Must have a line return before, except if it's at start of document
            if extractor.popCurrent(with: ("\n" || "\r").count(1...)) == nil && !isAtStart {
                currentIndex = program.index(after: currentIndex)
                continue
            } else {
                isAtStart = false
                currentIndex = extractor.currentIndex
            }
            
            let beforePreprocessorParse = currentIndex
            
            extractor.popCurrent(with: CommonMatchers.whitespace.count(0...))
            currentIndex = extractor.currentIndex
            
            let substring = program[currentIndex...]
            
            let parsedPart: Token
            
            if let parsedIf = try Preprocessor.If.parse(from: substring) {
                let range = currentIndex..<parsedIf.advancedIndex
                currentIndex = parsedIf.advancedIndex
                parsedPart = Token(range: range, value: .if(parsedIf.value))
            } else if let parsedElseIf = try Preprocessor.ElseIf.parse(from: substring) {
                let range = currentIndex..<parsedElseIf.advancedIndex
                currentIndex = parsedElseIf.advancedIndex
                parsedPart = Token(range: range, value: .elseif(parsedElseIf.value))
            } else if let parsedElse = try Preprocessor.Else.parse(from: substring) {
                let range = currentIndex..<parsedElse.advancedIndex
                currentIndex = parsedElse.advancedIndex
                parsedPart = Token(range: range, value: .else(parsedElse.value))
            } else if let parsedEndIf = try Preprocessor.EndIf.parse(from: substring) {
                let range = currentIndex..<parsedEndIf.advancedIndex
                currentIndex = parsedEndIf.advancedIndex
                parsedPart = Token(range: range, value: .endif(parsedEndIf.value))
            } else if let parsedInclude = try Preprocessor.Include.parse(from: substring) {
                let range = currentIndex..<parsedInclude.advancedIndex
                currentIndex = parsedInclude.advancedIndex
                parsedPart = Token(range: range, value: .include(parsedInclude.value))
            } else if let parsedDefine = try Preprocessor.Define.parse(from: substring) {
                let range = currentIndex..<parsedDefine.advancedIndex
                currentIndex = parsedDefine.advancedIndex
                parsedPart = Token(range: range, value: .define(parsedDefine.value))
            } else {
                continue
            }
            
            // We only reach this place if we did parse something
            // Now we must first check if this correctly ends
            // with an optional comment and a new line as this
            // is required for macro statements
            extractor = Extractor(program[currentIndex...])
            extractor.popCurrent(with: CommonMatchers.whitespace.count(0...))
            currentIndex = extractor.currentIndex
            currentIndex = try Comment.parse(from: program[currentIndex...])?.advancedIndex ?? currentIndex
            extractor = Extractor(program[currentIndex...])
            extractor.popCurrent(with: CommonMatchers.whitespace.count(0...))
            guard case let endOfLine = extractor.peekCurrent(with: ("\n" || "\r")), endOfLine != nil || extractor.currentIndex == program.endIndex else {
                continue
            }
            
            // We add the code that came before in its own section
            if beforePreprocessorParse > currentCodeSectionStartIndex {
                parts.append(Token(range: currentCodeSectionStartIndex..<beforePreprocessorParse, value: .code))
            }
            
            currentCodeSectionStartIndex = endOfLine?.endIndex ?? extractor.currentIndex
            parts.append(parsedPart)
        }
        
        if currentIndex > currentCodeSectionStartIndex {
            parts.append(Token(range: currentCodeSectionStartIndex..<currentIndex, value: .code))
        }
        
        return parts
    }
    
    struct Token {
        var range: Range<String.Index>
        var value: Value
        
        enum Value {
            case `if`(Preprocessor.If)
            case elseif(Preprocessor.ElseIf)
            case `else`(Preprocessor.Else)
            case endif(Preprocessor.EndIf)
            case include(Preprocessor.Include)
            case define(Preprocessor.Define)
            case code
        }
    }
    
    // MARK: - AST
    // MARK: Build tree
    
    /// Build tree and throw errors related to incorrect program grammar
    ///
    /// This for instance detects unmatched #if/#endif statements
    func buildTree(from tokens: [Token]) throws -> Node {
        let root = Node(range: nil)
        var current = root
        
        func insertAndMakeCurrent(_ node: Node, at index: Int? = nil) {
            current.insertChild(node: node, at: index)
            current = node
        }
        
        for token in tokens {
            switch token.value {
            case .if(let ifValue):
                assert(!(current is ConditionGroup), "Attempting to insert an #if inside an already existing ConditionGroup")
                insertAndMakeCurrent(ConditionGroup())
                insertAndMakeCurrent(IfNode(expression: ifValue.expression, range: token.range))
                
            case .elseif(let elseIfValue):
                guard let parentConditionGroup = current.parent as? ConditionGroup else {
                    throw ParseError(description: "#elseif statement doesn't match any previous condition blocks, did you mean to use #if?", token.range)
                }
                let node = IfNode(expression: elseIfValue.expression, range: token.range)
                parentConditionGroup.insertChild(node: node)
                current = node
                
            case .else:
                guard let parentConditionGroup = current.parent as? ConditionGroup else {
                    throw ParseError(description: "#else statement doesn't match any previous #if or #else statements", token.range)
                }
                let node = ElseNode(range: token.range)
                parentConditionGroup.insertChild(node: node)
                current = node
                
            case .endif:
                guard current.parent is ConditionGroup else {
                    throw ParseError(description: "#endif statement doesn't match any previous condition blocks", token.range)
                }
                guard let grandparent = current.grandparent else {
                    fatalError("ConditionGroup used at root of tree")
                }
                current = grandparent
                
            case .include(let includeValue):
                current.insertChild(node: IncludeNode(preprocessorInclude: includeValue, range: token.range))
                
            case .define(let defineValue):
                current.insertChild(node: DefineNode(preprocessorDefine: defineValue, range: token.range))
                
            case .code:
                current.insertChild(node: CodeNode(substring: program[token.range],
                                                   originalRange: token.range,
                                                   isDirectMapping: true,
                                                   file: self.programPath,
                                                   uuid: self.uuid,
                                                   range: token.range))
            }
        }
        
        guard current === root else {
            guard let parentConditionGroup = current.parent as? ConditionGroup, let firstIf = parentConditionGroup.children.first else {
                throw ASTError("Unknown error: a block might be unclosed but can't determine which. Please report a bug with this programm attached.")
            }
            
            if let range = firstIf.range {
                throw ParseError(description: "This #if statement doesn't have a matching #endif", range)
            } else {
                throw ASTError("Unknown error: a block might be unclosed but can't determine which. Please report a bug with this programm attached.")
            }
        }
        
        return current
    }
    
    
    // MARK: Evaluate tree
    func evaluate(ast: Node) throws {
        assert(ast.parent == nil, "AST node should be a root node")
        guard let start = ast.children.first else {
            return
        }
        
        var current: Node? = start
        repeat {
            if let defineNode = current as? DefineNode {
                guard context.defines[defineNode.symbolName] == nil else {
                    throw ParseError(description: "Definition of \"\(defineNode.symbolName)\" conflicts with previous definition", defineNode.range!)
                }
                context.defines[defineNode.symbolName] = defineNode.value
                current = current?.nextNode
            } else if let conditionGroup = current as? ConditionGroup {
                current = conditionGroup.children.first ?? current?.nextNode
            } else if let ifNode = current as? IfNode {
                let branchShouldExecute: Bool
                switch ifNode.expression {
                case .defined(let symbolName):
                    branchShouldExecute = context.defines[symbolName] != nil
                case .notdefined(let symbolName):
                    branchShouldExecute = context.defines[symbolName] == nil
                }
                
                if branchShouldExecute {
                    // Other branches won't be executed, we therefore just replace the group
                    // with the content of the content of the only branch that will be executed
                    let conditionGroup = (ifNode.parent as? ConditionGroup)!
                    let firstChild = ifNode.children.first
                    let nextAfterGroup = conditionGroup.nextNode
                    conditionGroup.replaceInParent(with: ifNode.children)
                    current = firstChild ?? nextAfterGroup
                } else {
                    current = ifNode.nextNode
                    ifNode.removeFromParent()
                }
                
            } else if let elseNode = current as? ElseNode {
                let conditionGroup = (elseNode.parent as? ConditionGroup)!
                let nextAfterGroup = conditionGroup.nextNode
                let firstChild = elseNode.children.first
                conditionGroup.replaceInParent(with: elseNode.children)
                current = firstChild ?? nextAfterGroup
            } else if let includeNode = current as? IncludeNode {
                // FIXME: Avoid recursive includes
                let preprocessor = try Preprocessor(programPath: includeNode.path, context: self.context)
                let code = try preprocessor.process().modified
                let substr: Substring = "\(code)"
                let codeNode = CodeNode(substring: substr, originalRange: includeNode.range!, isDirectMapping: true, file: includeNode.path, uuid: preprocessor.uuid, range: substr.startIndex..<substr.endIndex)
                let next = includeNode.nextNode
                includeNode.replaceInParent(with: codeNode)
                current = next
            } else {
                current = current?.nextNode
            }
            
            
        } while current != nil
        
    }
    
    func evaluateToCodeMap(_ ast: Node) -> CodeMap {
        var codeMap = CodeMap(string: self.program)
        codeMap.modified = ""
        let range = self.program.startIndex..<self.program.startIndex
        codeMap.segments = [CodeMap.Segment(previous: range, current: range, isDirectMapping: true)]
        let codeNodes = ast.children.compactMap({ $0 as? CodeNode })
        for codeNode in codeNodes {
            if codeNode.uuid != self.uuid {
                let lastSegment = codeMap.segments.last!
                
                let previousRange = lastSegment.previous.upperBound..<lastSegment.previous.upperBound
                let currentStart = codeMap.modified.endIndex
                codeMap.modified.append(contentsOf: codeNode.substring)
                let currentRange = currentStart..<codeMap.modified.endIndex
                var segment = CodeMap.Segment(previous: previousRange,
                                                           current: currentRange,
                                                           isDirectMapping: false)
                segment.externalUUID = codeNode.uuid
                codeMap.segments.append(segment)
                
                // If the added substring doesn't end with a newline we add it
                if codeNode.substring.last != "\n" {
                    let beforeNewLine = codeMap.modified.endIndex
                    let beforePrevious = codeMap.original.index(codeMap.original.endIndex, offsetBy: -1, limitedBy: codeMap.original.startIndex) ?? codeMap.original.startIndex
                    codeMap.modified.append("\n")
                    codeMap.segments.append(.init(previous: beforePrevious..<codeMap.original.endIndex, current: beforeNewLine..<codeMap.modified.endIndex, isDirectMapping: false))
                }
            } else {
                let start = codeMap.modified.endIndex
                codeMap.modified.append(contentsOf: codeNode.substring)
                let currentRange = start..<codeMap.modified.endIndex
                codeMap.segments.append(.init(previous: codeNode.originalRange, current: currentRange, isDirectMapping: true))
                
                var currentIndex = currentRange.lowerBound
                var definedSymbolsMatcher = !Matcher.any()
                
                for symbol in self.context.defines.keys.sorted(by: { $0.count > $1.count }) {
                    definedSymbolsMatcher = definedSymbolsMatcher || Matcher(symbol)
                }
                
                // FIXME: Check that use of ?? is correct (empty string)
                // Or does beforeTheEnd ever make any sense
                // let beforeTheEnd = codeMap.modified.index(currentRange.upperBound, offsetBy: -1)
                while currentIndex < codeMap.modified.endIndex {
                    // FIXME: Check if the unclosed range is ok here
                    var extractor = Extractor(codeMap.modified[currentIndex...])
                
                    // We pop string literals and comments as we don't
                    // want to substitute the symbols contained in them
                    // FIXME: The warning without _ = may be a Swift bug
                    _ = try? extractor.popStringLiteral()
                    _ = try? extractor.popComment()
                    
                    let matcherStart: Matcher = !(CommonMatchers.symbolNameMatcher && !definedSymbolsMatcher)
                    let matcherEnd: Matcher = (!CommonMatchers.symbolNameMatcher)
                    let matcher: Matcher
                    
                    
                    if extractor.currentIndex == currentRange.lowerBound {
                        matcher = definedSymbolsMatcher + matcherEnd
                    } else {
                        matcher = matcherStart + definedSymbolsMatcher + matcherEnd
                    }
                    
                    if let baseMatch = extractor.popCurrent(with: matcher) {
                        var actualNameExtractor = Extractor(baseMatch)
                        let name = actualNameExtractor.matches(for: definedSymbolsMatcher).first!
                        // FIXME: Should we really replace none value defines with empty string?
                        currentIndex = codeMap.replaceCharacters(in: name.startIndex..<name.endIndex, with: self.context.defines["\(name)"]!.description)
                    } else {
                        currentIndex = codeMap.modified.index(extractor.currentIndex, offsetBy: 1, limitedBy: codeMap.modified.endIndex) ?? codeMap.modified.endIndex
                    }
                }
            }
        }
        return codeMap
    }
    
    // FIXME: This is temporary and actually needs to use StringRangeConverter
    // MARK: Write as string
    func evaluateToString(_ ast: Node) -> String {
        var result = ""
        for childNode in ast.children {
            if let code = childNode as? CodeNode {
                result += code.substring
            }
        }
        return result
    }
    
    // MARK: Node types
    class Node {
        init(range: Range<String.Index>?) {
            self.range = range
            self.children = []
            self.parent = nil
        }
        
        var range: Range<String.Index>?
        private(set) var children: [Node]
        private(set) weak var parent: Node?
        var grandparent: Node? {
            return parent?.parent
        }
        
        var nextNode: Node? {
            guard let parent = self.parent else {
                return nil
            }
            let index = parent.children.firstIndex(where: { $0 === self })!
            
            if index+1 < parent.children.endIndex {
                return parent.children[index+1]
            } else {
                return parent.nextNode
            }
        }
        
        var root: Node? {
            return firstParent(where: { $0.parent == nil })
        }
        
        func removeAllChildren(after childNode: Node) {
            guard let childNodeIndex = self.children.firstIndex(where: { $0 === childNode }) else {
                fatalError("\(#function): No such child node")
            }
            
            guard case let nextChildNode = childNodeIndex + 1, nextChildNode != self.children.endIndex else {
                return
            }
            
            self.children.removeSubrange(nextChildNode...)
        }
        
        func replaceInParent(with otherNode: Node) {
            self.replaceInParent(with: [otherNode])
        }
        
        func replaceInParent(with otherNodes: [Node]) {
            guard let parent = self.parent else {
                return
            }
            guard let selfIndexInParent = parent.children.firstIndex(where: { $0 === self }) else {
                fatalError("\(#function): No such child node")
            }
            otherNodes.forEach { node in
                node.removeFromParent()
                node.parent = parent
            }
            parent.children.insert(contentsOf: otherNodes, at: selfIndexInParent)
            self.removeFromParent()
        }
        
        func firstParent(where parentPrecondition: (Node) throws -> Bool) rethrows -> Node? {
            var maybeParent = self.parent
            while let currentParent = maybeParent {
                if try parentPrecondition(currentParent) {
                    return currentParent
                }
                maybeParent = currentParent.parent
            }
            return nil
        }
        
        func insertChild(node: Node, at index: Int? = nil) {
            node.parent = self
            if let index = index {
                self.children.insert(node, at: index)
            } else {
                self.children.append(node)
            }
        }
        
        
        func removeChild(at index: Int) {
            children.remove(at: index)
        }
        
        func removeFromParent() {
            guard let parent = self.parent else { return }
            guard let index = self.parent?.children.firstIndex(where: { $0 === self }) else {
                fatalError("Child node should have been contained by parent")
            }
            parent.removeChild(at: index)
            self.parent = nil
        }
    }
    
    class ConditionGroup: Node {
        init() {
            super.init(range: nil)
        }
        
        override func insertChild(node: Node, at index: Int? = nil) {
            assert(node is IfNode || node is ElseNode)
            super.insertChild(node: node, at: index)
        }
    }
    
    class IfNode: Node {
        init(expression: Preprocessor.PreprocessorExpression, range: Range<String.Index>) {
            self.expression = expression
            super.init(range: range)
        }
        
        var expression: Preprocessor.PreprocessorExpression
    }
    
    class ElseNode: Node {}
    
    class DefineNode: Node {
        init(symbolName: String, value: DefineValue, range: Range<String.Index>) {
            self.symbolName = symbolName
            self.value = value
            super.init(range: range)
        }
        
        convenience init(preprocessorDefine: Preprocessor.Define, range: Range<String.Index>) {
            self.init(symbolName: preprocessorDefine.symbolName, value: preprocessorDefine.value, range: range)
        }
        
        var symbolName: String
        var value: DefineValue
    }
    
    class IncludeNode: Node {
        init(path: String, range: Range<String.Index>) {
            self.path = path
            super.init(range: range)
        }
        
        convenience init(preprocessorInclude: Preprocessor.Include, range: Range<String.Index>) {
            self.init(path: preprocessorInclude.path, range: range)
        }
        
        var path: String
    }
    
    class CodeNode: Node {
        init(substring: Substring, originalRange: Range<String.Index>, isDirectMapping: Bool, file: String, uuid: UUID, range: Range<String.Index>) {
            self.substring = substring
            self.originalRange = originalRange
            self.isDirectMapping = isDirectMapping
            self.uuid = uuid
            self.file = file
            super.init(range: range)
        }
        
        // The substring this node represents
        var substring: Substring
        
        // The range of this substring in its original file
        var originalRange: Range<String.Index>
        
        // Wether this has a one-to-one mapping with the original file
        //
        // This essentially means
        var isDirectMapping: Bool
        
        // The cannonical name for the file
        var file: String
        
        // The UUID for the processed file
        var uuid: UUID
    }
    
    struct ASTError: Error {
        init(_ value: String) {
            self.value = value
        }
        
        var value: String
    }
    
    // MARK: - Instructions
    struct Define: Statement {
        var symbolName: String
        var value: DefineValue
        
        
        
        static func parse(from substring: Substring) throws -> ParseResult<Preprocessor.Define>? {
            var extractor = Extractor(substring)
            guard extractor.popCurrent(with: "#define") != nil else {
                return nil
            }
            
            extractor.popCurrent(with: CommonMatchers.whitespace.count(0...))
            
            guard let symbolName = extractor.popCurrent(with: CommonMatchers.symbolNameMatcher) else {
                throw ParseError(description: "Expected a symbol name", location: .single(extractor.currentIndex))
            }
            
            extractor.popCurrent(with: CommonMatchers.whitespace.count(0...))
            
            if let string = try extractor.popStringLiteral() {
                return .init(value: .init(symbolName: String(symbolName), value: .string(string)), advancedIndex: extractor.currentIndex)
            } else if let number = try extractor.popNumberLiteral() {
                return .init(value: .init(symbolName: String(symbolName), value: .number(number)), advancedIndex: extractor.currentIndex)
            } else {
                return .init(value: .init(symbolName: String(symbolName), value: .none), advancedIndex: extractor.currentIndex)
            }
        }
        
        var assemblyValue: String {
            return "#define \(value)"
        }
    }
    
    struct Include: Statement {
        var path: String
        
        static func parse(from substring: Substring) throws -> ParseResult<Preprocessor.Include>? {
            var extractor = Extractor(substring)
            guard extractor.popCurrent(with: "#include") != nil else {
                return nil
            }
            
            extractor.popCurrent(with: CommonMatchers.whitespace.count(0...))
            
            guard extractor.popCurrent(with: "<") != nil else {
                throw ParseError(description: "Expected < before included file name", location: .single(extractor.currentIndex))
            }
            
            let allowedPathCharacters = CommonMatchers.letter || CommonMatchers.number || " " || "_" || "-" || "." || "/"
            
            guard let path = extractor.popCurrent(with: allowedPathCharacters.count(1...)) else {
                throw ParseError(description: "Missing or invalid path name", location: .single(extractor.currentIndex))
            }
            
            guard extractor.popCurrent(with: ">") != nil else {
                throw ParseError(description: "Expected closing > before after file name", location: .single(extractor.currentIndex))
            }
            
            return .init(value: .init(path: String(path)), advancedIndex: extractor.currentIndex)
        }
        
        var assemblyValue: String {
            return "#include <\(path)>"
        }
    }
    
    enum PreprocessorExpression: CustomStringConvertible {
        case defined(symbol: String)
        case notdefined(symbol: String)
        
        static func parse(from extractor: inout Extractor<Substring>) throws -> PreprocessorExpression? {
            // FIXME: Refactor for code repetition
            if extractor.popCurrent(with: "defined(" + CommonMatchers.whitespace.count(0...)) != nil {
                guard let symbolName = extractor.popCurrent(with: CommonMatchers.symbolNameMatcher) else {
                    throw ParseError(description: "Expected a symbol name", location: .single(extractor.currentIndex))
                }
                
                extractor.popCurrent(with: CommonMatchers.whitespace.count(0...))
                
                guard extractor.popCurrent(with: ")") != nil else {
                    throw ParseError(description: "Missing closing )", location: .single(extractor.currentIndex))
                }
                return PreprocessorExpression.defined(symbol: String(symbolName))
            } else if extractor.popCurrent(with: "notdefined(" + CommonMatchers.whitespace.count(0...)) != nil {
                guard let symbolName = extractor.popCurrent(with: CommonMatchers.symbolNameMatcher) else {
                    throw ParseError(description: "Expected a symbol name", location: .single(extractor.currentIndex))
                }
                
                extractor.popCurrent(with: CommonMatchers.whitespace.count(0...))
                
                guard extractor.popCurrent(with: ")") != nil else {
                    throw ParseError(description: "Missing closing )", location: .single(extractor.currentIndex))
                }
                return PreprocessorExpression.notdefined(symbol: String(symbolName))
            } else {
                throw ParseError(description: "Expected a valid preprocessor expression", location: .single(extractor.currentIndex))
            }
        }
        
        var description: String {
            switch self {
            case .defined(let symbol):
                return "defined(\(symbol)"
            case .notdefined(let symbol):
                return "notdefined(\(symbol))"
            }
        }
    }
    
    struct If: Statement {
        var expression: PreprocessorExpression
        
        static func parse(from substring: Substring) throws -> ParseResult<Preprocessor.If>? {
            var extractor = Extractor(substring)
            guard extractor.popCurrent(with: "#if") != nil else {
                return nil
            }
            
            extractor.popCurrent(with: CommonMatchers.whitespace.count(0...))
            
            guard let expression = try PreprocessorExpression.parse(from: &extractor) else {
                throw ParseError(description: "Expected a preprocessor expression", location: .single(extractor.currentIndex))
            }
            
            return .init(value: .init(expression: expression), advancedIndex: extractor.currentIndex)
        }
        
        var assemblyValue: String {
            return "#if \(expression)"
        }
    }
    
    struct ElseIf: Statement {
        var expression: PreprocessorExpression
        
        static func parse(from substring: Substring) throws -> ParseResult<Preprocessor.ElseIf>? {
            var extractor = Extractor(substring)
            guard extractor.popCurrent(with: "#elseif") != nil else {
                return nil
            }
            
            extractor.popCurrent(with: CommonMatchers.whitespace.count(0...))
            
            guard let expression = try PreprocessorExpression.parse(from: &extractor) else {
                throw ParseError(description: "Expected a preprocessor expression", location: .single(extractor.currentIndex))
            }
            
            return .init(value: .init(expression: expression), advancedIndex: extractor.currentIndex)
        }
        
        var assemblyValue: String {
            return "#elseif \(expression)"
        }
    }
    
    struct Else: Statement {
        static func parse(from substring: Substring) throws -> ParseResult<Preprocessor.Else>? {
            var extractor = Extractor(substring)
            guard extractor.popCurrent(with: "#else") != nil else {
                return nil
            }
            
            return .init(value: .init(), advancedIndex: extractor.currentIndex)
        }
        
        var assemblyValue: String {
            return "#else"
        }
    }
    
    struct EndIf: Statement {
        static func parse(from substring: Substring) throws -> ParseResult<Preprocessor.EndIf>? {
            var extractor = Extractor(substring)
            guard extractor.popCurrent(with: "#endif") != nil else {
                return nil
            }
            
            return .init(value: .init(), advancedIndex: extractor.currentIndex)
        }
        
        var assemblyValue: String {
            return "#endif"
        }
    }
    
    class Context {
        init(fileResolver: FileResolver, defines: [String:DefineValue] = [:], codeMaps: [UUID:CodeMap] = [:]) {
            self.fileResolver = fileResolver
            self.defines = defines
            self.codeMaps = codeMaps
        }
        
        let fileResolver: FileResolver
        var defines: [String:DefineValue]
        var codeMaps: [UUID:CodeMap]
    }
}

enum DefineValue: CustomStringConvertible {
    case none
    case number(Int32)
    case string(String)
    
    var description: String {
        switch self {
        case .none:
            return ""
        case .number(let number):
            return "\(number)"
        case .string(let string):
            // FIXME: Might not be ok to use debugDescription
            return string.debugDescription
        }
    }
}


protocol FileResolver {
    func fileContents(at path: String) throws -> String
    func canonicalPath(for path: String) throws -> String
}
