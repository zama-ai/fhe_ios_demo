// Copyright © 2024 Zama. All rights reserved.

import Foundation

struct FHERenderable: Codable {
    let type: FHEType
    let data: Data
    
    init(_ type: FHERenderable.FHEType, data: (() throws -> Data)) throws {
        self.type = type
        self.data = try data()
    }
    
    enum FHEType: String, Codable {
        case uint16
        case uint16Array
    }
}

extension FHERenderable: Persistable {
    init(fromData input: Data) throws {
        let res = try JSONDecoder().decode(FHERenderable.self, from: input)
        self.type = res.type
        self.data = res.data
    }
    
    func toData() throws -> Data {
        try JSONEncoder().encode(self)
    }
}
