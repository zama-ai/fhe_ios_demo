// Copyright © 2024 Zama. All rights reserved.

import Foundation
import TFHE

final class CompactCiphertextList {
    var pointer: OpaquePointer? = nil // CompactCiphertextList
    
    init(pointer: OpaquePointer?) {
        self.pointer = pointer
    }
    
    deinit {
        compact_ciphertext_list_destroy(pointer)
    }
}

extension CompactCiphertextList: Persistable {
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
}

extension CompactCiphertextList {
    convenience init(encrypting samples: [[Int]], publicKey pk: PublicKeyCompact) throws {
        var builder: OpaquePointer?     // CompactCiphertextListBuilder
        var compact_list: OpaquePointer? // CompactCiphertextList
        
        try wrap { compact_ciphertext_list_builder_new(pk.pointer, &builder) }
        
        try samples.forEach { sample in
            try wrap { compact_ciphertext_list_builder_push_u4(builder, UInt8(sample[0])) }
            try wrap { compact_ciphertext_list_builder_push_u10(builder, UInt16(sample[1])) }
            try wrap { compact_ciphertext_list_builder_push_u10(builder, UInt16(sample[2])) }
        }
        
        try wrap { compact_ciphertext_list_builder_build(builder, &compact_list) }
        try wrap { compact_ciphertext_list_builder_destroy(builder) }
        
        self.init(pointer: compact_list)
    }
    
}
