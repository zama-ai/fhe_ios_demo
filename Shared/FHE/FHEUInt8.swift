// Copyright © 2025 Zama. All rights reserved.

import Foundation
import TFHE

/// A type that contains up to 2^8 - 1 = 255 values
final class FHEUInt8: Persistable {
    var pointer: OpaquePointer? = nil
    
    init(pointer: OpaquePointer?) {
        self.pointer = pointer
    }
    
    deinit {
        fhe_uint8_destroy(pointer)
    }
    
    // MARK: to/from Data
    func toData() throws -> Data {
        var buffer = DynamicBuffer(pointer: nil, length: 0, destructor: nil)
        try wrap { fhe_uint8_serialize(pointer, &buffer) }
        return try buffer.toData()
    }
    
    convenience init(fromData input: Data) throws {
        let buffer = input.toDynamicBuffer()
        let bufferView = DynamicBufferView(pointer: buffer.pointer, length: buffer.length)
        var result: OpaquePointer?
        
        try wrap { fhe_uint8_deserialize(bufferView, &result) }
        
        self.init(pointer: result)
    }
    
    // MARK: - ENCRYPTION -
    func decrypt(clientKey: ClientKey) throws -> Int {
        var result: UInt8 = 0
        try wrap { fhe_uint8_decrypt(pointer, clientKey.pointer, &result) }
        return Int(result)
    }
    
    init(encrypting integer: Int, clientKey: ClientKey) throws {
        try wrap { fhe_uint8_try_encrypt_with_client_key_u8(UInt8(integer), clientKey.pointer, &pointer) }
    }
}
