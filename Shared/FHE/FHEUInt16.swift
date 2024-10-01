// Copyright © 2024 Zama. All rights reserved.

import Foundation
import TFHE

final class FHEUInt16: Persistable {
    static let fileName: Storage.File = .encryptedInput
    var pointer: OpaquePointer? = nil
    
    init(pointer: OpaquePointer?) {
        self.pointer = pointer
    }
    
    deinit {
        fhe_uint16_destroy(pointer)
    }

    // MARK: to/from Data
    func toData() throws -> Data {
        var buffer = DynamicBuffer(pointer: nil, length: 0, destructor: nil)
        try wrap { fhe_uint16_serialize(pointer, &buffer) }
        return try buffer.toData()
    }
    
    convenience init(fromData input: Data) throws {
        let buffer = input.toDynamicBuffer()
        let bufferView = DynamicBufferView(pointer: buffer.pointer, length: buffer.length)
        var result: OpaquePointer?

        try wrap { fhe_uint16_deserialize(bufferView, &result) }
        
        self.init(pointer: result)
    }
        
    // MARK: - ENCRYPTION -
    func decrypt(clientKey: ClientKey) throws -> Int {
        var result: UInt16 = 0
        try wrap { fhe_uint16_decrypt(pointer, clientKey.pointer, &result) }
        return Int(result)
    }

    init(encrypting integer: Int, clientKey: ClientKey) throws {
        try wrap { fhe_uint16_try_encrypt_with_client_key_u16(UInt16(integer), clientKey.pointer, &pointer) }
    }
    
    // MARK: - COMPUTE (needs ServerKey) -
    func addScalar(int: Int) throws -> FHEUInt16 {
        var resultPointer: OpaquePointer?
        try wrap { fhe_uint16_scalar_add(pointer, UInt16(int), &resultPointer) }
        return FHEUInt16(pointer: resultPointer)
    }
}

extension FHEUInt16: Codable {
    // Encoding (writing to JSON)
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Data())
    }
    
    // Decoding (reading from JSON)
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let data = try container.decode(Data.self)
        try self.init(fromData: data)
    }
}
