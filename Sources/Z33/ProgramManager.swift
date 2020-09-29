protocol ProgramStateDelegate: class {
    
}

class ProgramManager {
    private var fileStore = StoringFileResolver()
    
    func setFile(at path: String, with contents: String) throws {
        try self.fileStore.setFile(at: path, with: contents)
    }
    
    func removeFile(at path: String) throws {
        try self.fileStore.removeFile(at: path)
    }
    
    struct StoringFileResolver: Z33.FileResolver {
        func fileContents(at path: String) throws -> String {
            guard !path.contains("/") && !path.contains(".") else {
                throw Error("File hiearchy is currently flat and therefore doesn't support such path specifiers")
            }
            guard let file = files[path] else {
                throw Error("File at path \"\(path)\" doesn't exist")
            }
            
            return file
        }
        
        func canonicalPath(for path: String) throws -> String {
            guard !path.contains("/") && !path.contains(".") else {
                throw Error("File hiearchy is currently flat and therefore doesn't support such path specifiers")
            }
            return path
        }
        
        mutating func setFile(at path: String, with contents: String) throws {
            guard !path.contains("/") && !path.contains(".") else {
                throw Error("File hiearchy is currently flat and therefore doesn't support such path specifiers")
            }
            files[path] = contents
        }
        
        mutating func removeFile(at path: String) throws {
            guard !path.contains("/") && !path.contains(".") else {
                throw Error("File hiearchy is currently flat and therefore doesn't support such path specifiers")
            }
            guard files.keys.contains(path) else {
                throw Error("Attempting to remove a non-existent file")
            }
            
            files[path] = nil
        }
        
        private var files = [String:String]()
    }
    
    
    
    struct Error: Swift.Error, CustomStringConvertible {
        init(_ description: String) {
            self.description = description
        }
        var description: String
    }
}
