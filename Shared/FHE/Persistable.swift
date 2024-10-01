// Copyright © 2024 Zama. All rights reserved.

import Foundation

protocol Persistable {
    static var fileName: Storage.File { get }
    
    func toData() throws -> Data
    init(fromData input: Data) throws
}

extension Persistable {
    func writeToDisk() async throws {
        let data = try self.toData()
        try await Storage.write(Self.fileName, data: data)
    }
    
    static func deleteFromDisk() async throws {
        try await Storage.write(Self.fileName, data: nil)
    }

    static func readFromDisk() async throws -> Self? {
        if let data = try await Storage.read(Self.fileName) {
            return try self.init(fromData: data)
        } else {
            return nil
        }
    }
}
