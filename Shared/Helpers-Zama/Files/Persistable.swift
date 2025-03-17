// Copyright © 2025 Zama. All rights reserved.

import Foundation

protocol Persistable {
    func toData() throws -> Data
    init(fromData input: Data) throws
}

extension Persistable {
    func writeToDisk(_ file: Storage.File) async throws {
        let data = try self.toData()
        try await Storage.write(file, data: data)
    }
    
    static func readFromDisk(_ file: Storage.File) async throws -> Self? {
        if let data = await Storage.read(file) {
            return try self.init(fromData: data)
        } else {
            return nil
        }
    }
}
