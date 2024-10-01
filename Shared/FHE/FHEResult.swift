// Copyright © 2024 Zama. All rights reserved.

import Foundation

struct FHEResult: Codable, Persistable {
    static var fileName: Storage.File = .encryptedOutput
    
    let prediction1: Data
    let prediction2: Data
    let displayType: String

    func toData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(self)
        
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("Content of \(Self.fileName):")
            print(jsonString)
        }

        return jsonData
    }
    
    init(fromData input: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: input)
    }
}
