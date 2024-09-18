// Copyright © 2024 Zama. All rights reserved.

import Foundation
import TFHE

struct FHEEngine {
    func runDemo() {
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
        
        let clear_a: UInt8 = 27
        let clear_b: UInt8 = 128
        
        var a, b: OpaquePointer?
        // TODO: compressed
        
        start = .now
        ok = fhe_uint8_try_encrypt_with_client_key_u8(clear_a, client_key, &a)
        assert(ok == 0)
        
        ok = fhe_uint8_try_encrypt_with_client_key_u8(clear_b, client_key, &b)
        assert(ok == 0)
        print("2 Encryptions done in \(Date().timeIntervalSince(start))s")

        
//            let encryptedA = UnsafePointer<UInt8>(a!).pointee
//            let encryptedB = UnsafePointer<UInt8>(b!).pointee
//            print("encryption: ", clear_a, clear_b, encryptedA, encryptedB)
        
        set_server_key(server_key)
        var result: OpaquePointer?
        fhe_uint8_add(a, b, &result)
        
        var result2: OpaquePointer?
        fhe_uint8_scalar_rem(result, 17, &result2)
        
        start = .now
        var decrypted_result: UInt8 = 0
        fhe_uint8_decrypt(result2, client_key, &decrypted_result)
        print("Decryption done in \(Date().timeIntervalSince(start))s")
        
        let clear_result = (clear_a + clear_b) % 17
        assert(decrypted_result == clear_result)
        print("all good")
    }
}
