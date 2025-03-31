// Copyright © 2025 Zama. All rights reserved.

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
    func decrypt(clientKey ck: ClientKey) throws -> [Sleep.Sample] {
        var expander: OpaquePointer?     // CompactCiphertextListExpander
        
        try wrap { compact_ciphertext_list_expand(pointer, &expander) }
        var length: Int = 0
        try wrap { compact_ciphertext_list_expander_len(expander, &length) }
        
        var array: [Sleep.Sample] = []
        for i in stride(from: 0, to: length, by: 3) {
            var level: OpaquePointer? // FheUint4
            var start: OpaquePointer? // FheUint10
            var end: OpaquePointer? // FheUint10
            
            try wrap { compact_ciphertext_list_expander_get_fhe_uint4(expander, i, &level) }
            try wrap { compact_ciphertext_list_expander_get_fhe_uint10(expander, i+1, &start) }
            try wrap { compact_ciphertext_list_expander_get_fhe_uint10(expander, i+2, &end) }
            
            let clearStart = try FHEUInt16(pointer: start).decrypt(clientKey: ck)
            let clearEnd = try FHEUInt16(pointer: end).decrypt(clientKey: ck)
            let clearLevel = try FHEUInt8(pointer: level).decrypt(clientKey: ck)
            
            let sample = Sleep.Sample(start: clearStart,
                                      end: clearEnd,
                                      level: Sleep.Level(rawValue: clearLevel)!)
            array.append(sample)
        }
        
        compact_ciphertext_list_expander_destroy(expander)
        return array
    }
    
    convenience init(encrypting samples: [[Int]], publicKey pk: PublicKeyCompact) throws {
        var builder: OpaquePointer? // CompactCiphertextListBuilder
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
