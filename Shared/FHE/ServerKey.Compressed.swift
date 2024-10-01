// Copyright © 2024 Zama. All rights reserved.

import Foundation
import TFHE

final class CompressedServerKey: Persistable {
    static let fileName: Storage.File = .serverKey
    private var pointer: OpaquePointer? = nil
    
    init(pointer: OpaquePointer?) {
        self.pointer = pointer
    }

    convenience init(clientKey: ClientKey) throws {
        var compressedKeyPointer: OpaquePointer? // CompressedServerKey
        try wrap { compressed_server_key_new(clientKey.pointer, &compressedKeyPointer) }
        self.init(pointer: compressedKeyPointer)
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

    // MARK: - SERVER -
    func setServerKey() throws {
        let decompressed = try decompress()
        set_server_key(decompressed.pointer)
    }
    
    private func decompress() throws -> ServerKey {
        var serverKeyPointer: OpaquePointer? // ServerKey
        try wrap { compressed_server_key_decompress(pointer, &serverKeyPointer) }
        return ServerKey(pointer: serverKeyPointer)
    }
}
