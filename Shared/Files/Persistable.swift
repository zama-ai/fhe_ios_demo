// Copyright © 2024 Zama. All rights reserved.

import Foundation

protocol Persistable {
    func toData() throws -> Data
    init(fromData input: Data) throws
}

//protocol Persistable: Serializable {
//    var fileName: Storage.File { get }
//}

extension Persistable {
    func writeToDisk(_ file: Storage.File) async throws {
        let data = try self.toData()
        try await Storage.write(file, data: data)
    }
    
    static func readFromDisk(_ file: Storage.File) async throws -> Self? {
        if let data = try await Storage.read(file) {
            return try self.init(fromData: data)
        } else {
            return nil
        }
    }
}

//extension Persistable where Self: Serializable {
//    func writeToDisk() async throws {
//        try await writeToDisk(fileName)
//    }
//    
//    func deleteFromDisk() async throws {
//        try await Storage.deleteFromDisk(fileName)
//    }
//}
