// Copyright © 2025 Zama. All rights reserved.

import Foundation
import TFHE

final class ServerKeyCompressed: Persistable {
    let fileName: Storage.File = .serverKey
    var pointer: OpaquePointer? = nil
    
    init(pointer: OpaquePointer?) {
        self.pointer = pointer
    }
    
    convenience init(clientKey: ClientKey) throws {
        var pointer: OpaquePointer? // ServerKeyCompressed
        try wrap { compressed_server_key_new(clientKey.pointer, &pointer) }
        self.init(pointer: pointer)
    }
    
    deinit {
        compressed_server_key_destroy(pointer)
    }
    
    // MARK: to/from Data
    func toData() throws -> Data {
        var buffer = DynamicBuffer(pointer: nil, length: 0, destructor: nil)
        try wrap { compressed_server_key_serialize(pointer, &buffer) }
        return try buffer.toData()
    }
    
    convenience init(fromData input: Data) throws {
        let buffer = input.toDynamicBuffer()
        let bufferView = DynamicBufferView(pointer: buffer.pointer, length: buffer.length)
        var result: OpaquePointer?
        try wrap { compressed_server_key_deserialize(bufferView, &result) }
        
        self.init(pointer: result)
    }
}
