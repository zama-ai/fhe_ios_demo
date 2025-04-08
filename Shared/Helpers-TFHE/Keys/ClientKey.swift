// Copyright © 2025 Zama. All rights reserved.

import Foundation
import TFHE

final class ClientKey {
    var pointer: OpaquePointer? = nil
        
    init(pointer: OpaquePointer?) {
        self.pointer = pointer
    }
    
    static func generate() throws -> ClientKey {
        var configBuilder: OpaquePointer? // ConfigBuilder
        var config: OpaquePointer? // Config
        var clientKeyPointer: OpaquePointer? // ClientKey
        
        try wrap { config_builder_default(&configBuilder) }
        try wrap { config_builder_build(configBuilder, &config) }
        try wrap { client_key_generate(config, &clientKeyPointer) }
        
        return ClientKey(pointer: clientKeyPointer)
    }
    
    deinit {
        client_key_destroy(pointer)
    }
    
    // MARK: to/from Data
    func toData() throws -> Data {
        var buffer = DynamicBuffer(pointer: nil, length: 0, destructor: nil)
        try wrap { client_key_serialize(pointer, &buffer) }
        return try buffer.toData()
    }
    
    convenience init(fromData input: Data) throws {
        let buffer = input.toDynamicBuffer()
        let bufferView = DynamicBufferView(pointer: buffer.pointer, length: buffer.length)
        var result: OpaquePointer?
        try wrap { client_key_deserialize(bufferView, &result) }
        
        self.init(pointer: result)
    }
    
    // MARK: Keychain support
    static func readFromKeychain() throws -> ClientKey? {
        if let data = try KeychainHelper.readSharedData(.tfheClientKey) {
            return try ClientKey(fromData: data)
        }
        
        return nil
    }

    func writeToKeychain() throws {
        try KeychainHelper.storeSharedData(try toData(), for: .tfheClientKey)
    }
}
