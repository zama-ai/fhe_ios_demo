// Copyright © 2025 Zama. All rights reserved.

import Foundation
import TFHE

/// A type that contains up to 2^10 - 1 = 1023 values
final class FHEUInt10: Persistable {
    var pointer: OpaquePointer? = nil
    
    init(pointer: OpaquePointer?) {
        self.pointer = pointer
    }
    
    deinit {
        fhe_uint10_destroy(pointer)
    }
    
    // MARK: to/from Data
    func toData() throws -> Data {
        var buffer = DynamicBuffer(pointer: nil, length: 0, destructor: nil)
        try wrap { fhe_uint10_serialize(pointer, &buffer) }
        return try buffer.toData()
    }
    
    convenience init(fromData input: Data) throws {
        let buffer = input.toDynamicBuffer()
        let bufferView = DynamicBufferView(pointer: buffer.pointer, length: buffer.length)
        var result: OpaquePointer?
        
        try wrap { fhe_uint10_deserialize(bufferView, &result) }
        
        self.init(pointer: result)
    }
    
    // MARK: - ENCRYPTION -
    func decrypt(clientKey: ClientKey) throws -> Int {
        var result: UInt16 = 0
        try wrap { fhe_uint10_decrypt(pointer, clientKey.pointer, &result) }
        return Int(result)
    }
    
    init(encrypting integer: Int, clientKey: ClientKey) throws {
        try wrap { fhe_uint10_try_encrypt_with_client_key_u16(UInt16(integer), clientKey.pointer, &pointer) }
    }
}
