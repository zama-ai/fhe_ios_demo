// Copyright © 2024 Zama. All rights reserved.

import Foundation
import TFHE

extension FHEEngine {
    static private let sharedAppGroup = "group.com.dimdl.shared"
    private var defaults: UserDefaults? {
        UserDefaults(suiteName: Self.sharedAppGroup)
    }
    
    enum Key: String {
        case input, output
    }
    
    func writeSharedValue(_ value: Int?, key: Key) {
        defaults?.setValue(value, forKey: key.rawValue)
    }
    
    func readSharedValue(key: Key) -> Int? {
        defaults?.value(forKey: key.rawValue) as? Int
    }
}

final class FHEEngine {
    static let shared = FHEEngine()
    private init() {}

    var client_key: OpaquePointer? // ClientKey
    var server_key: OpaquePointer? // ServerKey
    var public_key: OpaquePointer? // CompactPublicKey
    
    func ensureClientServerKeysExist() {
        if client_key == nil || server_key == nil {
            generateClientServerKeys()
        }
    }
    
    func generateClientServerKeys() {
        print(#function)
        
        var ok: Int32
        let start = Date()
        var configBuilder: OpaquePointer? // ConfigBuilder
        var config: OpaquePointer? // Config
        
        ok = config_builder_default(&configBuilder)
        assert(ok == 0)
        
        ok = config_builder_build(configBuilder, &config);
        assert(ok == 0)
        
        ok = generate_keys(config, &client_key, &server_key)
        assert(ok == 0)
        
        print(#function, "executed in \(Date().timeIntervalSince(start))s")
    }

    func generatePublicKey() {
        print(#function)
        
        var ok: Int32
        
        ok = compact_public_key_new(client_key, &public_key)
        assert(ok == 0)
    }

    func encryptInt(_ integer: UInt16) {
        print(#function)
        
        ensureClientServerKeysExist()
        
        var ok: Int32
        let start = Date()
        var encrypted: OpaquePointer? // FheUint16
        var buffer = DynamicBuffer(pointer: nil, length: 0, destructor: nil)

        ok = fhe_uint16_try_encrypt_with_client_key_u16(integer,
                                                        client_key,
                                                        &encrypted)
        assert(ok == 0)
        

        ok = fhe_uint16_serialize(encrypted, &buffer)
        assert(ok == 0)

        if ok == 0, let pointer = buffer.pointer {
            // Read the serialized data into a Swift Data object
            let data = Data(bytes: pointer, count: buffer.length)
            print("Serialized data: \(data) \(data.count.formatted(.byteCount(style: .file)))")
            
            // Optionally, free memory using the destructor (if provided)
            if let destructor = buffer.destructor {
                let freeResult = destructor(pointer, buffer.length)
                if freeResult != 0 {
                    print("Failed to free memory")
                }
            }
        }
        
        print(#function, "executed in \(Date().timeIntervalSince(start))s")
    }

    func encryptArray(_ items: [UInt16]) {
        print(#function)
        
        ensureClientServerKeysExist()
        generatePublicKey() // TODO: Everytime or should we cache it ?
        
        // Create compact list
        var ok: Int32
        var compact_list: OpaquePointer? // CompactCiphertextList
        var listBuilder: OpaquePointer? // CompactCiphertextListBuilder
        
        ok = compact_ciphertext_list_builder_new(public_key, &listBuilder);
        assert(ok == 0);
        
        // Push values
        for item in items {
            ok = compact_ciphertext_list_builder_push_u16(listBuilder, item)
            assert(ok == 0)
        }
        
        // Build
        ok = compact_ciphertext_list_builder_build(listBuilder, &compact_list)
        assert(ok == 0)
        
        // Don't forget to destroy the builder
        compact_ciphertext_list_builder_destroy(listBuilder);
        
        print("all good")
    }

    func runSampleCode() {
        var ok: Int32
        var builder: OpaquePointer? // ConfigBuilder
        var config: OpaquePointer? // Config
        
        ok = config_builder_default(&builder)
        assert(ok == 0)
        
        ok = config_builder_build(builder, &config);
        assert(ok == 0)
        
        print("Config Builder OK, generating keys…")
        
        var client_key: OpaquePointer? // ClientKey
        var server_key: OpaquePointer? // ServerKey
        
        var start = Date()
        ok = generate_keys(config, &client_key, &server_key)
        assert(ok == 0)
        
        print("Keys generated in \(Date().timeIntervalSince(start))s")
//            print("Client: ", client_key ?? "-")
//            print("Server: ", server_key ?? "-")
        
        let clear_a: UInt64 = 27
        let clear_b: UInt64 = 128
        
        var a, b: OpaquePointer?
        // TODO: compressed
        
        start = .now
        ok = fhe_uint64_try_encrypt_with_client_key_u64(clear_a, client_key, &a)
        assert(ok == 0)
        
        ok = fhe_uint64_try_encrypt_with_client_key_u64(clear_b, client_key, &b)
        assert(ok == 0)
        print("2 Encryptions done in \(Date().timeIntervalSince(start))s")

        
//            let encryptedA = UnsafePointer<UInt8>(a!).pointee
//            let encryptedB = UnsafePointer<UInt8>(b!).pointee
//            print("encryption: ", clear_a, clear_b, encryptedA, encryptedB)
        
        set_server_key(server_key)
        var result: OpaquePointer?
        fhe_uint64_add(a, b, &result)
        
        start = .now
        var result2: OpaquePointer?
        fhe_uint64_scalar_rem(result, 17, &result2)
        print("Scalar Rem done in \(Date().timeIntervalSince(start))s")

        start = .now
        var decrypted_result: UInt64 = 0
        fhe_uint64_decrypt(result2, client_key, &decrypted_result)
        
        let clear_result = (clear_a + clear_b) % 17
        assert(decrypted_result == clear_result)
        print("all good")
    }
}
