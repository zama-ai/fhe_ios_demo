// Copyright © 2025 Zama. All rights reserved.

import Foundation
import TFHE

final class PublicKeyCompact: Persistable {
    let fileName: Storage.File = .publicKey
    var pointer: OpaquePointer? = nil
    
    init(pointer: OpaquePointer?) {
        self.pointer = pointer
    }
    
    convenience init(clientKey: ClientKey) throws {
        var pointer: OpaquePointer? // CompactPublicKey
        try wrap { compact_public_key_new(clientKey.pointer, &pointer) }
        self.init(pointer: pointer)
    }
    
    deinit {
        compact_public_key_destroy(pointer)
    }
    
    // MARK: to/from Data
    func toData() throws -> Data {
        var buffer = DynamicBuffer(pointer: nil, length: 0, destructor: nil)
        try wrap { compact_public_key_serialize(pointer, &buffer) }
        return try buffer.toData()
    }
    
    convenience init(fromData input: Data) throws {
        let buffer = input.toDynamicBuffer()
        let bufferView = DynamicBufferView(pointer: buffer.pointer, length: buffer.length)
        var result: OpaquePointer?
        try wrap { compact_public_key_deserialize(bufferView, &result) }
        
        self.init(pointer: result)
    }
}
