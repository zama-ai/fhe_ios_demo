// Copyright © 2024 Zama. All rights reserved.

import Foundation
import TFHE

final class FHEUInt16Array: Persistable {
    static let fileName: Storage.File = .encryptedInputList
    var pointer: OpaquePointer? = nil
    var cachedItems: [FHEUInt16] = []

    init(pointer: OpaquePointer?) {
        self.pointer = pointer // CompactCiphertextList
    }
    
    deinit {
        compact_ciphertext_list_destroy(pointer)
    }
    
    // MARK: to/from Data
    func toData() throws -> Data {
        var buffer = DynamicBuffer(pointer: nil, length: 0, destructor: nil)
        try wrap { compact_ciphertext_list_serialize(pointer, &buffer) }
        return try buffer.toData()
    }
    
    convenience init(fromData input: Data) throws {
        let buffer = input.toDynamicBuffer()
        let bufferView = DynamicBufferView(pointer: buffer.pointer, length: buffer.length)
        var result: OpaquePointer?
        
        try wrap { compact_ciphertext_list_deserialize(bufferView, &result) }
        
        self.init(pointer: result)
    }
    
    // MARK: - ENCRYPTION -
    convenience init(encrypting array: [Int], publicKey pk: PublicKeyCompact) throws {
        var builder: OpaquePointer?     // CompactCiphertextListBuilder
        var compact_list: OpaquePointer? // CompactCiphertextList
        
        try wrap { compact_ciphertext_list_builder_new(pk.pointer, &builder) }
        
        try array.forEach { integer in
            try wrap {
                compact_ciphertext_list_builder_push_u16(builder, UInt16(integer))
            }
        }
        
        try wrap { compact_ciphertext_list_builder_build(builder, &compact_list) }
        try wrap { compact_ciphertext_list_builder_destroy(builder) }

        self.init(pointer: compact_list)
    }
}
