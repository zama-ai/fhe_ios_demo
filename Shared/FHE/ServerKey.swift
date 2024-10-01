// Copyright © 2024 Zama. All rights reserved.

import Foundation
import TFHE

final class ServerKey: Persistable {
    static let fileName: Storage.File = .serverKey
    var pointer: OpaquePointer? = nil
    
    init(pointer: OpaquePointer?) {
        self.pointer = pointer
    }
    
    deinit {
        server_key_destroy(pointer)
    }
    
    // MARK: to/from Data
    func toData() throws -> Data {
        var buffer = DynamicBuffer(pointer: nil, length: 0, destructor: nil)
        try wrap { server_key_serialize(pointer, &buffer) }
        return try buffer.toData()
    }
    
    convenience init(fromData input: Data) throws {
        let buffer = input.toDynamicBuffer()
        let bufferView = DynamicBufferView(pointer: buffer.pointer, length: buffer.length)
        var result: OpaquePointer?
        try wrap { server_key_deserialize(bufferView, &result) }
        
        self.init(pointer: result)
    }

    // MARK: - SERVER -
    func setServerKey() {
        set_server_key(pointer)
    }
}
