// Copyright © 2025 Zama. All rights reserved.

import Foundation
import TFHE

final class FHEUInt16Array: Persistable {
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
    
    func decrypt(clientKey: ClientKey) throws -> [Int] {
        try readItems().map {
            try $0.decrypt(clientKey: clientKey)
        }
    }
    
    func readItems() throws -> [FHEUInt16] {
        if cachedItems.isEmpty {
            self.cachedItems = try expandItems()
        }
        return cachedItems
    }
    
    private func expandItems() throws -> [FHEUInt16] {
        var expander: OpaquePointer? // CompactCiphertextListExpander
        
        try wrap {
            compact_ciphertext_list_expand(pointer, &expander)
        }
        
        var length: Int = 0
        try wrap {
            compact_ciphertext_list_expander_len(expander, &length)
        }
        
        var array: [FHEUInt16] = []
        for int in 0..<length {
            var pointer: OpaquePointer? // FheUint16
            try wrap {
                // Ensure slot has correct type
                var type: FheTypes = Type_FheBool
                let ok = compact_ciphertext_list_expander_get_kind_of(expander, 0, &type);
                assert(type == Type_FheUint16);
                return ok
            }
            
            try wrap {
                compact_ciphertext_list_expander_get_fhe_uint16(expander, int, &pointer)
            }
            array.append(FHEUInt16(pointer: pointer))
        }
        
        compact_ciphertext_list_expander_destroy(expander)
        
        return array
    }
}
